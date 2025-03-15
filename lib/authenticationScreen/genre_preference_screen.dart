import 'package:flutter/material.dart';
import 'package:iwatched/controllers/authentication_controller.dart';
import 'package:get/get.dart';
import 'package:iwatched/homepage/main_screen.dart';

class GenrePreferenceScreen extends StatefulWidget {
  const GenrePreferenceScreen({super.key});

  @override
  State<GenrePreferenceScreen> createState() => _GenrePreferenceScreenState();
}

class _GenrePreferenceScreenState extends State<GenrePreferenceScreen> {
  bool isUserOver18 = true;
  AuthenticationController authenticationController =
      AuthenticationController();

  final List<String> genres = [
    "Action",
    "Adventure",
    "Comedy",
    "Crime",
    "Drama",
    "Fantasy",
    "History",
    "Horror",
    "Mystery",
    "Romance",
    "Thriller",
    "Western",
    "Animation",
    "Family",
    "Music",
    "War",
    "Documentary",
    "Sci-fi",
    "Biography",
    "Sport",
    "Talk Show",
    "Reality-TV",
    "News",
    "Game Show",
    "Short",
    "Film-Noir",
    "Musical"
  ];

  List<String> selectedGenres = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.grey),
              onPressed: () => Navigator.pop(context),
            ),
            Center(
              child: Column(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.1,
                  ),
                  Text(
                    "Select your genre preferences",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Please select your favorite genres",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 5,
                    mainAxisSpacing: 6,
                    childAspectRatio:
                        2.2, // Adjust this to balance width and height
                  ),
                  itemCount: genres.length + (isUserOver18 ? 1 : 0),
                  itemBuilder: (context, index) {
                    String genre =
                        index < genres.length ? genres[index] : "Adult";
                    bool isSelected = selectedGenres.contains(genre);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedGenres.remove(genre);
                          } else {
                            selectedGenres.add(genre);
                          }
                        });
                      },
                      child: Stack(
                        children: [
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color.fromARGB(255, 160, 2, 2)
                                  : const Color.fromARGB(255, 61, 61, 61),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              genre,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color.fromARGB(255, 161, 161, 161),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Icon(Icons.check,
                                  color:
                                      const Color.fromARGB(255, 255, 255, 255),
                                  size: 16),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // Next button
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: GestureDetector(
                  onTap: () async {
                    // Next button
                    //go to the main screen
                    if (selectedGenres.isNotEmpty) {
                      try {
                        await authenticationController.updateUserGenres(
                            selectedGenres);
                        Get.offAll(() => MainScreen());
                      } catch (e) {
                        Get.snackbar("Error", "Failed to navigate: $e");
                      }
                    } else {
                      Get.snackbar("Error", "Please select at least one genre");
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        "Save & Complete",
                        style: TextStyle(
                          color: Color.fromARGB(255, 212, 212, 212),
                          fontSize: 18,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        color: Color.fromARGB(255, 212, 212, 212),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
