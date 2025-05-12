import 'package:flutter/material.dart';
import 'package:trademark/screens/admin_screen.dart';
import 'package:trademark/screens/player_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trademark Guessing Game',
      initialRoute: '/',
      routes: {
        '/': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/admin': (context) => AdminPage(),
        '/player': (context) => PlayerPage(),
      },
    );
  }
}