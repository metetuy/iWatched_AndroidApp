import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendService {
  final String baseUrl = "10.0.2.2:5000"; 

  // List of (TMDB_ID, Backend_Index)
  Future<List<(int, int)>> fetchBatchRecommendations(String userId, bool isInitialFetch, {int count = 5}) async {
    try {

      final http.Response response;

      if(isInitialFetch){
        response = await http.get(Uri.parse('$baseUrl/initial_recommendations/$userId?count=$count'));
      }
      else{
        response = await http.get(Uri.parse('$baseUrl/recommendations/$userId?count=$count'));
      }
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'];
        
        List<(int, int)> batch = [];
        for (var item in results) {
          batch.add((item['tmdb_id'] as int, item['index'] as int));
        }
        return batch;
      }
    } catch (e) {
      debugPrint("Backend Batch Error: $e");
    }
    return [];
  }

  // Swipe artık sadece status dönüyor, film beklemiyoruz
  Future<void> sendSwipe(String userId, int movieIndex, String action) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/swipe'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": userId,
          "movie_index": movieIndex,
          "action": action,
        }),
      );
    } catch (e) {
      debugPrint("Backend Swipe Error: $e");
    }
  }
}