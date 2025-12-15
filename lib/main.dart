import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'includes/auth.dart';

// ! SCREENS IMPORT
import 'screens/sign_in.dart';
import 'screens/home_seeker.dart';
import 'screens/home_recruiter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final logged = await isLoggedIn();
  String? userType;
  if (logged) userType = await getUserType();

  runApp(MainApp(isLoggedIn: logged, userType: userType));
}

class MainApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? userType;
  const MainApp({super.key, required this.isLoggedIn, this.userType});

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!isLoggedIn) {
      home = const SignInPage();
    } else if (userType == 'recruiter') {
      home = const HomeRecruiterPage();
    } else {
      home = const HomeSeekerPage();
    }

    return MaterialApp(
      title: 'Part Timer',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: home,
    );
  }
}
