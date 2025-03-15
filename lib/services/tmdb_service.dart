import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:iwatched/models/movie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TMDBService {
  static final String _apiKey = dotenv.env['TMDB_API_KEY'] ?? '';
  static final String _baseUrl = 'https://api.themoviedb.org/3';
  int _currentPage = 1;
  bool _isFetching = false;
  final Set<int> _fetchedMovieIds = {};

  // Add this cache
  Map<int, String>? _genreMapCache;

  Future<Map<int, String>> _fetchGenreMap() async {
    // Use cached genre map if available
    if (_genreMapCache != null) return _genreMapCache!;

    final url =
        Uri.parse('$_baseUrl/genre/movie/list?api_key=$_apiKey&language=en-US');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final genres = data['genres'] as List<dynamic>;
      _genreMapCache = {for (var genre in genres) genre['id']: genre['name']};
      return _genreMapCache!;
    } else {
      throw Exception('Failed to load genres');
    }
  }

  void incrementPage() {
    _currentPage++;
  }

  Future<List<Movie>> searchMovies(String query) async {
    if (query.isEmpty) return [];
    try {
      final genreMap = await _fetchGenreMap();
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
          '$_baseUrl/search/movie?api_key=$_apiKey&language=en-US&query=$encodedQuery&include_adult=false');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> moviesJson = data['results'];

        // Filter out movies that have no poster or backdrop
        final filteredMovies =
            moviesJson.where((movie) => movie['poster_path'] != null).toList();

        return filteredMovies
            .map((json) => Movie.fromJson(json, genreMap))
            .toList();
      } else {
        throw Exception('Failed to search movies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search movies: $e');
    }
  }

  Future<List<Movie>> getPopularMovies() async {
    if (_isFetching) return [];
    _isFetching = true;

    try {
      final genreMap = await _fetchGenreMap();
      final url = Uri.parse(
          '$_baseUrl/movie/top_rated?api_key=$_apiKey&language=en-US&page=$_currentPage');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> moviesJson = data['results'];

        final newMovies = moviesJson.where((movie) {
          final movieId = movie['id'] as int;
          if (!_fetchedMovieIds.contains(movieId)) {
            _fetchedMovieIds.add(movieId);
            return true;
          }
          return false;
        }).toList();

        return newMovies.map((json) => Movie.fromJson(json, genreMap)).toList();
      } else {
        throw Exception('Failed to load popular movies');
      }
    } finally {
      _isFetching = false;
    }
  }
}
