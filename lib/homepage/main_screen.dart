import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:iwatched/homepage/profile_screen.dart';
import 'package:iwatched/services/backend_service.dart';
import 'package:iwatched/services/tmdb_service.dart';
import 'package:iwatched/models/movie.dart';
import 'package:iwatched/models/user.dart' as user_profile;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:iwatched/utilities/movie_dialog_util.dart';
import 'package:iwatched/authenticationScreen/genre_preference_screen.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<State<CardSwiper>> _cardSwiperKey =
      GlobalKey<State<CardSwiper>>();
  final CardSwiperController controller = CardSwiperController();
  final PageController _pageController = PageController(initialPage: 1);

  late String _uid;

  // Default to Swipe Page

  int _selectedIndex = 1;

  final TMDBService _tmdbService = TMDBService();
  final BackendService _backendService = BackendService();

  final List<Movie> _allMovies = [];

  // NEW: Map to store Backend CSV Indices. Key: Movie ID (String), Value: CSV Index (int)
  // This is required because the backend needs the specific CSV index to learn.
  final Map<String, int> _movieBackendIndices = {};

  user_profile.User? _user;

  int _currentMovieIndex = 0;
  int _previousMovieIndex = 0;
  int _lastKnownIndex = 0; //Tracks the last known index when leaving swipe page

  // Add these variables to track swipe history
  final List<Map<String, dynamic>> _swipeHistory = [];

  // BUFFER SETTINGS
  final int _bufferThreshold = 3; // Fetch new batch when 3 cards remain
  final int _batchSize = 10; // How many movies to fetch per batch
  bool _isLoadingBatch = false; // Prevent concurrent batch requests

  @override
  void initState() {
    super.initState();

    Get.put(_pageController);

    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      _uid = (await _fetchUser()) ?? '';
      await _fetchInitialRecommendations();
    } catch (e) {
      debugPrint('Error initializing data: $e');
    }
  }

  // --- NEW RECOMMENDATION LOGIC (COLD START) ---
  /// Fetches initial batch of movies (e.g., 5) on startup
  Future<void> _fetchInitialRecommendations() async {
    await _fetchBatchMovies(true, count: 5);
  }

  // NEW BATCH FETCH FUNCTION
  Future<void> _fetchBatchMovies(bool isInitialFetch, {int count = 5}) async {
    if (_isLoadingBatch) return;
    _isLoadingBatch = true;

    // ✅ Run heavy work in a microtask to not block the current frame
    Future.microtask(() async {
      try {

        debugPrint(
            "🎬 FETCHING BATCH (isInitial: $isInitialFetch, count: $count)");

        final batch = await _backendService
            .fetchBatchRecommendations(_uid, isInitialFetch, count: count);

        if (batch.isEmpty) {
          debugPrint("❌ Backend returned empty batch!");
          _isLoadingBatch = false;
          return;
        }

        // ✅ Filter duplicates BEFORE making TMDB calls
        final newBatch = batch
            .where(
                (item) => !_allMovies.any((m) => int.tryParse(m.id) == item.$1))
            .toList();

        if (newBatch.isEmpty) {
          debugPrint("⚠️ All movies were duplicates");
          _isLoadingBatch = false;
          return;
        }

        // ✅ Parallel fetch with shorter timeout
        final futures = newBatch.map((item) {
          return _tmdbService
              .getMovieById(item.$1)
              .timeout(const Duration(seconds: 3), onTimeout: () => null)
              .then((movie) => MapEntry(item.$2, movie));
        }).toList();

        final results = await Future.wait(futures);

        // Process results
        final newMovies = <Movie>[];
        final newIndices = <String, int>{};

        for (final entry in results) {
          final movie = entry.value;
          if (movie != null) {
            newMovies.add(movie);
            newIndices[movie.id] = entry.key;
          }
        }

        debugPrint(
            "✅ Added ${newMovies.length} movies. Total: ${_allMovies.length + newMovies.length}");

        // ✅ Batch update state only once
        if (mounted && newMovies.isNotEmpty) {
          setState(() {
            _allMovies.addAll(newMovies);
            _movieBackendIndices.addAll(newIndices);
          });
        }

      } catch (e) {
        debugPrint("❌ Batch Fetch Error: $e");
      } finally {
        _isLoadingBatch = false;
      }
    });
  }

  bool _onSwipe(
      int prevIndex, int? currentIndex, CardSwiperDirection direction) {
    // 1. BOUNDS CHECK (Fast)
    if (prevIndex >= _allMovies.length) return false;

    // 2. CAPTURE DATA (Fast)
    final swipedMovie = _allMovies[prevIndex];
    // Don't do heavy JSON serialization here if possible, but if needed, keep it light.

    // 3. UI UPDATES (Fast)
    // Only update local variables needed for the UI.
    // Defer everything else.
    _previousMovieIndex = prevIndex;
    if (currentIndex != null) {
      _currentMovieIndex = currentIndex;
      _lastKnownIndex = currentIndex;
    }

    // 4. FIRE AND FORGET (Async)
    // Do NOT await this. Let it run in the background.
    // We use a separate method that isolates the heavy logic.
    _handleBackgroundLogic(
        swipedMovie, direction, currentIndex ?? _currentMovieIndex);

    return true; // Return immediately to let the animation play smoothly
  }

  void _handleBackgroundLogic(
      Movie swipedMovie, CardSwiperDirection direction, int currentIdx) {
    // Use Microtask to ensure this runs strictly AFTER the animation frame starts
    Future.microtask(() {
      // A. Backend / Firebase Logic
      final movieJson = swipedMovie.toJson();
      final movieId = swipedMovie.id;
      final backendIndex = _movieBackendIndices[movieId];

      String actionType = 'DISLIKE';
      if (direction == CardSwiperDirection.right){
        actionType = 'WATCHED';
      }
      else if (direction == CardSwiperDirection.top) {
        actionType = 'WATCH_LATER';
      }

      // Fire backend calls (existing logic)
      _processSwipeAsync(
          swipedMovie, movieJson, movieId, direction, actionType, backendIndex);

      // B. HISTORY LOGIC (Moved here to unblock UI)
      _swipeHistory.add({
        'movieIndex': _previousMovieIndex, // Use stored previous index
        'direction': direction,
      });

      // C. BUFFER LOGIC - Schedule AFTER the frame is fully rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final int totalMovies = _allMovies.length;
        final int remainingCards = totalMovies - currentIdx - 1;

        if (remainingCards <= _bufferThreshold && !_isLoadingBatch) {
          debugPrint(
              "📉 Buffer low ($remainingCards left). Fetching in post-frame...");
          _fetchBatchMovies(false, count: _batchSize);
        }
      });
    });
  }

  // ✅ Updated to use captured data instead of index
  void _processSwipeAsync(
      Movie movie,
      Map<String, dynamic> movieJson,
      String movieId,
      CardSwiperDirection direction,
      String actionType,
      int? backendIndex) {
    Future.microtask(() async {
      try {
        // Firebase update with captured data
        _updateUserMoviesAsync(movie, movieJson, movieId, direction);

        // Backend update
        if (backendIndex != null) {
          _backendService.sendSwipe(_uid, backendIndex, actionType);
        }
      } catch (e) {
        debugPrint("Async swipe processing error: $e");
      }
    });
  }

  // ✅ Updated to use captured data
  void _updateUserMoviesAsync(Movie movie, Map<String, dynamic> movieJson,
      String movieId, CardSwiperDirection direction) {
    Future.microtask(() async {
      try {
        if (_user == null) return;

        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) return;

        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

        if (direction == CardSwiperDirection.right) {
          userRef.update({
            'watchedMovies': FieldValue.arrayUnion([movieJson]),
          });
          _user!.watchedMovies.add(movie);
        } else if (direction == CardSwiperDirection.top) {
          userRef.update({
            'watchLaterMovies': FieldValue.arrayUnion([movieJson]),
          });
          _user!.watchLaterMovies.add(movie);
        } else if (direction == CardSwiperDirection.left) {
          userRef.update({
            'notInterestedMovies': FieldValue.arrayUnion([movieId]),
          });
          _user!.notInterestedMovies.add(movieId);
        }
      } catch (e) {
        debugPrint('Async Firebase update error: $e');
      }
    });
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

      debugPrint('Undid action for movie: ${_allMovies[lastIndex].title}');
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
              currentIds.where((id) => id != _allMovies[lastIndex].id).toList();
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
            .where((movie) => movie.title != _allMovies[lastIndex].title)
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

  Future<String?> _fetchUser() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        setState(() {
          _user = user_profile.User.fromJson(userDoc.data()!);
        });
      } else {
        debugPrint("User document does not exist.");
      }
      return uid; // UID'yi döndür
    } catch (e) {
      debugPrint('Error fetching user: $e');
      Get.snackbar('Error', 'Error fetching user: $e');
      return null;
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
                  fit: BoxFit.fill,
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

  final WidgetStateProperty<Color?> overlayColor =
      WidgetStateProperty<Color?>.fromMap(
    <WidgetState, Color>{
      WidgetState.selected:
          const Color.fromARGB(255, 255, 7, 7).withOpacity(0.54),
      WidgetState.disabled: Colors.grey.shade400,
    },
  );

  final WidgetStateProperty<Color?> thumbColor =
      WidgetStateProperty<Color?>.fromMap(
    <WidgetStatesConstraint, Color>{
      WidgetState.selected: const Color.fromARGB(255, 255, 255, 255),
      WidgetState.any: Colors.grey.shade400,
    },
  );

  final WidgetStateProperty<Icon> thumbIcon = WidgetStateProperty<Icon>.fromMap(
    <WidgetStatesConstraint, Icon>{
      WidgetState.selected: Icon(Icons.check, color: Colors.black),
      WidgetState.any: Icon(Icons.close),
    },
  );

  final WidgetStateProperty<Color?> trackColor =
      WidgetStateProperty<Color?>.fromMap(
    <WidgetStatesConstraint, Color>{
      WidgetState.selected: const Color.fromARGB(255, 255, 7, 7)
    },
  );

  List<String> genres = GenrePreferenceScreen.genres;

  Widget _swipePage() {
    if (_allMovies.isEmpty) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              //Info Button
              IconButton(
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
                    color: Color.fromARGB(255, 226, 226, 226)),
              ),
            ],
          ),
          Expanded(
            flex: 7,
            child: CardSwiper(
              key: _cardSwiperKey,
              controller: controller,
              cardsCount: _allMovies.length, // Add extra cards for loading
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
                if (index >= _allMovies.length) {
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

                final movie = _allMovies[index];
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
                                movie.posterPath), // ✅ Already full URL
                            fit: BoxFit
                                .fill, // Also: use cover instead of fill for better aspect ratio
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
