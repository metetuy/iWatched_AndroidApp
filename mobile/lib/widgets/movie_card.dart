import 'package:flutter/material.dart';
import 'package:iwatched/models/movie.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback? onTap;
  final List<Widget> Function(List<String>) genreButtonBuilder;

  const MovieCard({
    super.key,
    required this.movie,
    required this.genreButtonBuilder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Background placeholder
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: const Color.fromARGB(255, 41, 41, 41),
            ),
          ),
          // Poster image
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              image: DecorationImage(
                image: NetworkImage(movie.posterPath),
                fit: BoxFit.fill,
              ),
            ),
          ),
          // Gradient overlay
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
          // Movie info
          Positioned(
            bottom: 80,
            left: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 10),
                
                // Genre buttons
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: genreButtonBuilder(movie.genres),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Rating
          Positioned(
            bottom: 50,
            left: 10,
            child: Row(
              children: [
                Image.asset("images/tmdbLogo.png", width: 45),
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
  }
}