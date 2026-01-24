class Movie {
  final String id;
  final String title;
  final String posterPath;
  final String year;
  final String runtime;
  final List<String> genres;
  final double rating;
  final String overview;
  final String backdropPath;

  Movie({
    required this.id,
    required this.title,
    required this.year,
    required this.runtime,
    required this.posterPath,
    required this.genres,
    required this.rating,
    required this.overview,
    required this.backdropPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'poster_path': posterPath,
      'year': year,
      'runtime': runtime,
      'genres': genres,
      'rating': rating,
      'overview': overview,
      'backdrop_path': backdropPath,
    };
  }

  factory Movie.fromJson(Map<String, dynamic> json, Map<int, String> genreMap) {
    String releaseYear = 'Unknown';
    if (json['release_date'] != null &&
        json['release_date'].toString().isNotEmpty) {
      // Parse the date string which comes in format "YYYY-MM-DD"
      releaseYear = json['release_date'].toString().substring(0, 4);
    }

    return Movie(
      id: json['id'].toString(),
      title: json['title'] ?? 'Unknown Title',
      posterPath: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}'
          : '',
      genres: (json['genre_ids'] as List<dynamic>?)
              ?.map((id) => genreMap[id] ?? 'Unknown')
              .toList() ??
          [],
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      year: releaseYear,
      runtime: json['runtime'] != null ? '${json['runtime']}' : 'Unknown',
      overview: json['overview'] ?? 'No overview available',
      backdropPath: json['backdrop_path'] != null
          ? 'https://image.tmdb.org/t/p/w1280${json['backdrop_path']}'
          : '',
    );
  }

  factory Movie.fromJustJson(Map<String, dynamic> json) {
    return Movie(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      posterPath: json['poster_path'] ?? '',
      year: json['year'] ?? '',
      runtime: json['runtime'] ?? '',
      genres: List<String>.from(json['genres'] ?? []),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      overview: json['overview'] ?? 'No overview available',
      backdropPath: json['backdrop_path'] ?? '',
    );
  }
}
