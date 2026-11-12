import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:pump_control/home_view.dart';
import 'package:pump_control/login_view.dart';
import 'package:pump_control/register_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'bar.dart';
import 'custom_appbar.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  _ProfileViewState createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final TextEditingController _currentPasswordController =
      TextEditingController(text: "");
  final TextEditingController _newPasswordController =
      TextEditingController(text: "");

  double? _currentMaxTemperature;
  double? _currentMaxCurrent;
  String? _userName;
  String? _userEmail;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  late Map<String, dynamic> _values = {};

  late DatabaseReference _databaseReference;
  late StreamSubscription<DatabaseEvent> _databaseSubscription;

  late final TextEditingController _maxTemperatureController =
      TextEditingController(text: '');
  late final TextEditingController _maxCurrentController =
      TextEditingController(text: '');

  @override
  void initState() {
    super.initState();
    _databaseReference = FirebaseDatabase.instance.ref().child('test');
    _databaseSubscription = _databaseReference.onValue.listen((event) {
      setState(() {
        if (event.snapshot.value != null) {
          _values = Map<String, dynamic>.from(event.snapshot.value! as Map);

          _currentMaxTemperature = _values['maxTemperature']?.toDouble() ?? 0.0;
          _currentMaxCurrent = _values['maxCurrent']?.toDouble() ?? 0.0;

          _maxTemperatureController.text =
              _currentMaxTemperature?.toString() ?? '';
          _maxCurrentController.text = _currentMaxCurrent?.toString() ?? '';
        }
      });
    });
    _loadUserInfo();
  }

  @override
  void dispose() {
    _databaseSubscription.cancel();
    _maxTemperatureController.dispose();
    _maxCurrentController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('name');
      _userEmail = prefs.getString('email');
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    Navigator.of(context)
        .pushReplacementNamed('/login'); // Assuming you have a login route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: "Profile",
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User Info'),
              SizedBox(height: 8.0),
              if (_userName != null && _userEmail != null)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: $_userName'),
                          SizedBox(height: 8.0),
                          Text('Email: $_userEmail'),
                        ],
                      ),
                      Spacer()
                    ],
                  ),
                ),
              SizedBox(height: 16.0),
              SizedBox(height: 16.0),
              Text('Change Password'),
              TextFormField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureCurrentPassword = !_obscureCurrentPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureCurrentPassword,
              ),
              TextFormField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureNewPassword = !_obscureNewPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureNewPassword,
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _changePassword,
                    child: Text('Change Password'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            20.0), // Adjust the radius as needed
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              Text('Max Values'),
              TextFormField(
                controller: _maxTemperatureController,
                decoration: InputDecoration(labelText: 'Max Temperature'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _maxCurrentController,
                decoration: InputDecoration(labelText: 'Max Current'),
                keyboardType: TextInputType.number,
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      double maxTemperature =
                          double.parse(_maxTemperatureController.text);
                      double maxCurrent =
                          double.parse(_maxCurrentController.text);
                      await updateMaxValues(maxTemperature, maxCurrent);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Max values updated')),
                      );
                    },
                    child: Text('Update Max Values'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            20.0), // Adjust the radius as needed
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.0),
              Center(
                child: ElevatedButton(
                  onPressed: _logout,
                  child: Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          20.0), // Adjust the radius as needed
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    try {
      String currentPassword = _currentPasswordController.text;
      String newPassword = _newPasswordController.text;

      AuthCredential credential = EmailAuthProvider.credential(
        email: FirebaseAuth.instance.currentUser!.email!,
        password: currentPassword,
      );
      await FirebaseAuth.instance.currentUser!
          .reauthenticateWithCredential(credential);

      await FirebaseAuth.instance.currentUser!.updatePassword(newPassword);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password updated')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update password: $e')),
      );
    }
  }

  Future<void> updateMaxValues(double maxTemperature, double maxCurrent) async {
    await _databaseReference.update({
      'maxTemperature': maxTemperature,
      'maxCurrent': maxCurrent,
    });
  }
}
