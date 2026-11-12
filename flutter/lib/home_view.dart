import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:pump_control/custom_appbar.dart';
import 'package:pump_control/home_view.dart';
import 'package:pump_control/login_view.dart';
import 'package:pump_control/profile_view.dart';
import 'package:pump_control/register_view.dart';
import 'package:pump_control/add_schedule_view.dart';
import 'package:pump_control/shcedule_list_view..dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'bar.dart';
import 'main.dart';

class HomeView extends StatefulWidget {
  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late DatabaseReference _databaseReference;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  late Map<String, dynamic> _values = {};
  late Timer _timer;
  late Timer _timer1;
  bool forcePumpState = false;
  String? _token;
  late List<DocumentSnapshot> _history = [];
  late bool _loading = true;
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  void showNotification(bool isTemp) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pump_control',
      'maxQuotaReached',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      'Pump is Tuned Off',
      isTemp
          ? 'The Temperature reached the max values and the pump is shut down!'
          : 'The Current reached the max values and the pump is shut down!',
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  Future<void> _getToken() async {
    FCMService fcmService = FCMService();
    String? token = await fcmService.getFCMToken();
    setState(() {
      _token = token;
      if (token != null) {
        fcmService.saveTokenToFirestore(token);
      }
      print("myToken is : ${_token}");
    });
  }

  @override
  void initState() {
    super.initState();
    _databaseReference = FirebaseDatabase.instance.ref().child('test');
    _databaseReference.onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _values = Map<String, dynamic>.from(event.snapshot.value! as Map);
        });
      }
    });

    // Start the timer to save values every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
       
      _saveToFirestore(); 
    });
     _timer1 = Timer.periodic(const Duration(seconds: 1), (timer) {
    
      _checkAndSetPumpState();
    });
    _fetchHistory();

    // Initialize the plugin
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
    _getToken();
    _checkAndSetPumpState();
  }

Future<void> _checkAndSetPumpState() async {
  print("Checking schedules...");
  QuerySnapshot snapshot = await _firestore.collection('schedules').get();
  List<DocumentSnapshot> schedules = snapshot.docs;

  // Get current day and time
  DateTime now = DateTime.now();
  int currentWeekday = now.weekday;
    String currentDayString = DateFormat('EEEE').format(DateTime.now());

  String currentTime = DateFormat('HH:mm').format(now);
  print("Current time: $currentTime");

  for (DocumentSnapshot schedule in schedules) {
    var data = schedule.data() as Map<String, dynamic>;

    bool isActive = data['active'];
    List<String> days = List<String>.from(data['days']);
    int selectedDuration = data['selectedDuration'];
    DateTime startDate = DateTime.parse(data['startDate']);
    List<String> timeParts = data['startTime'].split(':');
    TimeOfDay startTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );
  print(data);
    if (!isActive) {
      print("Schedule is not active");
      continue;
    }

    // Check if today is in schedule days
    if (!days.contains(currentDayString.toString())) {
      print("Today is not in schedule days");
      continue;
    }

    DateTime startDateTime = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      startTime.hour,
      startTime.minute,
    );

    DateTime endDateTime =
        startDateTime.add(Duration(minutes: selectedDuration));

    print("Start Time: $startTime, End Time: $endDateTime");

    // Check if current time is within the schedule
    if (now.isAfter(startDateTime) && now.isBefore(endDateTime)) {
      print("Active schedule found, setting pumpState to true");
      await _databaseReference.child('pumpState').set(true);
      return; // Exit the loop if a schedule is active
    }
  }

  // If no active schedule found, set pumpState to false
if (!forcePumpState){
  print("No active schedule found, setting pumpState to false");
  await _databaseReference.child('pumpState').set(false);
}
}


  void _fetchHistory() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('history').get();
      setState(() {
        _history = snapshot.docs;
        _loading = false;
      });
    } catch (e) {
      print('Error fetching history: $e');
    }
  }

  void _togglePumpState() {
    bool currentPumpState = _values['pumpState'] ?? false;
    _databaseReference.update({'pumpState': !currentPumpState});
     bool currentForcePumpState = _values['forcePumpState'] ?? false;
    _databaseReference.update({'forcePumpState': !currentPumpState});
  }

  void _saveToFirestore() {
    FirebaseFirestore.instance.collection('history').add({
      'temperature': _values['temperature']?.toDouble() ?? 0.0,
      'current': _values['current']?.toDouble() ?? 0.0,
      'date': Timestamp.now(),
    });
  }

  void _saveAlarmToFirestore(
      String selectedDay,
      TimeOfDay startTime,
      TimeOfDay endTime,
      DateTime selectedDate,
      TimeOfDay selectedTime,
      Duration selectedDuration) {
    FirebaseFirestore.instance.collection('schedules').add({
      'selectedDay': selectedDay,
      'startTime': '${startTime.hour}:${startTime.minute}',
      'endTime': '${endTime.hour}:${endTime.minute}',
      'selectedDate': DateFormat('yyyy-MM-dd').format(selectedDate),
      'selectedTime': '${selectedTime.hour}:${selectedTime.minute}',
      'selectedDuration': selectedDuration.inMinutes,
    });
  }

  @override
  void dispose() {
    _timer.cancel(); 
     _timer1.cancel(); // Cancel the timer when the widget is disposed
   // Cancel the timer when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool pumpState = _values['pumpState'] ?? false;
   forcePumpState = _values['forcePumpState'] ?? false;
    double currentTemperature = _values['temperature']?.toDouble() ?? 0.0;
    double maxTemperature = _values['maxTemperature']?.toDouble() ?? 0.0;
    double currentCurrent = _values['current']?.toDouble() ?? 0.0;
    double maxCurrent = _values['maxCurrent']?.toDouble() ?? 0.0;
 
    if (currentTemperature > maxTemperature || currentCurrent > maxCurrent) {
      // Turn off the pump
      _databaseReference.update({'pumpState': false});
      if (currentTemperature > maxTemperature) {
        showNotification(true);
      } else {
        showNotification(false);
      }
      // Show notification
      // You need to implement the notification logic here
      // For example, using flutter_local_notifications package
    }  

    return Scaffold(
      appBar: CustomAppBar(
        title: "InteliPump",
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Current Temperature: $currentTemperature °C'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Max Temperature: $maxTemperature °C'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Current Current: $currentCurrent A'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Max Current: $maxCurrent A'),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text('PumpState : '),
                Text(pumpState ? "On" : "Off",
                    style: TextStyle(
                        color: pumpState ? Colors.green : Colors.red)),
              ],
            ),
          ),
          _loading
              ? Center(child: CircularProgressIndicator())
              : InteractiveViewer(
                  boundaryMargin: EdgeInsets.all(20.0),
                  minScale: 0.5,
                  maxScale: 2.0,
                  child: AspectRatio(
                    aspectRatio: 1.7,
                    child: LineChart(
                      LineChartData(
                        titlesData: FlTitlesData(
                          topTitles: AxisTitles(
                            axisNameWidget: Text("Time(min)"),
                            sideTitles: SideTitles(
                              showTitles: false,
                            ),
                          ),
                          rightTitles: AxisTitles(
                            axisNameWidget: Text("Values (A / C°)"),
                            sideTitles: SideTitles(
                              showTitles: false,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                              color: const Color(0xff37434d), width: 1),
                        ),
                        minX: 0,
                        maxX: _history.length.toDouble() - 1,
                        minY: -50,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _history.asMap().entries.map((entry) {
                              final index = entry.key;
                              final data = entry.value;
                              final current = maxCurrent;
                              return FlSpot(index.toDouble(), current);
                            }).toList(),
                            isCurved: true,
                            color: Colors.red,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            belowBarData: BarAreaData(show: false),
                            dotData: FlDotData(
                                show: false), // Remove dots on each value
                          ),
                          LineChartBarData(
                            spots: _history.asMap().entries.map((entry) {
                              final index = entry.key;
                              final data = entry.value;
                              final current = maxTemperature;
                              return FlSpot(index.toDouble(), current);
                            }).toList(),
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            belowBarData: BarAreaData(show: false),
                            dotData: FlDotData(
                                show: false), // Remove dots on each value
                          ),
                          LineChartBarData(
                            spots: _history.asMap().entries.map((entry) {
                              final index = entry.key;
                              final data = entry.value;
                              final current =
                                  data['current']?.toDouble() ?? 0.0;
                              return FlSpot(index.toDouble(), current);
                            }).toList(),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            belowBarData: BarAreaData(show: false),
                            dotData: FlDotData(
                                show: false), // Remove dots on each value
                          ),
                          LineChartBarData(
                            spots: _history.asMap().entries.map((entry) {
                              final index = entry.key;
                              final data = entry.value;
                              final temp =
                                  data['temperature']?.toDouble() ?? 0.0;
                              return FlSpot(index.toDouble(), temp);
                            }).toList(),
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            belowBarData: BarAreaData(show: false),
                            dotData: FlDotData(
                                show: false), // Remove dots on each value
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text('Current Temperature (°C)'),
                ),
                Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text('Max Temperature (°C)'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text('Current Current (A)'),
                ),
                Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text('Max Current (A)'),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: FloatingActionButton(
              heroTag: 'ToggleButton',
              onPressed: _togglePumpState,
              tooltip: 'Toggle Pump',
              backgroundColor: pumpState ? Colors.green : Colors.red,
              child: Icon(pumpState
                  ? Icons.power_settings_new
                  : Icons.power_settings_new),
            ),
          ),
          FloatingActionButton(
            heroTag: 'SettingButton',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProfileView()),
              );
            },
            tooltip: 'Setting',
            backgroundColor: Colors.blue,
            child: Icon(Icons.settings),
          ),
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: FloatingActionButton(
              heroTag: 'AlarmPickerButton',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ScheduleListPage()),
                );
              },
              tooltip: 'Set Alarm',
              backgroundColor: Colors.orange,
              child: Icon(Icons.schedule),
            ),
          ),
        ],
      ),
    );
  }
}

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final CollectionReference _tokensCollection =
      FirebaseFirestore.instance.collection('fcm_tokens');

  Future<String?> getFCMToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> saveTokenToFirestore(String token) async {
    await _tokensCollection.doc(token).set({'token': token});
  }
}
