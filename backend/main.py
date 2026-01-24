import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import pandas as pd
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.neighbors import NearestNeighbors
from sklearn.preprocessing import MinMaxScaler
from difflib import SequenceMatcher
import joblib
from typing import Any, Dict, List, Set

load_dotenv()

# Build credentials from environment variables
cred_dict = {
    "type": "service_account",
    "project_id": os.getenv("FIREBASE_PROJECT_ID"),
    "private_key_id": os.getenv("FIREBASE_PRIVATE_KEY_ID"),
    "private_key": os.getenv("FIREBASE_PRIVATE_KEY").replace("\\n", "\n"),
    "client_email": os.getenv("FIREBASE_CLIENT_EMAIL"),
    "client_id": os.getenv("FIREBASE_CLIENT_ID"),
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": f"https://www.googleapis.com/robot/v1/metadata/x509/{os.getenv('FIREBASE_CLIENT_EMAIL').replace('@', '%40')}",
    "universe_domain": "googleapis.com"
}

cred = credentials.Certificate(cred_dict)
firebase_admin.initialize_app(cred)

# --- DEBUG SETTINGS ---
DEBUG_MODE = True  # Set to False to disable verbose logging

def debug_print(msg: str, level: str = "INFO"):
    """Print colored debug output to console."""
    if not DEBUG_MODE:
        return
    colors = {
        "INFO": "\033[94m",      # Blue
        "SUCCESS": "\033[92m",   # Green
        "WARNING": "\033[93m",   # Yellow
        "ERROR": "\033[91m",     # Red
        "HEADER": "\033[95m",    # Magenta
        "DATA": "\033[96m",      # Cyan
    }
    reset = "\033[0m"
    color = colors.get(level, "")
    print(f"{color}[{level}] {msg}{reset}")

# --- CONFIGURATION ---
CSV_PATH = 'movies_dataset_final.csv'
MODEL_PATH = 'model_data.pkl'
MAX_FEATURES = 5000 
MIN_VOTE_COUNT = 100
MIN_VOTE_AVERAGE = 5.5

# --- SCORING WEIGHTS ---
POPULARITY_WEIGHT = 0.35
CONTENT_WEIGHT = 0.35
RATING_WEIGHT = 0.20
VOTE_COUNT_WEIGHT = 0.10

SEQUEL_PENALTY = 0.25  # Penalty multiplier for sequel/similar titles

db = firestore.client()
app = FastAPI()


class RecommendationEngine:
    """
    Content-based movie recommendation engine using TF-IDF vectorization
    and K-Nearest Neighbors for similarity matching.
    """
    
    def __init__(self, csv_path: str, model_path: str):
        self.csv_path = csv_path
        self.model_path = model_path
        
        # Model components
        self.df: pd.DataFrame = pd.DataFrame()
        self.tmdb_id_to_index: Dict[int, int] = {}
        self.tfidf: TfidfVectorizer = TfidfVectorizer()
        self.movie_vectors: Any = None
        self.model: NearestNeighbors = NearestNeighbors()
        
        # User state (in-memory cache)
        self.user_profiles: Dict[str, np.ndarray] = {}      
        self.user_seen_movies: Dict[str, Set[int]] = {}   
        self.user_liked_titles: Dict[str, List[str]] = {}  

        # Load existing model or train from scratch
        if os.path.exists(self.model_path):
            print(f"Found saved model: {self.model_path}")
            self.load_model()
        else:
            print(" No saved model found. Training from scratch...")
            self.train_and_save_model()

        print(" System initialized and Firebase connected!")

    def train_and_save_model(self) -> None:
        """Train the recommendation model and save to disk."""
        print("   -> Loading data...")
        self.df = pd.read_csv(self.csv_path).fillna('')
        
        # Convert numeric columns
        self.df['vote_count'] = pd.to_numeric(self.df['vote_count'], errors='coerce').fillna(0)
        self.df['vote_average'] = pd.to_numeric(self.df['vote_average'], errors='coerce').fillna(0)
        
        # Apply quality filter to remove low-quality movies
        original_count = len(self.df)
        self.df = self.df[
            (self.df['vote_count'] >= MIN_VOTE_COUNT) & 
            (self.df['vote_average'] >= MIN_VOTE_AVERAGE)
        ].reset_index(drop=True)
        print(f"   -> Quality filter: {original_count} → {len(self.df)} movies")
        
        # Build TMDB ID to DataFrame index mapping
        print("   -> Building ID mapping...")
        self.tmdb_id_to_index = {}
        for idx, row in self.df.iterrows():
            try:
                tmdb_id = int(row['id'])
                self.tmdb_id_to_index[tmdb_id] = int(idx)
            except (ValueError, TypeError):
                continue

        # Normalize popularity scores to [0, 1] range
        self.df['popularity'] = pd.to_numeric(self.df['popularity'], errors='coerce')
        self.df['popularity'] = self.df['popularity'].fillna(0)
        scaler = MinMaxScaler()
        self.df['norm_popularity'] = scaler.fit_transform(self.df[['popularity']].values).flatten()
        
        # Normalize ratings to [0, 1] range
        self.df['vote_average'] = pd.to_numeric(self.df['vote_average'], errors='coerce').fillna(0)
        self.df['norm_rating'] = self.df['vote_average'] / 10.0

        self.df['vote_count'] = pd.to_numeric(self.df['vote_count'], errors='coerce').fillna(0)
        self.df['log_vote_count'] = np.log1p(self.df['vote_count'])
        self.df['norm_vote_count'] = scaler.fit_transform(self.df[['log_vote_count']].values).flatten()
        
        # Create content "soup" for TF-IDF vectorization
        print("   -> Creating feature vectors (weighted by cast and director)...")
        self.df['soup'] = self.df.apply(self._create_soup, axis=1)
        
        # Fit TF-IDF vectorizer
        self.tfidf = TfidfVectorizer(stop_words='english', max_features=MAX_FEATURES, min_df=2)
        self.movie_vectors = self.tfidf.fit_transform(self.df['soup'])
        
        # Train KNN model for similarity search
        print("   -> Training KNN model...")
        self.model = NearestNeighbors(metric='cosine', algorithm='brute')
        self.model.fit(self.movie_vectors)
        
        # Save model to disk
        print(f"    Saving model to disk: {self.model_path}")
        save_data = {
            'df': self.df,
            'tmdb_id_to_index': self.tmdb_id_to_index,
            'tfidf': self.tfidf,
            'movie_vectors': self.movie_vectors,
            'model': self.model
        }
        joblib.dump(save_data, self.model_path)
        print("   Model saved successfully!")

    def load_model(self) -> None:
        """Load pre-trained model from disk."""
        print("   -> Loading model from file...")
        data = joblib.load(self.model_path)
        
        self.df = data['df']
        self.tmdb_id_to_index = data['tmdb_id_to_index']
        self.tfidf = data['tfidf']
        self.movie_vectors = data['movie_vectors']
        self.model = data['model']
        print("    Model loaded successfully!")

    def clean_data(self, x: Any) -> str:
        """
        Clean and normalize text data for cast and director fields.
        Removes spaces and converts to lowercase for better matching.
        """
        if isinstance(x, list):
            return " ".join([str.lower(i.replace(" ", "")) for i in x])
        else:
            if isinstance(x, str):
                items = x.split(',')
                cleaned = [item.strip().replace(" ", "").lower() for item in items]
                return " ".join(cleaned)
            return ""
        
    def _create_soup(self, x: pd.Series) -> str:
        """
        Create a combined text "soup" from movie metadata for TF-IDF vectorization.
        Director and cast are weighted higher (repeated 2x) to increase their influence.
        """
        director = self.clean_data(x.get('director', ''))
        cast = self.clean_data(x.get('cast', ''))
        keywords = str(x.get('keywords', '')).strip()
        genres = str(x.get('genres', '')).strip()
        overview = str(x.get('overview', '')).strip()
        
        return (
            (director + ' ') * 2 + 
            (cast + ' ') * 2 + 
            (genres + ' ') * 2 + 
            (keywords + ' ') * 1 + 
            (overview + ' ') * 1
        )

    def load_user_from_firebase(self, user_id: str) -> None:
        """
        Load user's movie history from Firebase and initialize their profile vector.
        Only positive interactions (liked, watched, watch later) affect the profile.
        Disliked movies are only tracked to avoid re-showing them.
        """
        debug_print(f"═══════════════════════════════════════════", "HEADER")
        debug_print(f"📥 FIREBASE LOAD: {user_id[:8]}...", "HEADER")
        debug_print(f"═══════════════════════════════════════════", "HEADER")
        
        try:
            doc = db.collection('users').document(user_id).get()
            if not doc.exists:
                debug_print("User not found in Firebase - New User", "WARNING")
                return
            
            data = doc.to_dict()
            if data is None: 
                return
            
            # Define which lists contribute to profile (positive interactions only)
            profile_actions: List[tuple[str, str]] = [
                ('likedMovies', 'LIKED'),
                ('watchedMovies', 'WATCHED'),
                ('watchLaterMovies', 'WATCH_LATER'),
                # Note: notInterestedMovies excluded from profile to avoid negative drift
            ]
            
            profile_count = 0
            for list_name, action_type in profile_actions:
                movie_list = data.get(list_name, [])
                list_count = len(movie_list)
                if list_count > 0:
                    debug_print(f"  {list_name}: {list_count} movies (→ profile)", "DATA")
                
                for item in movie_list:
                    tmdb_id = None
                    if isinstance(item, dict): 
                        tmdb_id = int(item.get('id', 0))
                    elif isinstance(item, (str, int)): 
                        tmdb_id = int(item)

                    if tmdb_id and tmdb_id in self.tmdb_id_to_index:
                        idx = self.tmdb_id_to_index[tmdb_id]
                        self._update_profile_internal(user_id, idx, action_type)
                        profile_count += 1
            
            # Load disliked movies into seen set only (no profile impact)
            not_interested = data.get('notInterestedMovies', [])
            skipped_count = 0
            for item in not_interested:
                tmdb_id = None
                if isinstance(item, dict): 
                    tmdb_id = int(item.get('id', 0))
                elif isinstance(item, (str, int)): 
                    try:
                        tmdb_id = int(item)
                    except (ValueError, TypeError):
                        continue

                if tmdb_id and tmdb_id in self.tmdb_id_to_index:
                    idx = self.tmdb_id_to_index[tmdb_id]
                    self.user_seen_movies[user_id].add(idx)
                    skipped_count += 1
            
            if skipped_count > 0:
                debug_print(f"  notInterestedMovies: {len(not_interested)} movies (→ seen only, not profile)", "WARNING")
                        
            debug_print(f"✅ Profile: {profile_count} movies | Seen-only: {skipped_count} movies", "SUCCESS")
            
        except Exception as e:
            debug_print(f"Firebase Error: {e}", "ERROR")

    def get_user_vector(self, user_id: str) -> np.ndarray:
        """
        Get or initialize the user's preference vector.
        Loads from Firebase on first access for a session.
        """
        if user_id not in self.user_profiles:
            debug_print(f"🆕 New user session: {user_id[:8]}...", "INFO")
            self.user_profiles[user_id] = np.zeros(MAX_FEATURES)
            self.user_seen_movies[user_id] = set()
            self.user_liked_titles[user_id] = []
            self.load_user_from_firebase(user_id)
        return self.user_profiles[user_id]

    def _update_profile_internal(self, user_id: str, movie_index: int, action: str) -> None:
        """
        Internal method to update user profile vector based on movie interaction.
        Weights: LIKED=1.0, WATCH_LATER=0.5, WATCHED=0.2, DISLIKE=-0.5
        """
        user_vec = self.user_profiles[user_id]
        try:
            movie_vec = np.asarray(self.tfidf.transform([self.df.iloc[movie_index]['soup']]).toarray()).flatten()
            movie_title = str(self.df.iloc[movie_index]['title']).lower()
        except IndexError:
            return

        weights = {'LIKED': 1.0, 'WATCH_LATER': 0.5, 'WATCHED': 0.2, 'DISLIKE': -0.5}
        weight = weights.get(action, 0)
        
        self.user_profiles[user_id] = user_vec + (movie_vec * weight)
        self.user_seen_movies[user_id].add(movie_index)
        
        # Track liked titles for sequel detection
        if action in ['LIKED', 'WATCHED', 'WATCH_LATER']:
            if movie_title not in self.user_liked_titles[user_id]:
                self.user_liked_titles[user_id].append(movie_title)

    def update_profile(self, user_id: str, movie_index: int, action: str) -> None:
        """
        Public method to update user profile after a swipe action.
        Called from the /swipe endpoint.
        """
        self.get_user_vector(user_id)
        
        # Get movie info for debugging
        movie_title = str(self.df.iloc[movie_index]['title']) if movie_index < len(self.df) else "Unknown"
        movie_genres = str(self.df.iloc[movie_index].get('genres', '')) if movie_index < len(self.df) else ""
        
        debug_print(f"═══════════════════════════════════════════", "HEADER")
        debug_print(f" SWIPE RECEIVED", "HEADER")
        debug_print(f"═══════════════════════════════════════════", "HEADER")
        debug_print(f"  User: {user_id[:8]}...", "INFO")
        debug_print(f"  Movie: {movie_title}", "INFO")
        debug_print(f"  Genres: {movie_genres}", "DATA")
        debug_print(f"  Action: {action}", "INFO")
        debug_print(f"  Index: {movie_index}", "DATA")
        
        weights = {'LIKED': 1.0, 'WATCH_LATER': 0.5, 'WATCHED': 0.2, 'DISLIKE': -0.5}
        weight = weights.get(action, 0)
        debug_print(f"  Weight Applied: {weight:+.1f}", "DATA")
        
        self._update_profile_internal(user_id, movie_index, action)
        
        seen_count = len(self.user_seen_movies[user_id])
        debug_print(f"  Total Seen Movies: {seen_count}", "SUCCESS")

    def check_title_similarity(self, title1: str, title_list: List[str]) -> bool:
        """
        Check if a title is similar to any in the list (sequel detection).
        Uses prefix matching and SequenceMatcher for fuzzy comparison.
        """
        t1 = title1.lower()
        for t2 in title_list:
            # Check if titles share the same prefix (e.g., "Iron Man" and "Iron Man 2")
            if len(t1) > 5 and len(t2) > 5 and t1[:8] == t2[:8]: 
                return True
            # Fuzzy match for similar titles
            if SequenceMatcher(None, t1, t2).ratio() > 0.8: 
                return True
        return False

    def recommend(self, user_id: str, is_initial_fetch: bool, count: int = 5) -> List[Dict[str, Any]]:
        """
        Generate movie recommendations for a user.
        
        Uses two strategies:
        1. Cold Start (is_initial_fetch=True): Returns popular, high-rated movies
        2. Hybrid Ranking (is_initial_fetch=False): Uses KNN + popularity + rating scoring
        """
        debug_print(f"═══════════════════════════════════════════", "HEADER")
        debug_print(f" RECOMMENDATION REQUEST", "HEADER")
        debug_print(f"═══════════════════════════════════════════", "HEADER")
        debug_print(f"  User: {user_id[:8]}...", "INFO")
        debug_print(f"  Requested: {count} movies", "INFO")
        
        user_vec = self.get_user_vector(user_id)
        seen_movies = self.user_seen_movies[user_id]
        liked_titles = self.user_liked_titles.get(user_id, [])[-20:]  # Last 20 for sequel check
        
        debug_print(f"  Seen Movies: {len(seen_movies)}", "DATA")
        debug_print(f"  Liked Titles (last 20): {len(liked_titles)}", "DATA")
        
        recommendations = []
        
        # Strategy 1: Cold Start - Use for new users or initial fetch
        if is_initial_fetch:
            debug_print("   Using COLD START strategy", "WARNING")
            
            # Filter to high-quality movies only
            quality_movies = self.df[
                (self.df['vote_count'] >= 500) & 
                (self.df['vote_average'] >= 7.0)
            ].copy()
            
            debug_print(f"  Quality Pool: {len(quality_movies)} movies", "DATA")
            
            # Score by popularity and rating
            quality_movies['cold_score'] = (
                quality_movies['norm_popularity'] * 0.4 + 
                (quality_movies['vote_average'] / 10) * 0.6
            )
            top_movies = quality_movies.sort_values('cold_score', ascending=False)
            
            # Sample from top movies, avoiding duplicates
            safety = 0
            while len(recommendations) < count and safety < 100:
                safety += 1
                sample = top_movies.sample(1)
                idx = int(sample.index[0])
                if idx not in seen_movies and idx not in [r['index'] for r in recommendations]:
                    movie_data = sample.iloc[0]
                    recommendations.append({
                        "tmdb_id": int(movie_data['id']),
                        "title": str(movie_data['title']),
                        "index": idx
                    })
            
            debug_print(f"\n  📋 COLD START RESULTS:", "SUCCESS")
            for i, rec in enumerate(recommendations):
                movie = self.df.iloc[rec['index']]
                genres = movie.get('genres', 'N/A')
                rating = movie.get('vote_average', 0)
                votes = movie.get('vote_count', 0)
                debug_print(f"    {i+1}. {rec['title'][:35]}", "DATA")
                debug_print(f"       Genres: {genres}", "DATA")
                debug_print(f"       Rating: {rating} ({int(votes)} votes)", "DATA")
            
            return recommendations

        # Strategy 2: Hybrid Ranking - Use KNN similarity + popularity + rating
        debug_print("  Using HYBRID RANKING strategy", "SUCCESS")
        
        # Normalize user vector to prevent negative drift from dislikes
        user_vec_normalized = user_vec.copy()
        vec_mean = np.mean(user_vec_normalized)
        vec_magnitude = np.linalg.norm(user_vec_normalized)
        
        debug_print(f"  Vector magnitude: {vec_magnitude:.2f}, mean: {vec_mean:.4f}", "DATA")
        
        if vec_magnitude > 0:
            # L2 normalize for consistent similarity comparison
            user_vec_normalized = user_vec_normalized / vec_magnitude
            
            # If vector is negative-heavy, focus only on positive preferences
            if vec_mean < -0.01:
                debug_print("  ⚠️ User vector is negative-heavy, applying shift...", "WARNING")
                user_vec_normalized = np.maximum(user_vec_normalized, 0)
                new_mag = np.linalg.norm(user_vec_normalized)
                if new_mag > 0:
                    user_vec_normalized = user_vec_normalized / new_mag
        
        # Display top user interests for debugging
        feature_names = self.tfidf.get_feature_names_out()
        feature_scores = list(zip(feature_names, user_vec_normalized))
        top_features = sorted(feature_scores, key=lambda x: x[1], reverse=True)[:10]
        debug_print(f"\n   User Top Interests (normalized):", "INFO")
        for word, score in top_features:
            if score > 0:
                debug_print(f"    • {word}: {score:.4f}", "DATA")
        
        # Find nearest neighbors using KNN
        n_candidates = count * 20
        distances, indices = self.model.kneighbors([user_vec_normalized], n_neighbors=n_candidates)
        
        debug_print(f"\n   KNN returned {len(indices[0])} candidates", "INFO")
        
        # Score and filter candidates
        candidates = []
        for i, idx in enumerate(indices[0]):
            idx = int(idx)
            if idx in seen_movies: 
                continue
            
            movie = self.df.iloc[idx]
            candidate_title = str(movie['title'])
            genres = str(movie.get('genres', ''))
            
            # Skip pure documentaries in hybrid mode
            if 'Documentary' in genres and 'Documentary' not in genres.replace('Documentary', '').strip():
                continue
            
            # Calculate hybrid score
            similarity_score = 1 - distances[0][i]
            pop_score = movie['norm_popularity']
            rating_score = movie['norm_rating']
            vote_count_score = movie.get('norm_vote_count', 0)
            
            final_score = (
                (similarity_score * CONTENT_WEIGHT) + 
                (pop_score * POPULARITY_WEIGHT) +
                (rating_score * RATING_WEIGHT) +
                (vote_count_score * VOTE_COUNT_WEIGHT)
            )
            
            # Apply sequel penalty to avoid recommending too many similar titles
            is_sequel = self.check_title_similarity(candidate_title, liked_titles)
            if is_sequel:
                final_score *= SEQUEL_PENALTY
            
            candidates.append({
                "idx": idx, 
                "score": final_score, 
                "data": movie,
                "similarity": similarity_score,
                "popularity": pop_score,
                "rating": rating_score,
                "vote_count": vote_count_score,
                "is_sequel": is_sequel
            })
            
            if len(candidates) >= count * 3:
                break
        
        # Sort by score and take top N
        candidates = sorted(candidates, key=lambda x: x['score'], reverse=True)[:count]
        
        debug_print(f"\n   HYBRID RESULTS:", "SUCCESS")
        for i, c in enumerate(candidates):
            genres = c['data'].get('genres', 'N/A')
            debug_print(f"    {i+1}. {c['data']['title'][:35]}", "DATA")
            debug_print(f"       Genres: {genres}", "DATA")
            debug_print(f"       Scores: sim={c['similarity']:.2f} pop={c['popularity']:.2f} rat={c['rating']:.2f} → final={c['score']:.3f}", "DATA")
            if c['is_sequel']:
                debug_print(f"       ⚠️  SEQUEL PENALTY APPLIED", "WARNING")
            
            recommendations.append({
                "tmdb_id": int(c['data']['id']),
                "title": str(c['data']['title']),
                "index": int(c['idx'])
            })
            
        debug_print(f"═══════════════════════════════════════════\n", "HEADER")
        return recommendations

    def get_user_profile_analysis(self, user_id: str, top_n: int = 10) -> Dict[str, Any]:
        """
        Analyze and return the top interests in a user's profile.
        Useful for debugging and understanding user preferences.
        """
        user_vec = self.get_user_vector(user_id)
        if np.all(user_vec == 0): 
            return {"status": "New User", "top_keywords": []}
        feature_names = self.tfidf.get_feature_names_out()
        feature_scores = list(zip(feature_names, user_vec))
        sorted_features = sorted(feature_scores, key=lambda x: x[1], reverse=True)[:top_n]
        return {"user_id": user_id, "top_interests": {word: round(score, 3) for word, score in sorted_features}}


# --- GLOBAL INSTANCE ---
engine = RecommendationEngine(CSV_PATH, MODEL_PATH)


class SwipeRequest(BaseModel):
    """Request model for swipe endpoint."""
    user_id: str
    movie_index: int
    action: str  # LIKED, WATCHED, WATCH_LATER, DISLIKE


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
    engine.update_profile(req.user_id, req.movie_index, req.action)
    return {"status": "success", "message": "Profile updated"}


@app.get("/debug/user/{user_id}")
def debug_user(user_id: str):
    """Debug endpoint to view user's top interests."""
    return engine.get_user_profile_analysis(user_id)


@app.get("/debug/knn/{user_id}")
def debug_knn(user_id: str, top_words: int = 20, top_candidates: int = 10):
    """
    Debug endpoint to inspect KNN recommendations for a user.
    Returns user vector analysis and raw KNN candidates.
    """
    user_vec = engine.get_user_vector(user_id)
    seen_movies = engine.user_seen_movies.get(user_id, set())
    
    # Get top positive and negative features
    feature_names = engine.tfidf.get_feature_names_out()
    feature_scores = list(zip(feature_names, user_vec))
    
    sorted_features = sorted(feature_scores, key=lambda x: x[1], reverse=True)
    top_positive = [(word, round(score, 4)) for word, score in sorted_features[:top_words] if score > 0]
    
    sorted_negative = sorted(feature_scores, key=lambda x: x[1])
    top_negative = [(word, round(score, 4)) for word, score in sorted_negative[:top_words] if score < 0]
    
    # Get KNN candidates
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
    
    # Calculate genre distribution in results
    genre_counts = {}
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