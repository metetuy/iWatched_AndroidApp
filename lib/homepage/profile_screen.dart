import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:iwatched/models/movie.dart';
import 'package:iwatched/models/user.dart' as user_profile;
import 'package:iwatched/controllers/authentication_controller.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:iwatched/services/tmdb_service.dart';
import 'package:iwatched/utilities/movie_dialog_util.dart';

class ProfileScreen extends StatefulWidget {
  final user_profile.User user;

  const ProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

List<Widget> _buildGenreButtons(List<String> genres) {
  return genres.map((genre) {
    return Container(
      margin: const EdgeInsets.only(right: 5, bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 0, 0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        genre,
        style: const TextStyle(
            color: Color.fromARGB(255, 226, 226, 226),
            fontSize: 12,
            fontWeight: FontWeight.bold),
      ),
    );
  }).toList();
}

class _ProfileScreenState extends State<ProfileScreen> {
  user_profile.User get user => widget.user;

  void _showSearchDialog() {
    final TextEditingController searchController = TextEditingController();
    final TMDBService tmdbService = TMDBService();

    List<Movie> searchResults = [];
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Define _performSearch inside this scope where it has access to isLoading
            void performSearch(String query) async {
              setState(() {
                isLoading = true;
              });

              try {
                final results = await tmdbService.searchMovies(query);
                setState(() {
                  searchResults = results;
                  isLoading = false;
                });
              } catch (e) {
                setState(() {
                  isLoading = false;
                });
                Get.snackbar('Error', 'Error searching movies: $e');
              }
            }

            return Dialog(
              backgroundColor: const Color.fromARGB(255, 48, 48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                height: MediaQuery.of(context).size.height * 0.7,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add Movies By Search',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search for movies...',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (query) {
                        if (query.trim().isNotEmpty) {
                          performSearch(query); // Use the local function
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if (searchController.text.trim().isNotEmpty) {
                          performSearch(
                              searchController.text); // Use the local function
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        fixedSize:
                            Size(MediaQuery.of(context).size.width * 0.3, 20),
                      ),
                      child: const Text(
                        'Search',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                    const Divider(color: Colors.grey, height: 24),
                    Expanded(
                      child: isLoading
                          ? const Center(
                              child:
                                  CircularProgressIndicator(color: Colors.red))
                          : searchResults.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Search for movies to add to your watched list',
                                    style: TextStyle(color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: searchResults.length,
                                  itemBuilder: (context, index) {
                                    final movie = searchResults[index];
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          movie.posterPath,
                                          width: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Container(
                                              width: 50,
                                              height: 75,
                                              color: Colors.grey[700],
                                              child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.white),
                                            );
                                          },
                                        ),
                                      ),
                                      title: Text(
                                        movie.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${movie.year} • ${movie.rating.toStringAsFixed(1)}',
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            color: Colors.green),
                                        onPressed: () {
                                          _addMovieToWatched(movie);
                                          Navigator.pop(context);
                                        },
                                      ),
                                      onTap: () {
                                        MovieDialogUtil.showMovieDetailsDialog(
                                          context: context,
                                          movie: movie,
                                          genreButtonBuilder:
                                              _buildGenreButtons,
                                          onWatched: () {
                                            _addMovieToWatched(movie);
                                            Navigator.pop(context);
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addMovieToWatched(Movie movie) async {
    try {
      // Check if movie is already in watched list
      bool alreadyExists = user.watchedMovies.any((m) => m.id == movie.id);

      if (alreadyExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              backgroundColor: Colors.red,
              content: Text(
                textAlign: TextAlign.center,
                '${movie.title} is already in your watched list',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )),
        );
        return;
      }

      // Add movie to watched movies in Firebase
      List<Map<String, dynamic>> updatedMovies =
          user.watchedMovies.map((m) => m.toJson()).toList();

      updatedMovies.add(movie.toJson());

      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'watchedMovies': updatedMovies});

      // Update local list
      setState(() {
        user.watchedMovies.add(movie);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          backgroundColor: Colors.green,
          content: Text(
            'Movie added to your watched list',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error adding movie to watched list: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(197, 0, 0, 0),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text(
                              'Confirm Logout',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: const Text(
                              'Are you sure you want to logout?',
                              style: TextStyle(
                                fontSize: 18,
                              ),
                            ),
                            actions: <Widget>[
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  AuthenticationController.authController
                                      .logoutUser();
                                  Navigator.of(context).pop();
                                },
                                child: const Text(
                                  'Confirm',
                                  style: TextStyle(
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          );
                        });
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(
                height: 40,
              ),
              Obx(() => CircleAvatar(
                    radius: 50,
                    backgroundImage:
                        AuthenticationController.authController.profileImage !=
                                null
                            ? FileImage(AuthenticationController
                                .authController.profileImage!)
                            : const AssetImage("images/profile.png"),
                    backgroundColor: Colors.white,
                  )),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.red),
                    onPressed: () async {
                      await AuthenticationController.authController
                          .captureImageFromCamera();

                      setState(() {
                        AuthenticationController.authController.imageFile;
                      });
                      AuthenticationController.authController.imageFile;
                    },
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () async {
                      await AuthenticationController.authController
                          .pickImageFileFromGallery();

                      setState(() {
                        AuthenticationController.authController.imageFile;
                      });
                    },
                    icon: const Icon(Icons.image_search_outlined,
                        color: Colors.red),
                  ),
                ],
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Text(
                  'Username',
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color.fromARGB(255, 196, 195, 195),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color.fromARGB(255, 209, 209, 209),
                      width: 1.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                width: MediaQuery.of(context).size.width * 0.9,
                child: Row(
                  children: [
                    Text(
                      user.name ?? 'N/A',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Text(
                  'Age',
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color.fromARGB(255, 196, 195, 195),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color.fromARGB(255, 209, 209, 209),
                      width: 1.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                width: MediaQuery.of(context).size.width * 0.9,
                child: Row(
                  children: [
                    Text(
                      (user.age).toString(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Text(
                  'Country',
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color.fromARGB(255, 196, 195, 195),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color.fromARGB(255, 209, 209, 209),
                      width: 1.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                width: MediaQuery.of(context).size.width * 0.9,
                child: Row(
                  children: [
                    Text(
                      user.country ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color.fromARGB(255, 196, 195, 195),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.all(8),
                width: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color.fromARGB(255, 209, 209, 209),
                      width: 1.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Text(
                      user.email ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Text(
                  'Preferred Genres',
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color.fromARGB(255, 196, 195, 195),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromARGB(255, 196, 195, 195),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                width: MediaQuery.of(context).size.width * 0.9,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Wrap(
                      children: _buildGenreButtons(user.selectedGenres),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Row(
                  children: [
                    Text(
                      '# Watched Movies: ${user.watchedMovies.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 196, 195, 195),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _showSearchDialog();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 122, 11, 3),
                        shape: const CircleBorder(),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return Dialog(
                              backgroundColor:
                                  const Color.fromARGB(255, 48, 48, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                width: MediaQuery.of(context).size.width * 0.9,
                                height:
                                    MediaQuery.of(context).size.height * 0.7,
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Watched Movies',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.search,
                                              color: Colors.white),
                                          onPressed: () {
                                            final TextEditingController
                                                searchController =
                                                TextEditingController();
                                            List<Movie> searchResults = [];
                                            // Show search dialog in watched movies
                                            showDialog(
                                              context: context,
                                              builder: (BuildContext context) {
                                                return StatefulBuilder(builder:
                                                    (context, setDialogState) {
                                                  return AlertDialog(
                                                    backgroundColor:
                                                        const Color.fromARGB(
                                                            255, 19, 19, 19),
                                                    title: Text('Search Movies',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white)),
                                                    content: SizedBox(
                                                      // Set explicit constraints for the container
                                                      width: double.maxFinite,
                                                      height: MediaQuery.of(
                                                                  context)
                                                              .size
                                                              .height *
                                                          0.5, // Set a specific height
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize
                                                            .min, // Important!
                                                        children: [
                                                          TextField(
                                                              controller:
                                                                  searchController,
                                                              decoration:
                                                                  InputDecoration(
                                                                hintText:
                                                                    'Search for movies...',
                                                                prefixIcon: Icon(
                                                                    Icons
                                                                        .search,
                                                                    color: Colors
                                                                        .grey),
                                                                border:
                                                                    OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              30),
                                                                  borderSide:
                                                                      BorderSide
                                                                          .none,
                                                                ),
                                                                filled: true,
                                                                fillColor:
                                                                    Colors.grey[
                                                                        800],
                                                                contentPadding:
                                                                    EdgeInsets.symmetric(
                                                                        vertical:
                                                                            5),
                                                              ),
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .white),
                                                              onChanged:
                                                                  (query) {
                                                                // Your existing search logic
                                                                if (query
                                                                    .trim()
                                                                    .isEmpty) {
                                                                  setDialogState(
                                                                      () {
                                                                    searchResults =
                                                                        [];
                                                                  });
                                                                  return;
                                                                }

                                                                final suggestions = user
                                                                    .watchedMovies
                                                                    .where(
                                                                        (movie) {
                                                                  final movieTitle =
                                                                      movie
                                                                          .title
                                                                          .toLowerCase();
                                                                  final input =
                                                                      query
                                                                          .toLowerCase();
                                                                  return movieTitle
                                                                      .contains(
                                                                          input);
                                                                }).toList();

                                                                setDialogState(
                                                                    () {
                                                                  searchResults =
                                                                      suggestions;
                                                                });
                                                              }),
                                                          const Divider(
                                                              color:
                                                                  Colors.grey),

                                                          // Fixed Expanded widget
                                                          Expanded(
                                                            child: searchResults
                                                                    .isEmpty
                                                                ? Center(
                                                                    child: Text(
                                                                      searchController
                                                                              .text
                                                                              .isEmpty
                                                                          ? 'Search for movies in your watched list'
                                                                          : 'No movies found',
                                                                      style: TextStyle(
                                                                          color:
                                                                              Colors.white),
                                                                    ),
                                                                  )
                                                                : ListView
                                                                    .builder(
                                                                    shrinkWrap:
                                                                        true, // Important!
                                                                    itemCount:
                                                                        searchResults
                                                                            .length,
                                                                    itemBuilder:
                                                                        (context,
                                                                            index) {
                                                                      final movie =
                                                                          searchResults[
                                                                              index];
                                                                      return ListTile(
                                                                        leading:
                                                                            ClipRRect(
                                                                          borderRadius:
                                                                              BorderRadius.circular(8),
                                                                          child:
                                                                              Image.network(
                                                                            movie.posterPath,
                                                                            width:
                                                                                50,
                                                                            fit:
                                                                                BoxFit.cover,
                                                                            errorBuilder: (context,
                                                                                error,
                                                                                stackTrace) {
                                                                              return Container(
                                                                                width: 50,
                                                                                height: 75,
                                                                                color: Colors.grey,
                                                                                child: Icon(Icons.error),
                                                                              );
                                                                            },
                                                                          ),
                                                                        ),
                                                                        title:
                                                                            Text(
                                                                          movie
                                                                              .title,
                                                                          style:
                                                                              TextStyle(
                                                                            color:
                                                                                Colors.white,
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        ),
                                                                        subtitle:
                                                                            Text(
                                                                          'Year: ${movie.year} • Rating: ${movie.rating.toStringAsFixed(1)}',
                                                                          style: TextStyle(
                                                                              color: Colors.grey,
                                                                              fontSize: 12),
                                                                        ),
                                                                        onTap:
                                                                            () {
                                                                          MovieDialogUtil
                                                                              .showMovieDetailsDialog(
                                                                            context:
                                                                                context,
                                                                            movie:
                                                                                movie,
                                                                            genreButtonBuilder:
                                                                                _buildGenreButtons,
                                                                          );
                                                                        },
                                                                      );
                                                                    },
                                                                  ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: Text('Close',
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .red)),
                                                      ),
                                                    ],
                                                  );
                                                });
                                              },
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.white),
                                          onPressed: () =>
                                              Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                    const Divider(color: Colors.grey),
                                    Expanded(
                                      child: user.watchedMovies.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'No movies in your watched movies list',
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount:
                                                  user.watchedMovies.length,
                                              itemBuilder: (context, index) {
                                                final movie =
                                                    user.watchedMovies[index];
                                                return ListTile(
                                                  onTap: () {
                                                    MovieDialogUtil
                                                        .showMovieDetailsDialog(
                                                      context: context,
                                                      movie: movie,
                                                      genreButtonBuilder:
                                                          _buildGenreButtons,
                                                    );
                                                  },
                                                  leading: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.network(
                                                      movie.posterPath,
                                                      width: 50,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return Container(
                                                          width: 50,
                                                          height: 75,
                                                          color: Colors.grey,
                                                          child: const Icon(
                                                              Icons.error),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  title: Text(
                                                    movie.title,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  subtitle: Text(
                                                    'Year: ${movie.year} • Rating: ${movie.rating.toStringAsFixed(1)}',
                                                    style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 12),
                                                  ),
                                                  trailing: IconButton(
                                                    icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.red),
                                                    onPressed: () async {
                                                      // Remove from Firebase
                                                      try {
                                                        final updatedList = user
                                                            .watchedMovies
                                                            .where((m) =>
                                                                m.title !=
                                                                movie.title)
                                                            .map((m) =>
                                                                m.toJson())
                                                            .toList();

                                                        await FirebaseFirestore
                                                            .instance
                                                            .collection("users")
                                                            .doc(FirebaseAuth
                                                                .instance
                                                                .currentUser!
                                                                .uid)
                                                            .update({
                                                          "watchedMovies":
                                                              updatedList
                                                        });

                                                        setState(() {
                                                          user.watchedMovies
                                                              .removeAt(index);
                                                        });

                                                        if (user.watchedMovies
                                                                .isEmpty &&
                                                            context.mounted) {
                                                          Navigator.pop(
                                                              context);
                                                        }
                                                      } catch (e) {
                                                        debugPrint(
                                                            'Error removing movie: $e');
                                                      }
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color.fromARGB(255, 196, 195, 195),
                      ),
                      child: SizedBox(
                        child: Text(
                          'View',
                          style: TextStyle(
                            color: Color.fromARGB(255, 0, 0, 0),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: ElevatedButton(
                  onPressed: () {
                    // Show dialog with watch later movies
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          backgroundColor:
                              const Color.fromARGB(255, 48, 48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.9,
                            height: MediaQuery.of(context).size.height * 0.7,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Watch Later Movies',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.white),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ],
                                ),
                                const Divider(color: Colors.grey),
                                Expanded(
                                  child: user.watchLaterMovies.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No movies in your watch later list',
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount:
                                              user.watchLaterMovies.length,
                                          itemBuilder: (context, index) {
                                            final movie =
                                                user.watchLaterMovies[index];
                                            return ListTile(
                                              leading: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  movie.posterPath,
                                                  width: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      width: 50,
                                                      height: 75,
                                                      color: Colors.grey,
                                                      child: const Icon(
                                                          Icons.error),
                                                    );
                                                  },
                                                ),
                                              ),
                                              title: Text(
                                                movie.title,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              subtitle: Text(
                                                'Year: ${movie.year} • Rating: ${movie.rating.toStringAsFixed(1)}',
                                                style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 12),
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(Icons.delete,
                                                    color: Colors.red),
                                                onPressed: () async {
                                                  // Remove from Firebase
                                                  try {
                                                    final updatedList = user
                                                        .watchLaterMovies
                                                        .where((m) =>
                                                            m.title !=
                                                            movie.title)
                                                        .map((m) => m.toJson())
                                                        .toList();

                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection("users")
                                                        .doc(FirebaseAuth
                                                            .instance
                                                            .currentUser!
                                                            .uid)
                                                        .update({
                                                      "watchLaterMovies":
                                                          updatedList
                                                    });

                                                    setState(() {
                                                      user.watchLaterMovies
                                                          .removeAt(index);
                                                    });

                                                    if (user.watchLaterMovies
                                                            .isEmpty &&
                                                        context.mounted) {
                                                      Navigator.pop(context);
                                                    }
                                                  } catch (e) {
                                                    debugPrint(
                                                        'Error removing movie: $e');
                                                  }
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 194, 194, 194),
                  ),
                  child: const Text(
                    'Watch Later Movies',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 0, 0, 0),
                    ),
                  ),
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text(
                    'Reset Non-Interested Movies',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () async {
                    bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Confirm Reset'),
                          content: const Text(
                            'Are you sure you want to reset non-interested movies?',
                            style: TextStyle(
                              fontSize: 18,
                            ),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                    if (confirm != true) {
                      return;
                    }
                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .update({"notInterestedMovies": []});
                    user.notInterestedMovies.clear();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
