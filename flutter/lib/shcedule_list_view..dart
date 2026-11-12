import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pump_control/custom_appbar.dart';
import 'package:pump_control/add_schedule_view.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ScheduleListPage extends StatefulWidget {
  @override
  _ScheduleListPageState createState() => _ScheduleListPageState();
}

class _ScheduleListPageState extends State<ScheduleListPage> {
  List<DocumentSnapshot> schedules = [];
  bool loading = true;
  final List<String> allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();
    fetchSchedules();
  }

  Future<void> fetchSchedules() async {
    setState(() {
      loading = true;
    });
    final snapshot =
        await FirebaseFirestore.instance.collection('schedules').get();
    setState(() {
      schedules = snapshot.docs;
      loading = false;
    });
  }

  void _deleteSchedule(DocumentSnapshot schedule) {
    schedule.reference.delete();
    setState(() {
      schedules.remove(schedule);
    });
  }

  void _editSchedule(DocumentSnapshot schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddScheduleView(schedule: schedule),
      ),
    ).then((_) =>
        fetchSchedules()); // Reload the data when returning from the edit page
  }

  String formatTime(String time) {
    List<String> parts = time.split(':');
    String formattedHour = parts[0].padLeft(2, '0');
    String formattedMinute = parts[1].padLeft(2, '0');
    return '$formattedHour:$formattedMinute';
  }

  String formatDateTime(String dateTimeString) {
    DateTime dateTime = DateTime.parse(dateTimeString);
    return DateFormat('MM/dd/yyyy').format(dateTime);
  }

  String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours} h';
    } else {
      return '${duration.inMinutes} m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Schedules',
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                var schedule = schedules[index];
                var scheduleData = schedule.data() as Map<String, dynamic>;
                var selectedDays =
                    (scheduleData['days'] as List<dynamic>).cast<String>();
          selectedDays.sort((a, b) => allDays.indexOf(a).compareTo(allDays.indexOf(b)));

                return ListTile(
                  title: Row(
                    children: [
                       Text(formatDateTime(scheduleData['startDate']),style: TextStyle(fontWeight: FontWeight.bold)),
                      Spacer(),
                      Text(formatTime(scheduleData['startTime'])),
                     
                      Spacer(),
                      Text(formatDuration(
                          Duration(minutes: scheduleData['selectedDuration']))),
                          Spacer()
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Row(
                      children: [
                        
                        for (String day in selectedDays)
                          Container(
                            width: 20,
                            height: 20,
                            margin: EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blueAccent,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              day[0],
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 30,
                        child: IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () {
                            _editSchedule(schedule);
                          },
                        ),
                      ),
                      SizedBox(width: 30,
                        child: IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            _deleteSchedule(schedule);
                          },
                        ),
                      ),
                      SizedBox(width: 50,
                        child: Switch(
                          value: scheduleData['active'],
                          onChanged: (bool value) {
                            setState(() {
                              schedule.reference.update({'active': value});
                              scheduleData['active'] = value;
                              fetchSchedules();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddScheduleView()),
          ).then((_) =>
              fetchSchedules()); // Reload the data when returning from the add page
        },
        child: Icon(Icons.add),
        backgroundColor: Color.fromARGB(255, 17, 91, 230),
      ),
    );
  }
}
