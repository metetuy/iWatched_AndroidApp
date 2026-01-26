import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:get/get.dart';
import 'package:iwatched/controllers/swipe_controller.dart';
import 'package:iwatched/utilities/movie_dialog_util.dart';

class WatchLaterPage extends StatelessWidget {
  const WatchLaterPage({super.key});

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
    final SwipeController controller = Get.find<SwipeController>();

    return Obx(() {
      final user = controller.user.value;

      if (user == null) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.red),
        );
      }

      if (user.watchLaterMovies.isEmpty) {
        return const Center(
          child: Text(
            'No watch later movies found.',
            style: TextStyle(color: Colors.white),
          ),
        );
      }

      return ListView.builder(
        itemCount: user.watchLaterMovies.length,
        itemBuilder: (context, index) {
          final movie = user.watchLaterMovies[index];
          return ListTile(
            onTap: () {
              MovieDialogUtil.showMovieDetailsDialog(
                context: context,
                movie: movie,
                genreButtonBuilder: _buildGenreButtons,
                onWatched: () => controller.handleAction(
                    movie, index, CardSwiperDirection.right),
                onSkip: () => controller.handleAction(
                    movie, index, CardSwiperDirection.left),
                onLike: () => controller.handleAction(
                    movie, index, CardSwiperDirection.bottom),
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
                    child: const Icon(Icons.error_outline, color: Colors.white),
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
              style: const TextStyle(color: Colors.grey),
            ),
          );
        },
      );
    });
  }
}
