import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BackendService {
  final String baseUrl = "http://10.0.2.2:8000"; 

  // List of (TMDB_ID, Backend_Index)
  Future<List<(int, int)>> fetchBatchRecommendations(String userId, bool isInitialFetch, {int count = 5}) async {
    
    debugPrint("═══════════════════════════════════════════");
    debugPrint("🌐 BACKEND REQUEST");
    debugPrint("═══════════════════════════════════════════");
    debugPrint("   User ID: $userId");
    debugPrint("   Is Initial: $isInitialFetch");
    debugPrint("   Count: $count");
    
    if (userId.isEmpty) {
      debugPrint("   ❌ ERROR: User ID is empty!");
      return [];
    }
    
    final endpoint = isInitialFetch
        ? '$baseUrl/initial_recommendations/$userId?count=$count'
        : '$baseUrl/recommendations/$userId?count=$count';
    
    debugPrint("   URL: $endpoint");
    
    try {
      debugPrint("   📡 Sending request...");
      
      final response = await http.get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 15));
      
      debugPrint("   ✅ Response received!");
      debugPrint("   Status Code: ${response.statusCode}");
      debugPrint("   Body length: ${response.body.length}");
      debugPrint("   Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...");
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'];
        
        debugPrint("   📦 Parsed ${results.length} results");
        
        List<(int, int)> batch = [];
        for (var item in results) {
          batch.add((item['tmdb_id'] as int, item['index'] as int));
        }
        
        debugPrint("   ✅ Returning ${batch.length} movies");
        debugPrint("═══════════════════════════════════════════");
        return batch;
      } else {
        debugPrint("   ❌ Non-200 status: ${response.statusCode}");
        debugPrint("   Body: ${response.body}");
      }
    } on SocketException catch (e) {
      debugPrint("   ❌ SOCKET ERROR: Cannot connect to server!");
      debugPrint("   Details: $e");
      debugPrint("   💡 Is the backend running? Try: uvicorn main:app --host 0.0.0.0 --port 5000");
    } on http.ClientException catch (e) {
      debugPrint("   ❌ CLIENT ERROR: $e");
    } on FormatException catch (e) {
      debugPrint("   ❌ JSON PARSE ERROR: $e");
    } catch (e) {
      debugPrint("   ❌ UNEXPECTED ERROR: $e");
      debugPrint("   Type: ${e.runtimeType}");
    }
    
    debugPrint("═══════════════════════════════════════════");
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