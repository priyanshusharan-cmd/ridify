import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Check for a saved session
  final prefs = await SharedPreferences.getInstance();
  final savedName = prefs.getString('user_name');
  final savedAge = prefs.getString('user_age');
  final savedEmail = prefs.getString('user_email');

  final bool hasSession =
      savedName != null && savedEmail != null && savedAge != null;

  runApp(MyApp(
    initialScreen: hasSession
        ? HomeScreen(
            userName: savedName,
            userAge: savedAge,
            userEmail: savedEmail,
          )
        : const LoginScreen(),
  ));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ridify',
      theme: ThemeData(primaryColor: Colors.black),
      home: initialScreen,
    );
  }
}
