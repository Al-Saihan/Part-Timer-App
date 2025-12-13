import 'package:flutter/material.dart';

// ! SCREENS IMPORT
import 'screens/sign_in.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Part Timer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SignInPage(),
    );
  }
}
