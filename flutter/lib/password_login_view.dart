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
import 'forget_password_view.dart';

class PasswordLoginScreen extends StatefulWidget {
  @override
  _PasswordLoginScreenState createState() => _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends State<PasswordLoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _userEmail;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('email');
    });
  }

  @override
  void initState() {
    super.initState();

    _loadUserInfo();
  }

  void _login(BuildContext context) async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please enter  password'),
            backgroundColor: Colors.red),
      );
      return;
    }

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _userEmail ?? "",
        password: _passwordController.text,
      );
      // Save login info and status to shared preferences

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Login successful'), backgroundColor: Colors.green),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeView()),
      );
    } catch (e) {
      print('Failed to login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to login: $e'), backgroundColor: Colors.red),
      );
    }
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
        title: 'Password Login',
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: _togglePasswordVisibility,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => _login(context),
                child: Text('Login'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        20.0), // Adjust the radius as needed
                  ),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _logout,
              child: Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                      20.0), // Adjust the radius as needed
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
