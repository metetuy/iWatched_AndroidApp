import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:iwatched/homepage/profile_screen.dart';
import 'package:iwatched/services/tmdb_service.dart';
import 'package:iwatched/models/movie.dart';
import 'package:iwatched/models/user.dart' as user_profile;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:iwatched/utilities/movie_dialog_util.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<State<CardSwiper>> _cardSwiperKey =
      GlobalKey<State<CardSwiper>>();

  final CardSwiperController controller = CardSwiperController();

  int _cardsCount = 50;

  // Default to Swipe Page
  int _selectedIndex = 1;

  final PageController _pageController = PageController(initialPage: 1);
  final TMDBService _tmdbService = TMDBService();
  final List<Movie> _movies = [];
  user_profile.User? _user;
  int _currentMovieIndex = 0;
  int _previousMovieIndex = 0;
  bool _isFetching = false;

  // Add these variables to track swipe history
  final List<Map<String, dynamic>> _swipeHistory = [];

  // Add this variable to manually track the index
  int _lastKnownIndex = 0;

  @override
  void initState() {
    super.initState();

    Get.put(_pageController);

    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await _fetchUser();
      await _fetchMovies();
    } catch (e) {
      debugPrint('Error initializing data: $e');
    }
  }

  // Update the _onSwipe method to track swipes
  bool _onSwipe(
      int prevIndex, int? currentIndex, CardSwiperDirection direction) {
    // Store the swipe action for potential undo
    _swipeHistory.add({
      'movieIndex': _currentMovieIndex,
      'direction': direction,
    });

    setState(() {
      _previousMovieIndex = prevIndex;
      if (currentIndex != null) {
        _currentMovieIndex = currentIndex;
        _lastKnownIndex = currentIndex; // Save this for tracking
      }

      if (_currentMovieIndex >= (_cardsCount - 20)) {
        _cardsCount += 30;
      }
    });

    if (direction == CardSwiperDirection.left) {
      //Not interested => add to the not interested list
      debugPrint(
          'Did not watch ${_movies[_previousMovieIndex].title} , index: $_previousMovieIndex');
      _updateUserMovies(_previousMovieIndex, direction);
    } else if (direction == CardSwiperDirection.right) {
      //did watch => add to the watched list
      debugPrint('Added to watched movies $_previousMovieIndex');
      _updateUserMovies(_previousMovieIndex, direction);
    } else if (direction == CardSwiperDirection.top) {
      // Add to watch later
      debugPrint('Added to watch later');
      _updateUserMovies(_previousMovieIndex, direction);
    }

    // Fetch more movies if we are running out
    if (_currentMovieIndex >= _movies.length - 8) {
      // Consider fetching more movies here
      _fetchMovies();
    }
    return true;
  }

  // Replace the existing _onUndo method with this improved version
  bool _onUndo(
      int? previousIndex, int currentIndex, CardSwiperDirection direction) {
    if (_swipeHistory.isEmpty) {
      Get.snackbar('Undo Error', 'No more actions to undo');
      return false;
    }

    try {
      // Get the last swipe action
      final lastSwipe = _swipeHistory.removeLast();
      final lastDirection = lastSwipe['direction'] as CardSwiperDirection;
      final lastIndex = lastSwipe['movieIndex'] as int;

      // Update UI immediately
      setState(() {
        _currentMovieIndex = lastIndex;
        _previousMovieIndex = lastIndex > 0 ? lastIndex - 1 : 0;
      });

      // Handle Firebase updates in a separate method
      _handleUndoFirebaseUpdate(lastIndex, lastDirection);

      debugPrint('Undid action for movie: ${_movies[lastIndex].title}');
      return true;
    } catch (e) {
      debugPrint('Error during undo: $e');
      Get.snackbar('Error', 'Failed to undo last action');
      return false;
    }
  }

  // Add this new method to handle Firebase updates
  void _handleUndoFirebaseUpdate(
      int lastIndex, CardSwiperDirection lastDirection) {
    Future(() async {
      try {
        if (_user == null) {
          await _fetchUser();
          if (_user == null) {
            Get.snackbar('Error', 'Could not load user data');
            return;
          }
        }

        String listName = '';
        if (lastDirection == CardSwiperDirection.top) {
          listName = 'watchLaterMovies';
        } else if (lastDirection == CardSwiperDirection.right) {
          listName = 'watchedMovies';
        } else if (lastDirection == CardSwiperDirection.left) {
          listName = 'notInterestedMovies';
        } else {
          debugPrint('Invalid direction for undo: $lastDirection');
        }

        // Initialize currentList with an empty list by default
        List<Movie> currentList = [];

        if (lastDirection == CardSwiperDirection.left) {
          final List<String> currentIds = _user!.notInterestedMovies;
          final updatedIds =
              currentIds.where((id) => id != _movies[lastIndex].id).toList();
          await FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .update({'notInterestedMovies': updatedIds});
          // Skip the rest of the function for left swipes as we've already handled it
          return;
        } else if (lastDirection == CardSwiperDirection.top) {
          currentList = _user!.watchLaterMovies;
        } else if (lastDirection == CardSwiperDirection.right) {
          currentList = _user!.watchedMovies;
        } else {
          debugPrint('Invalid direction for undo: $lastDirection');
        }

        final updatedList = currentList
            .where((movie) => movie.title != _movies[lastIndex].title)
            .map((movie) => movie.toJson())
            .toList();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({listName: updatedList});

        await _fetchUser();
      } catch (e) {
        debugPrint('Error updating Firebase during undo: $e');
        Get.snackbar('Error', 'Failed to update data');
      }
    });
  }

  Future<void> _fetchUser() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _user = user_profile.User.fromJson(userDoc.data()!);
        });
      } else {
        debugPrint("User document does not exist.");
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
      Get.snackbar('Error', 'Error fetching user: $e');
    }
  }

  Future<void> _updateUserMovies(
      int movieIndex, CardSwiperDirection direction) async {
    try {
      // Convert existing watchedMovies list to JSON
      if (_user == null) {
        debugPrint("User data is null. Cannot update watch later movies.");
        await _fetchUser();
        if (_user == null) {
          Get.snackbar(
              "User data is still null", "Cannot update watch later movies.");
          return;
        }
      }

      //If the user swiped right, add the movie to the watched list
      if (direction == CardSwiperDirection.right) {
        if (_user == null) {
          debugPrint("User data is null. Cannot update watched movies.");
          return;
        }
        List<Map<String, dynamic>> updatedMovies =
            _user!.watchedMovies.map((movie) => movie.toJson()).toList();
        updatedMovies.add(_movies[movieIndex].toJson());
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({
          'watchedMovies': updatedMovies,
        });
        debugPrint("Movie added to watched movies successfully!");
      }
      //If the user swiped up, add the movie to the watch later list
      else if (direction == CardSwiperDirection.top) {
        // Convert existing watchLaterMovies list to JSON
        List<Map<String, dynamic>> updatedWatchLaterMovies =
            _user!.watchLaterMovies.map((movie) => movie.toJson()).toList();

        // Add new movie in JSON format
        updatedWatchLaterMovies.add(_movies[movieIndex].toJson());

        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({
          'watchLaterMovies': updatedWatchLaterMovies,
        });
        debugPrint("Movie added to watch later movies successfully!");

        //If the user swiped left, add the movie to the not interested list
      } else if (direction == CardSwiperDirection.left) {
        List<String> updatedNotInterestedMovies =
            List<String>.from(_user!.notInterestedMovies);

        updatedNotInterestedMovies.add(_movies[movieIndex].id);
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .update({
          'notInterestedMovies': updatedNotInterestedMovies,
        });
        debugPrint("Movie added to not interested movies successfully!");
      }

      // Fetch updated user data
      await _fetchUser();
    } catch (e) {
      debugPrint('Error updating user movies: $e');
    }
  }

  // Update the _fetchMovies method
  Future<void> _fetchMovies() async {
    // Prevent multiple fetches
    if (_isFetching || _movies.length >= _cardsCount) return;

    try {
      // Set flag first, then update UI
      _isFetching = true;

      // Update UI in a separate call
      if (mounted) {
        setState(() {});
      }
      final movies = await _tmdbService.getPopularMovies();

      if (_user != null) {
        final filteredMovies = movies.where((movie) {
          if (movie.posterPath.isEmpty) {
            return false;
          }

          return !_user!.watchedMovies
                  .any((watchedMovie) => watchedMovie.id == movie.id) &&
              !_user!.watchLaterMovies
                  .any((watchLaterMovie) => watchLaterMovie.id == movie.id) &&
              !_user!.notInterestedMovies.contains(movie.id);
        }).toList();

        setState(() {
          if (filteredMovies.isNotEmpty) {
            filteredMovies.shuffle();
            _movies.addAll(filteredMovies);
            debugPrint(
                'Added ${filteredMovies.length} new movies. Total: ${_movies.length}');
          } else {
            // If no new movies after filtering, increment page and try again
            _tmdbService.incrementPage();
            // Schedule next fetch
            Future.microtask(() => _fetchMovies());
          }
        });
      } else {
        if (mounted) {
          setState(() {
            final validMovies =
                movies.where((movie) => movie.posterPath.isNotEmpty).toList();
            _movies.addAll(validMovies);
            debugPrint(
                'Added ${validMovies.length} new movies. Total: ${_movies.length}');
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching movies: $e');
      if (_movies.isEmpty && !_isFetching) {
        Get.snackbar(
          'Error',
          'Failed to fetch movies. Please check your internet connection.',
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      _isFetching = false;

      if (mounted) {
        setState(() {});
      }
    }
  }

  // Update the _onItemTapped method
  void _onItemTapped(int index) {
    // If leaving the swipe page, save the current index
    if (_selectedIndex == 1) {
      _currentMovieIndex = _lastKnownIndex;
    }

    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index); // Jump without animation
  }

  List<Widget> _buildGenreButtons(List<String> genres) {
    return genres.map((genre) {
      return Container(
        margin: const EdgeInsets.only(right: 5, bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color.fromARGB(225, 167, 13, 2).withAlpha(135),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          genre,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color.fromARGB(197, 0, 0, 0),
          iconSize: 20,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: Colors.red,
          selectedIconTheme: const IconThemeData(size: 28, color: Colors.red),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.alarm_add, color: Colors.white),
              label: 'Watch Later',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.vibration, color: Colors.white),
              label: 'Swipe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, color: Colors.white),
              label: 'Profile',
            ),
          ],
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics:
            const NeverScrollableScrollPhysics(), // Prevents PageView swipe
        children: [
          _watchLaterPage(),
          _swipePage(),
          _user == null
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                )
              : ProfileScreen(user: _user!), // Your existing profile screen
        ],
      ),
    );
  }

  Widget _watchLaterPage() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.red,
            ),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('No watch later movies found.'));
        }
        var userData = snapshot.data!.data() as Map<String, dynamic>;
        var watchLaterMovies = userData['watchLaterMovies'] as List<dynamic>;
        return ListView.builder(
          itemCount: watchLaterMovies.length,
          itemBuilder: (context, index) {
            final movie = _user!.watchLaterMovies[index];
            return ListTile(
              onTap: () {
                MovieDialogUtil.showMovieDetailsDialog(
                  context: context,
                  movie: movie,
                  genreButtonBuilder: _buildGenreButtons,
                );
              },
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  movie.posterPath,
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 50,
                      height: 75,
                      color: Colors.grey,
                      child: const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
              title: Text(
                movie.title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Year: ${movie.year} • Rating: ${movie.rating.toStringAsFixed(1)} ',
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  try {
                    final updatedList = _user!.watchLaterMovies
                        .where((m) => m.title != movie.title)
                        .map((m) => m.toJson())
                        .toList();

                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser!.uid)
                        .update({'watchLaterMovies': updatedList});

                    setState(() {
                      _user!.watchLaterMovies.removeAt(index);
                    });
                  } catch (e) {
                    debugPrint('Error removing movie: $e');
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _swipePage() {
    if (_movies.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.red,
        ),
      );
    }
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Info button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text(
                            'About iWatched',
                            style: TextStyle(
                              color: Colors.red,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          content: const Text(
                            'iWatched is a movie recommendation app that helps you find movies you like. Swipe right to add a movie to your watched list, swipe left to add a movie to your not interested list, and swipe up to add a movie to your watch later list. Enjoy!',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        );
                      });
                },
                icon: const Icon(Icons.info,
                    color: Color.fromARGB(255, 226, 226, 226))),
          ),
          Expanded(
            flex: 7,
            child: CardSwiper(
              key: _cardSwiperKey,
              controller: controller,
              cardsCount: _cardsCount,
              scale: 0.7,
              onSwipe: _onSwipe,
              onUndo: _onUndo,
              allowedSwipeDirection: AllowedSwipeDirection.only(
                right: true,
                left: true,
                up: true,
              ),
              initialIndex:
                  _currentMovieIndex, // Set initialIndex when creating
              cardBuilder:
                  (context, index, percentThresholdX, percentThresholdY) {
                // Start fetching earlier
                if (index >= _movies.length - 15 && !_isFetching) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _fetchMovies();
                  });
                }

                if (index >= _movies.length) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Colors.red,
                        ),
                        SizedBox(height: 16),
                        Text('Loading more movies...',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                }

                final movie = _movies[index];
                return GestureDetector(
                  onTap: () {
                    MovieDialogUtil.showMovieDetailsDialog(
                      context: context,
                      movie: movie,
                      genreButtonBuilder: _buildGenreButtons,
                      onWatched: () =>
                          controller.swipe(CardSwiperDirection.right),
                      onSkip: () => controller.swipe(CardSwiperDirection.left),
                      onLater: () => controller.swipe(CardSwiperDirection.top),
                    );
                  },
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            color: const Color.fromARGB(255, 41, 41, 41)),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          image: DecorationImage(
                            image: NetworkImage(
                                "https://image.tmdb.org/t/p/w500${movie.posterPath}"),
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withAlpha(200),
                              Colors.black.withAlpha(25),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 80,
                        left: 10,
                        right:
                            10, // Add right constraint to ensure proper width
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            //movie title
                            Text(
                              movie.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Text(
                              movie.year,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: MediaQuery.of(context).size.width *
                                  0.8, // Constrain width
                              child: Wrap(
                                direction: Axis.horizontal,
                                alignment: WrapAlignment.start,
                                spacing: 8,
                                runSpacing: 8,
                                children: _buildGenreButtons(movie.genres),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 50,
                        left: 10,
                        child: Row(
                          children: [
                            Image.asset(
                              "images/tmdbLogo.png",
                              width: 45,
                            ),
                            Text(
                              ": ${movie.rating.toStringAsFixed(1)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Swipe buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    controller.swipe(CardSwiperDirection.left);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(11),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 35,
                    color: Colors.white,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    controller.undo();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(13),
                  ),
                  child: const Icon(Icons.undo, size: 30, color: Colors.black),
                ),
                ElevatedButton(
                  onPressed: () {
                    controller.swipe(CardSwiperDirection.top);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 21, 118, 245),
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(13),
                  ),
                  child: const Icon(
                    Icons.alarm_add,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    controller.swipe(CardSwiperDirection.right);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(13),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
