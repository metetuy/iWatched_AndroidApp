import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iwatched/authenticationScreen/registration_screen.dart';
import 'package:iwatched/controllers/authentication_controller.dart';
import 'package:iwatched/widgets/custom_text_field_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  final controllerAuth = Get.find<AuthenticationController>();
  bool _keepMeLoggedIn = false;
  bool showProgress = false;

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SingleChildScrollView(
      child: Center(
        child: Column(
          children: [
            const SizedBox(
              height: 80,
            ),

            Image.asset(
              "images/logo.png",
              width: 160,
            ),

            const SizedBox(
              height: 20,
            ),

            Text(
              "iWatched",
              style: GoogleFonts.zillaSlab(
                fontSize: 36,
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(
              height: 40,
            ),

            //email
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: CustomTextFieldWidget(
                editingController: emailController,
                labelText: "Email",
                iconData: Icons.email_outlined,
                isObscure: false,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            //password
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: CustomTextFieldWidget(
                editingController: passwordController,
                labelText: "Password",
                iconData: Icons.lock_outline,
                isObscure: true,
              ),
            ),

            //login button
            Container(
              width: MediaQuery.of(context).size.width * 0.3,
              height: 40,
              margin: const EdgeInsets.only(top: 20),
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                  color: Color.fromARGB(255, 150, 0, 0)),
              child: InkWell(
                onTap: () async {
                  if (emailController.text.isEmpty ||
                      passwordController.text.isEmpty) {
                    Get.snackbar("Error", "Please fill all fields");
                  } else {
                    setState(() {
                      showProgress = true;
                    });
                    await controllerAuth.loginUser(emailController.text.trim(),
                        passwordController.text.trim(), _keepMeLoggedIn);

                    if (mounted) {
                      setState(() {
                        showProgress = false;
                      });
                    }
                  }
                },
                child: const Center(
                  child: Text(
                    "Login",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 5,
            ),

            //Remember me
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Checkbox(
                  checkColor: Colors.white,
                  activeColor: Colors.red,
                  value: _keepMeLoggedIn,
                  onChanged: (value) {
                    setState(() {
                      _keepMeLoggedIn = value!;
                    });
                  },
                ),
                const Text(
                  "Keep Me Logged In",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            //register button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
                InkWell(
                  onTap: () {
                    //register button

                    Get.to(RegistrationScreen());
                  },
                  child: const Text(
                    "Sign Up Now",
                    style: TextStyle(
                      fontSize: 15,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 184, 184, 184),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),
            if (showProgress)
              const CircularProgressIndicator(
                color: Colors.red,
              ),
          ],
        ),
      ),
    ));
  }
}
