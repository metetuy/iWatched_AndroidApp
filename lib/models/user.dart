import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iwatched/models/movie.dart';

class User {
  //Personal info
  String? imageProfile;
  String? name;
  int? age;
  String? email;
  String? password;
  String? country;
  int? publishedDateTime;

  //Genre preference
  List<String> selectedGenres = [];
  List<Movie> watchedMovies = [];
  List<Movie> watchLaterMovies = [];
  List<String> notInterestedMovies = [];

  User({
    this.imageProfile,
    this.name,
    this.age,
    this.email,
    this.password,
    this.country,
    this.publishedDateTime,
    this.selectedGenres = const [],
    this.watchedMovies = const [],
    this.watchLaterMovies = const [],
    this.notInterestedMovies = const [],
  });

  static User fromDataSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return User(
      imageProfile: data['imageProfile'],
      name: data['name'],
      age: data['age'],
      email: data['email'],
      password: data['password'],
      country: data['country'],
      publishedDateTime: data['publishedDateTime'],
      selectedGenres: List<String>.from(data['selectedGenres']),
      watchedMovies: List<Movie>.from(data['watchedMovies']),
      watchLaterMovies: List<Movie>.from(data['watchLaterMovies']),
      notInterestedMovies: List<String>.from(data['notInterestedMovies']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageProfile': imageProfile,
      'name': name,
      'age': age,
      'email': email,
      'password': password,
      'country': country,
      'publishedDateTime': publishedDateTime,
      'selectedGenres': selectedGenres,
      'watchedMovies': watchedMovies,
      'watchLaterMovies': watchLaterMovies,
      'notInterestedMovies': notInterestedMovies,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      imageProfile: json['imageProfile'],
      name: json['name'],
      age: json['age'],
      email: json['email'],
      password: json['password'],
      country: json['country'],
      publishedDateTime: json['publishedDateTime'],
      selectedGenres: List<String>.from(json['selectedGenres']),
      watchedMovies: (json['watchedMovies'] as List)
          .map((movie) => Movie.fromJustJson(movie))
          .toList(),
      watchLaterMovies: (json['watchLaterMovies'] as List)
          .map((movie) => Movie.fromJustJson(movie))
          .toList(),
      notInterestedMovies: List<String>.from(json['notInterestedMovies']),
    );
  }
}
