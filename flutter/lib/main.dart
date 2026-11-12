import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:pump_control/home_view.dart';
import 'package:pump_control/login_view.dart';
import 'package:pump_control/password_login_view.dart';
import 'package:pump_control/register_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'bar.dart';

// ...
String selectedDay = 'Monday'; // Default selected day
TimeOfDay startTime = TimeOfDay(hour: 0, minute: 0); // Default start time
TimeOfDay endTime = TimeOfDay(hour: 0, minute: 0); // Default end time
DateTime selectedDate = DateTime.now(); // Default selected date
TimeOfDay selectedTime = TimeOfDay(hour: 0, minute: 0); // Default selected time
Duration selectedDuration = Duration(hours: 1); // Default selected duration
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the login status before running the app
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  if (!kIsWeb) {
  OneSignal.shared.setAppId("YOUR_ONESIGNAL_APP_ID");

  await Firebase.initializeApp();
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  print('User granted permission: ${settings.authorizationStatus}');

  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  MyApp({required this.isLoggedIn});
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pump Control',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: widget.isLoggedIn ? PasswordLoginScreen() : LoginScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/home': (context) => HomeView(), // Assuming this is your home screen
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
