import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:iwatched/models/movie.dart';
import 'package:iwatched/models/user.dart' as user_profile;
import 'package:iwatched/services/backend_service.dart';
import 'package:iwatched/services/tmdb_service.dart';

class SwipeController extends GetxController {
  final TMDBService _tmdbService = TMDBService();
  final BackendService _backendService = BackendService();

  // Observable state
  final RxList<Movie> movies = <Movie>[].obs;
  final Rx<user_profile.User?> user = Rx<user_profile.User?>(null);
  final RxBool isLoading = false.obs;
  final RxInt currentIndex = 0.obs;

  // Internal state
  final Map<String, int> _movieBackendIndices = {};
  final List<Map<String, dynamic>> _swipeHistory = [];
  String _uid = '';

  // Buffer settings
  static const int _bufferThreshold = 3;
  static const int _batchSize = 10;
  bool _isLoadingBatch = false;

  String get uid => _uid;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    _uid = await _fetchUser() ?? '';
    
    // DEBUG: Check what we got
    debugPrint("═══════════════════════════════════════════");
    debugPrint("🔐 INIT DEBUG");
    debugPrint("   _uid after fetch: '$_uid'");
    debugPrint("   _uid is empty: ${_uid.isEmpty}");
    debugPrint("═══════════════════════════════════════════");
    
    if (_uid.isEmpty) {
      debugPrint("❌ Cannot fetch recommendations - UID is empty!");
      isLoading.value = false;
      return;
    }
    
    await fetchInitialRecommendations();
  }

  Future<String?> _fetchUser() async {
    try {
      // Check if user is logged in first
      final currentUser = FirebaseAuth.instance.currentUser;
      
      debugPrint("🔍 Checking Firebase Auth...");
      debugPrint("   currentUser: $currentUser");
      debugPrint("   currentUser is null: ${currentUser == null}");
      
      if (currentUser == null) {
        debugPrint("❌ No user logged in!");
        return null;
      }
      
      final uid = currentUser.uid;
      debugPrint("   UID from Firebase Auth: $uid");
      
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        user.value = user_profile.User.fromJson(userDoc.data()!);
        debugPrint("   ✅ User document loaded");
      } else {
        debugPrint("   ⚠️ User document doesn't exist in Firestore");
      }
      return uid;
    } catch (e, stackTrace) {
      debugPrint('❌ Error fetching user: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> fetchInitialRecommendations() async {
    await _fetchBatchMovies(isInitial: true, count: 5);
  }

  Future<void> _fetchBatchMovies({required bool isInitial, int count = 5}) async {
    if (_isLoadingBatch) return;
    _isLoadingBatch = true;
    
    if (isInitial) isLoading.value = true;

    try {
      final batch = await _backendService.fetchBatchRecommendations(
        _uid,
        isInitial,
        count: count,
      );

      if (batch.isEmpty) {
        debugPrint("❌ Backend returned empty batch!");
        return;
      }

      // Filter duplicates
      final newBatch = batch
          .where((item) => !movies.any((m) => int.tryParse(m.id) == item.$1))
          .toList();

      if (newBatch.isEmpty) {
        debugPrint("⚠️ All movies were duplicates");
        return;
      }

      // Parallel TMDB fetch
      final futures = newBatch.map((item) {
        return _tmdbService
            .getMovieById(item.$1)
            .timeout(const Duration(seconds: 3), onTimeout: () => null)
            .then((movie) => MapEntry(item.$2, movie));
      }).toList();

      final results = await Future.wait(futures);

      final newMovies = <Movie>[];
      final newIndices = <String, int>{};

      for (final entry in results) {
        final movie = entry.value;
        if (movie != null) {
          newMovies.add(movie);
          newIndices[movie.id] = entry.key;
        }
      }

      if (newMovies.isNotEmpty) {
        movies.addAll(newMovies);
        _movieBackendIndices.addAll(newIndices);
      }

      debugPrint("✅ Added ${newMovies.length} movies. Total: ${movies.length}");
    } catch (e) {
      debugPrint("❌ Batch Fetch Error: $e");
    } finally {
      _isLoadingBatch = false;
      isLoading.value = false;
    }
  }

  void checkAndFetchMoreIfNeeded(int currentIdx) {
    final remainingCards = movies.length - currentIdx - 1;
    if (remainingCards <= _bufferThreshold && !_isLoadingBatch) {
      debugPrint("📉 Buffer low ($remainingCards left). Fetching...");
      _fetchBatchMovies(isInitial: false, count: _batchSize);
    }
  }

  bool handleSwipe(int prevIndex, int? newIndex, CardSwiperDirection direction) {
    if (prevIndex >= movies.length) return false;

    final swipedMovie = movies[prevIndex];
    
    if (newIndex != null) {
      currentIndex.value = newIndex;
    }

    // Record history
    _swipeHistory.add({
      'movieIndex': prevIndex,
      'direction': direction,
    });

    // Process in background
    _processSwipe(swipedMovie, direction);

    // Check buffer after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAndFetchMoreIfNeeded(currentIndex.value);
    });

    return true;
  }

  void _processSwipe(Movie movie, CardSwiperDirection direction) {
    Future.microtask(() async {
      final movieJson = movie.toJson();
      final movieId = movie.id;
      final backendIndex = _movieBackendIndices[movieId];

      String actionType = _getActionType(direction);

      // Update Firebase
      _updateFirebase(movie, movieJson, movieId, direction);

      // Update backend
      if (backendIndex != null) {
        _backendService.sendSwipe(_uid, backendIndex, actionType);
      }
    });
  }

  String _getActionType(CardSwiperDirection direction) {
    switch (direction) {
      case CardSwiperDirection.right:
        return 'WATCHED';
      case CardSwiperDirection.top:
        return 'WATCH_LATER';
      default:
        return 'DISLIKE';
    }
  }

  void _updateFirebase(Movie movie, Map<String, dynamic> movieJson,
      String movieId, CardSwiperDirection direction) {
    Future.microtask(() async {
      if (user.value == null) return;

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      switch (direction) {
        case CardSwiperDirection.right:
          userRef.update({'watchedMovies': FieldValue.arrayUnion([movieJson])});
          user.value!.watchedMovies.add(movie);
          break;
        case CardSwiperDirection.top:
          userRef.update({'watchLaterMovies': FieldValue.arrayUnion([movieJson])});
          user.value!.watchLaterMovies.add(movie);
          break;
        case CardSwiperDirection.left:
          userRef.update({'notInterestedMovies': FieldValue.arrayUnion([movieId])});
          user.value!.notInterestedMovies.add(movieId);
          break;
        default:
          break;
      }
    });
  }

  bool handleUndo(int? previousIndex, int currentIdx, CardSwiperDirection direction) {
    if (_swipeHistory.isEmpty) {
      Get.snackbar('Undo Error', 'No more actions to undo');
      return false;
    }

    try {
      final lastSwipe = _swipeHistory.removeLast();
      final lastDirection = lastSwipe['direction'] as CardSwiperDirection;
      final lastIndex = lastSwipe['movieIndex'] as int;

      currentIndex.value = lastIndex;

      _handleUndoFirebase(lastIndex, lastDirection);

      debugPrint('Undid action for movie: ${movies[lastIndex].title}');
      return true;
    } catch (e) {
      debugPrint('Error during undo: $e');
      Get.snackbar('Error', 'Failed to undo last action');
      return false;
    }
  }

  void _handleUndoFirebase(int lastIndex, CardSwiperDirection lastDirection) {
    Future(() async {
      try {
        if (user.value == null) {
          await _fetchUser();
          if (user.value == null) return;
        }

        final uid = FirebaseAuth.instance.currentUser!.uid;
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

        if (lastDirection == CardSwiperDirection.left) {
          final updatedIds = user.value!.notInterestedMovies
              .where((id) => id != movies[lastIndex].id)
              .toList();
          await userRef.update({'notInterestedMovies': updatedIds});
          return;
        }

        final listName = lastDirection == CardSwiperDirection.top
            ? 'watchLaterMovies'
            : 'watchedMovies';

        final currentList = lastDirection == CardSwiperDirection.top
            ? user.value!.watchLaterMovies
            : user.value!.watchedMovies;

        final updatedList = currentList
            .where((movie) => movie.title != movies[lastIndex].title)
            .map((movie) => movie.toJson())
            .toList();

        await userRef.update({listName: updatedList});
        await _fetchUser();
      } catch (e) {
        debugPrint('Error updating Firebase during undo: $e');
      }
    });
  }

  Future<void> removeFromWatchLater(Movie movie, int index) async {
    try {
      final updatedList = user.value!.watchLaterMovies
          .where((m) => m.title != movie.title)
          .map((m) => m.toJson())
          .toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'watchLaterMovies': updatedList});

      user.value!.watchLaterMovies.removeAt(index);
      user.refresh(); // Trigger UI update
    } catch (e) {
      debugPrint('Error removing movie: $e');
    }
  }
}