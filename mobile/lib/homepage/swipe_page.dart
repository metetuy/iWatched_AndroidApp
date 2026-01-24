import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:get/get.dart';
import 'package:iwatched/controllers/swipe_controller.dart';
import 'package:iwatched/utilities/movie_dialog_util.dart';
import 'package:iwatched/widgets/movie_card.dart';
import 'package:iwatched/widgets/swipe_action_buttons.dart';

class SwipePage extends StatelessWidget {
  SwipePage({super.key});

  final CardSwiperController cardController = CardSwiperController();

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

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'About iWatched',
          style: TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'iWatched is a movie recommendation app that helps you find movies you like. '
          'Swipe right to add a movie to your watched list, swipe left to add a movie '
          'to your not interested list, and swipe up to add a movie to your watch later list. Enjoy!',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SwipeController controller = Get.find<SwipeController>();

    return Obx(() {
      if (controller.movies.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.red),
        );
      }

      return SafeArea(
        bottom: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _showInfoDialog(context),
                child: const Padding(
                  padding: EdgeInsets.only(right: 30, top: 20),
                  child: Icon(
                    Icons.info,
                    color: Color.fromARGB(255, 226, 226, 226),
                  ),
                ),
              ),
            ),

            // Card swiper
            Expanded(
              child: CardSwiper(
                controller: cardController,
                cardsCount: controller.movies.length,
                scale: 0.7,
                onSwipe: controller.handleSwipe,
                onUndo: controller.handleUndo,
                allowedSwipeDirection: AllowedSwipeDirection.all(),
                initialIndex: controller.currentIndex.value,
                cardBuilder:
                    (context, index, percentThresholdX, percentThresholdY) {
                  if (index >= controller.movies.length) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.red),
                          SizedBox(height: 16),
                          Text('Loading more movies...',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    );
                  }

                  final movie = controller.movies[index];
                  return MovieCard(
                    movie: movie,
                    genreButtonBuilder: _buildGenreButtons,
                    onTap: () {
                      MovieDialogUtil.showMovieDetailsDialog(
                        context: context,
                        movie: movie,
                        genreButtonBuilder: _buildGenreButtons,
                        onWatched: () =>
                            cardController.swipe(CardSwiperDirection.right),
                        onSkip: () =>
                            cardController.swipe(CardSwiperDirection.left),
                        onLater: () =>
                            cardController.swipe(CardSwiperDirection.top),
                        onLike: () => 
                            cardController.swipe(CardSwiperDirection.bottom)
                      );
                    },
                  );
                },
              ),
            ),
            // Action buttons
            SwipeActionButtons(controller: cardController),
          ],
        ),
      );
    });
  }
}
