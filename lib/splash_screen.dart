import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:iwatched/homepage/main_screen.dart';
import 'package:iwatched/authenticationScreen/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreenAnimation extends StatefulWidget {
  final bool loggedIn;
  const SplashScreenAnimation({
    super.key,
    required this.loggedIn,
  });

  @override
  State<SplashScreenAnimation> createState() => _SplashScreenAnimationState();
}

class _SplashScreenAnimationState extends State<SplashScreenAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();
    
    // Verify Firebase auth status
    final user = FirebaseAuth.instance.currentUser;
    
    // If user is null but loggedIn flag is true, we need to reset it 
    // unless keepMeLoggedIn is true
    if (user == null && widget.loggedIn) {
      final prefs = Get.find<SharedPreferences>();
      final keepMeLoggedIn = prefs.getBool('keepMeLoggedIn') ?? false;
      
      if (!keepMeLoggedIn) {
        prefs.setBool('loggedIn', false);
        _nextScreen = const LoginScreen();
      }
    } else {
      // Normal flow
      _nextScreen = widget.loggedIn ? const MainScreen() : const LoginScreen();
    }
    
    // Set up animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    
    // Start timer for navigation
    startTimer();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  startTimer() {
    // Wait for 3 seconds before starting the animation
    Timer(const Duration(seconds: 3), () {
      _animationController.forward().then((_) {
        Navigator.of(context).pushReplacement(
          FadeTransitionRoute(page: _nextScreen!),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(197, 0, 0, 0),
      body: Stack(
        children: [
          // The next screen (invisible until animation starts)
          Opacity(
            opacity: 0,
            child: _nextScreen ?? Container(),
          ),
          // Splash screen with animation
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Opacity(
                opacity: 1 - _animationController.value,
                child: child,
              );
            },
            child: Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Lottie.asset(
                  'assets/splash_animation.json',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom route transition for smooth crossfading
class FadeTransitionRoute extends PageRouteBuilder {
  final Widget page;

  FadeTransitionRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
          barrierColor: Colors.black,
        );
}
