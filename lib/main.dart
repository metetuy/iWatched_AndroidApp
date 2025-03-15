import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iwatched/controllers/authentication_controller.dart';
import 'package:iwatched/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {

  await dotenv.load(fileName: ".env");

  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase first
  await Firebase.initializeApp();
  
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  Get.put(prefs);
  
  // Initialize AuthenticationController only once
  Get.put(AuthenticationController());
  
  // Get the login status
  bool keepMeLoggedIn = prefs.getBool('keepMeLoggedIn') ?? false;
  bool loggedIn = prefs.getBool('loggedIn') ?? false;
  
  // Determine if we should show logged-in state
  bool showLoggedIn = false;
  
  // Check if the user is still authenticated with Firebase
  if (FirebaseAuth.instance.currentUser != null && loggedIn) {
    showLoggedIn = true;
  } else if (!keepMeLoggedIn) {
    // If keepMeLoggedIn is false, reset loggedIn status
    await prefs.setBool('loggedIn', false);
  }
  
  runApp(MyApp(loggedIn: showLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool loggedIn;
  const MyApp({super.key, required this.loggedIn});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'iWatched',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(197, 0, 0, 0),
      ),
      debugShowCheckedModeBanner: false,
      home: SplashScreenAnimation(loggedIn: loggedIn),
    );
  }
}
