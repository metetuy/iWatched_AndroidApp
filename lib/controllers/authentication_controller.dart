import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iwatched/authenticationScreen/genre_preference_screen.dart';
import 'package:iwatched/authenticationScreen/login_screen.dart';
import 'package:iwatched/homepage/main_screen.dart';
import 'package:iwatched/models/user.dart' as user_profile;
import 'package:iwatched/models/movie.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationController extends GetxController {
  static AuthenticationController get authController =>
      Get.find<AuthenticationController>();

  final Rx<File?> pickedFile = Rx<File?>(null);
  File? get profileImage => pickedFile.value;
  XFile? imageFile;

  pickImageFileFromGallery() async {
    imageFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (imageFile != null) {
      pickedFile.value = File(imageFile!.path);
      Get.snackbar("Profile Image", "Image Picked Successfully");
    }
  }

  Future<String> uploadImageToStorage(File imageFile) async {
    Reference ref = FirebaseStorage.instance
        .ref()
        .child("profileImages")
        .child(FirebaseAuth.instance.currentUser!.uid);

    UploadTask uploadTask = ref.putFile(imageFile);
    TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);

    String downloadUrlOfImage = await taskSnapshot.ref.getDownloadURL();

    return downloadUrlOfImage;
  }

  captureImageFromCamera() async {
    imageFile = await ImagePicker().pickImage(source: ImageSource.camera);

    if (imageFile != null) {
      pickedFile.value = File(imageFile!.path);
      Get.snackbar("Profile Image", "Image Picked Successfully");
    }
  }

  createNewUser(
    File? imageProfile,
    String name,
    String age,
    String email,
    String password,
    String country,
    int publishedDateTime,
    List<String> selectedGenres,
    List<Movie> watchedMovies,
    List<Movie> watchLaterMovies,
    List<Movie> notInterestedMovies,
  ) async {
    //Create a new user
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      //Save profile picture url
      String? urlOfDownloadedImage;
      if (imageProfile != null) {
        urlOfDownloadedImage = await uploadImageToStorage(imageProfile);
      } else {
        urlOfDownloadedImage =
            "https://png.pngtree.com/png-vector/20190223/ourmid/pngtree-profile-line-black-icon-png-image_691065.jpg"; // Set a default image URL
      }

      //Save user data to Firestore
      user_profile.User userInstance = user_profile.User(
          imageProfile: urlOfDownloadedImage,
          name: name,
          age: int.parse(age),
          email: email,
          password: password,
          country: country,
          publishedDateTime: DateTime.now().millisecondsSinceEpoch,
          selectedGenres: selectedGenres,
          watchedMovies: watchedMovies,
          watchLaterMovies: watchLaterMovies);

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCredential.user!.uid)
          .set(userInstance.toJson());

      Get.snackbar(
          "Account creation successfull", "Account created successfully");
      Get.to(GenrePreferenceScreen());
    } catch (e) {
      Get.snackbar("Account creation unsuccessfull", "Error occured: $e");
    }
  }

  updateUserGenres(List<String> selectedGenres) async {
    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({"selectedGenres": selectedGenres});
    } catch (e) {
      Get.snackbar("Error", e.toString());
    }
  }

  loginUser(String email, String password, bool keepMeLoggedIn) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      Get.snackbar("Login Success", "Login successfull");

      final prefs = Get.find<SharedPreferences>();

      await prefs.setBool('loggedIn', true);

      await prefs.setBool('keepMeLoggedIn', keepMeLoggedIn);

      Navigator.pushReplacement(
          Get.context!, MaterialPageRoute(builder: (context) => MainScreen()));
    } catch (e) {
      Get.snackbar("Login Failed", "Error occured: $e");
    }
  }

  Future<void> logoutUser() async {
    try {
      await FirebaseAuth.instance.signOut();

      final prefs = Get.find<SharedPreferences>();

      bool keepMeLoggedIn = prefs.getBool('keepMeLoggedIn') ?? false;
      if (!keepMeLoggedIn) {
        await prefs.setBool('loggedIn', false);
      }

      Get.offAll(() => const LoginScreen());
    } catch (e) {
      Get.snackbar("Logout Failed", "Error occured: $e");
    }
  }
}
