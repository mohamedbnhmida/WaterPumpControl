import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_appbar.dart';

class AddScheduleView extends StatefulWidget {
  final DocumentSnapshot? schedule;

  AddScheduleView({this.schedule});

  @override
  _AddScheduleViewState createState() => _AddScheduleViewState();
}

class _AddScheduleViewState extends State<AddScheduleView> {
  late String selectedDay;
  late DateTime startDate;
  late TimeOfDay startTime;
  late Duration selectedDuration;
  late bool isActive;
  late List<String> selectedDays;
  final List<String> allDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  @override
  void initState() {
    super.initState();

    if (widget.schedule != null) {
      var data = widget.schedule!.data() as Map<String, dynamic>;
      selectedDay = 'Monday';
      startDate = DateTime.parse(data['startDate']);
      List<String> timeParts = data['startTime'].split(':');
      startTime = TimeOfDay(
          hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
      selectedDuration = Duration(minutes: data['selectedDuration']);
      isActive = data['active'];
      selectedDays = List<String>.from(data['days']);
    } else {
      selectedDay = 'Monday';
      startDate = DateTime.now();
      startTime = TimeOfDay.fromDateTime(DateTime.now()); // Set default time to current time
      selectedDuration = Duration(hours: 1);
      isActive = true;
      selectedDays = [];
    }
    selectedDays.sort((a, b) => allDays.indexOf(a).compareTo(allDays.indexOf(b)));
  }

  void _saveAlarmToFirestore() {
    var scheduleData = {
      'startDate': startDate.toIso8601String(),
      'startTime':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'selectedDuration': selectedDuration.inMinutes,
      'active': isActive,
      'days': selectedDays,
    };

    if (widget.schedule != null) {
      widget.schedule!.reference.update(scheduleData);
    } else {
      FirebaseFirestore.instance.collection('schedules').add(scheduleData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Add Schedule',
      ),
      body: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Column(
          children: [
            ListTile(
              title: Text('Start Date'),
              trailing: TextButton(
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      startDate = pickedDate;
                    });
                  }
                },
                child: Text('${startDate.toLocal()}'.split(' ')[0]),
              ),
            ),
            ListTile(
              title: Text('Start Time'),
              trailing: TextButton(
                onPressed: () async {
                  final TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: startTime,
                  );
                  if (pickedTime != null) {
                    setState(() {
                      startTime = pickedTime;
                    });
                  }
                },
                child: Text(startTime.format(context)),
              ),
            ),
            ListTile(
              title: Text('Select Duration'),
              trailing: DropdownButton<Duration>(
                value: selectedDuration,
                items: <Duration>[ Duration(minutes: 1),
                  Duration(minutes: 15),
                  Duration(minutes: 30),
                  Duration(hours: 1),
                  Duration(hours: 2),
                  Duration(hours: 3),
                  Duration(hours: 4),
                  Duration(hours: 6),
                  Duration(hours: 8),
                  Duration(hours: 12),
                  Duration(days: 1),
                ].map<DropdownMenuItem<Duration>>((Duration value) {
                  return DropdownMenuItem<Duration>(
                    value: value,
                    child: Text(value.inHours > 1
                        ? '${value.inHours} h'
                        : '${value.inMinutes} m'),
                  );
                }).toList(),
                onChanged: (Duration? newValue) {
                  setState(() {
                    selectedDuration = newValue!;
                  });
                },
              ),
            ),
            ListTile(
              title: Text('Active'),
              trailing: Switch(
                value: isActive,
                onChanged: (bool value) {
                  setState(() {
                    isActive = value;
                  });
                },
              ),
            ),
            Wrap( // Using Wrap instead of Row for better handling of long lists
            spacing: 5,
              children: allDays.map((day) {
                return ChoiceChip(
                  label: Text(day), // Display full day name
                  backgroundColor: Color.fromARGB(255, 165, 159, 159),
                  labelStyle: TextStyle(color: Colors.white),
                  selectedColor: Colors.blueAccent,
                  selected: selectedDays.contains(day),
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        selectedDays.add(day);
                      } else {
                        selectedDays.remove(day);
                      }
                      selectedDays.sort((a, b) => allDays.indexOf(a).compareTo(allDays.indexOf(b)));
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _saveAlarmToFirestore();
          Navigator.of(context).pop();
        },
        child: Icon(Icons.save),
        backgroundColor: Color.fromARGB(255, 17, 91, 230),
      ),
    );
  }
}
