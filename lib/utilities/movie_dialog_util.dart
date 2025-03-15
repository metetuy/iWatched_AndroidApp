import 'package:flutter/material.dart';
import 'package:iwatched/models/movie.dart';

class MovieDialogUtil {
  /// Shows a movie details dialog
  ///
  /// Parameters:
  /// - context: BuildContext to show the dialog
  /// - movie: Movie object containing the details
  /// - genreButtonBuilder: Function to build genre buttons
  /// - onClose: Optional callback when dialog is closed
  /// - onWatched/onSkip/onLater: Optional callbacks for action buttons
  static Future<void> showMovieDetailsDialog({
    required BuildContext context,
    required Movie movie,
    required List<Widget> Function(List<String>) genreButtonBuilder,
    VoidCallback? onClose,
    VoidCallback? onWatched,
    VoidCallback? onSkip,
    VoidCallback? onLater,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        pageBuilder: (BuildContext context, _, __) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: const Color.fromARGB(197, 32, 32, 32),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Scaffold(
                  backgroundColor: const Color.fromARGB(197, 32, 32, 32),
                  body: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          // Backdrop image with gradient overlay
                          children: [
                            SizedBox(
                              height: 220,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  "https://image.tmdb.org/t/p/w1280${movie.backdropPath}",
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[800],
                                      child: const Center(
                                        child: Icon(Icons.error_outline,
                                            color: Colors.white, size: 40),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Container(
                              height: 220,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black,
                                  ],
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  if (onClose != null) onClose();
                                },
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: 30,
                                  color: Colors.white.withAlpha(160),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
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
                              const SizedBox(height: 8),
                              Row(
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
                                  const SizedBox(width: 16),
                                  Text(
                                    "Year: ${movie.year}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Overview",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                movie.overview,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.justify,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Genres",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                direction: Axis.horizontal,
                                alignment: WrapAlignment.start,
                                spacing: 8,
                                runSpacing: 8,
                                children: genreButtonBuilder(movie.genres),
                              ),

                              // Add action buttons if callbacks are provided
                              if (onWatched != null ||
                                  onSkip != null ||
                                  onLater != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 24.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      if (onSkip != null)
                                        _buildActionButton(
                                          icon: Icons.close,
                                          color: Colors.red,
                                          label: "Skip",
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            onSkip();
                                          },
                                        ),
                                      if (onLater != null)
                                        _buildActionButton(
                                          icon: Icons.alarm_add,
                                          color: Colors.blue,
                                          label: "Later",
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            onLater();
                                          },
                                        ),
                                      if (onWatched != null)
                                        _buildActionButton(
                                          icon: Icons.check,
                                          color: Colors.green,
                                          label: "Watched",
                                          onTap: () {
                                            Navigator.of(context).pop();
                                            onWatched();
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
      ),
    );
  }

  /// Helper method to build action buttons
  static Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
