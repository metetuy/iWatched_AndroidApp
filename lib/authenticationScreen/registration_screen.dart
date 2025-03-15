import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iwatched/controllers/authentication_controller.dart';
import 'package:iwatched/models/movie.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  //personal information
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController ageController = TextEditingController();
  TextEditingController countryController = TextEditingController();

  //preferences
  TextEditingController tvShowController = TextEditingController();
  TextEditingController movieController = TextEditingController();
  TextEditingController genreController = TextEditingController();
  TextEditingController directorController = TextEditingController();
  TextEditingController actorController = TextEditingController();
  List<String> selectedGenres = [];
  List<Movie> watchedMovies = [];
  List<Movie> watchLaterMovies = [];
  List<Movie> notInterested = [];

  final authenticationController = Get.find<AuthenticationController>();

  @override
  void initState() {
    super.initState();
    authenticationController.pickedFile.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              const SizedBox(
                height: 150,
              ),

              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.grey),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),

              const Text(
                "Create an account",
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                "Please fill in the following details",
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),

              const SizedBox(
                height: 20,
              ),

              Obx(() => CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        authenticationController.profileImage != null
                            ? FileImage(authenticationController.profileImage!)
                            : const AssetImage("images/profile.png"),
                    backgroundColor: Colors.white,
                  )),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.red),
                    onPressed: () async {
                      await authenticationController.captureImageFromCamera();

                      setState(() {
                        authenticationController.imageFile;
                      });
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () async {
                      await authenticationController.pickImageFileFromGallery();

                      setState(() {
                        authenticationController.imageFile;
                      });
                    },
                    icon: const Icon(Icons.image_search_outlined,
                        color: Colors.red),
                  ),
                ],
              ),

              const SizedBox(
                height: 20,
              ),

              //username
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Username",
                    labelStyle: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              //age
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: TextField(
                  controller: ageController,
                  decoration: InputDecoration(
                    labelText: "Age",
                    labelStyle: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              //country
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: TextField(
                  controller: countryController,
                  decoration: InputDecoration(
                    labelText: "Country",
                    labelStyle: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              //email
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    labelStyle: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              //password
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: "Password",
                    labelStyle: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  obscureText: true,
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              const SizedBox(
                height: 10,
              ),

              //preferences
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: GestureDetector(
                    onTap: () async {
                      if (nameController.text.trim().isEmpty ||
                          ageController.text.trim().isEmpty ||
                          countryController.text.trim().isEmpty ||
                          emailController.text.trim().isEmpty ||
                          passwordController.text.trim().isEmpty) {
                        Get.snackbar("Error", "Please fill in all the fields");
                      } else {
                        try {
                          await authenticationController.createNewUser(
                            authenticationController.profileImage,
                            nameController.text,
                            ageController.text,
                            emailController.text,
                            passwordController.text,
                            countryController.text,
                            DateTime.now().millisecondsSinceEpoch,
                            selectedGenres = [],
                            watchedMovies = [],
                            watchLaterMovies = [],
                            notInterested = [],
                          );
                        } catch (e) {
                          Get.snackbar("Error", "Failed to navigate: $e");
                        }
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Preferences",
                          style: TextStyle(
                            color: Color.fromARGB(255, 212, 212, 212),
                            fontSize: 18,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward,
                          color: Color.fromARGB(255, 212, 212, 212),
                          size:
                              18, // Change this value to adjust the size of the icon
                        ),
                      ],
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
}
