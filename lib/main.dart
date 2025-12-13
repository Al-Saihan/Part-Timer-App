import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ! SCREENS IMPORT
import 'screens/sign_in.dart';

void main() async {
  await dotenv.load(fileName: ".env"); 
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Part Timer',
      theme: ThemeData(primarySwatch: Colors.blue),
      // home: const SignUpPage(),
      home: const SignInPage(),
    );
  }
}
