import numpy as np
from fastapi import FastAPI, HTTPException

from config import CSV_PATH, MODEL_PATH
from engine import RecommendationEngine
from models import SwipeRequest

app = FastAPI()

# --- GLOBAL INSTANCE ---
engine = RecommendationEngine(CSV_PATH, MODEL_PATH)


# --- API ENDPOINTS ---

@app.get("/")
def read_root():
    """Health check endpoint."""
    return {"status": "Running", "movie_count": len(engine.df)}


@app.get("/recommendations/{user_id}")
def get_recommendations(user_id: str, count: int = 5):
    """Get personalized movie recommendations using hybrid ranking."""
    results = engine.recommend(user_id, count=count, is_initial_fetch=False)
    return {"results": results}


@app.get("/initial_recommendations/{user_id}")
def get_initial_recommendations(user_id: str, count: int = 5):
    """Get initial recommendations using cold start strategy."""
    results = engine.recommend(user_id, count=count, is_initial_fetch=True)
    return {"results": results}


@app.post("/swipe")
def swipe(req: SwipeRequest):
    """Record a user's swipe action and update their profile."""
    if req.movie_index < 0 or req.movie_index >= len(engine.df):
        raise HTTPException(status_code=400, detail="Invalid movie index")
    valid_actions = {"LIKED", "WATCHED", "WATCH_LATER", "DISLIKE"}
    if req.action not in valid_actions:
        raise HTTPException(status_code=400, detail=f"Invalid action. Must be one of: {valid_actions}")
    engine.update_profile(req.user_id, req.movie_index, req.action)
    return {"status": "success", "message": "Profile updated"}


@app.get("/debug/user/{user_id}")
def debug_user(user_id: str):
    """Debug endpoint to view user's top interests."""
    return engine.get_user_profile_analysis(user_id)


@app.get("/debug/knn/{user_id}")
def debug_knn(user_id: str, top_words: int = 20, top_candidates: int = 10):
    """Debug endpoint to inspect KNN recommendations for a user."""
    user_vec = engine.get_user_vector(user_id)
    seen_movies = engine.user_seen_movies.get(user_id, set())

    feature_names = engine.tfidf.get_feature_names_out()
    feature_scores = list(zip(feature_names, user_vec))

    sorted_features = sorted(feature_scores, key=lambda x: x[1], reverse=True)
    top_positive = [(word, round(score, 4)) for word, score in sorted_features[:top_words] if score > 0]

    sorted_negative = sorted(feature_scores, key=lambda x: x[1])
    top_negative = [(word, round(score, 4)) for word, score in sorted_negative[:top_words] if score < 0]

    n_candidates = top_candidates * 5
    distances, indices = engine.model.kneighbors([user_vec], n_neighbors=n_candidates)

    candidates = []
    for i, idx in enumerate(indices[0]):
        idx = int(idx)
        movie = engine.df.iloc[idx]
        similarity = round(1 - distances[0][i], 4)

        candidates.append({
            "rank": i + 1,
            "title": str(movie['title']),
            "genres": str(movie.get('genres', '')),
            "similarity": similarity,
            "popularity": round(float(movie.get('norm_popularity', 0)), 4),
            "rating": float(movie.get('vote_average', 0)),
            "votes": int(movie.get('vote_count', 0)),
            "already_seen": idx in seen_movies,
            "index": idx
        })

    genre_counts: dict = {}
    for c in candidates[:top_candidates]:
        for genre in c['genres'].split(', '):
            genre = genre.strip()
            if genre:
                genre_counts[genre] = genre_counts.get(genre, 0) + 1

    return {
        "user_id": user_id,
        "seen_movies_count": len(seen_movies),
        "user_vector_magnitude": round(float(np.linalg.norm(user_vec)), 4),
        "top_positive_words": top_positive,
        "top_negative_words": top_negative,
        "genre_distribution_in_results": dict(sorted(genre_counts.items(), key=lambda x: x[1], reverse=True)),
        "knn_candidates": candidates[:top_candidates]
    }


@app.get("/lookup/{tmdb_id}")
def lookup_movie_index(tmdb_id: int):
    """Look up the backend index for a given TMDB ID."""
    if tmdb_id in engine.tmdb_id_to_index:
        index = engine.tmdb_id_to_index[tmdb_id]
        return {"tmdb_id": tmdb_id, "index": index}
    return {"tmdb_id": tmdb_id, "index": None}