import os
from dotenv import load_dotenv

load_dotenv()

# --- DEBUG SETTINGS ---
DEBUG_MODE = True

# --- CONFIGURATION ---
CSV_PATH = 'movies_dataset_final.csv'
MODEL_PATH = 'model_data.pkl'
MAX_FEATURES = 5000
MIN_VOTE_COUNT = 100
MIN_VOTE_AVERAGE = 5.5

# --- SCORING WEIGHTS ---
POPULARITY_WEIGHT = 0.25
CONTENT_WEIGHT = 0.50
RATING_WEIGHT = 0.25
VOTE_COUNT_WEIGHT = 0.10

SEQUEL_PENALTY = 0.25

# --- FIREBASE CREDENTIALS ---
FIREBASE_CRED_DICT = {
    "type": "service_account",
    "project_id": os.getenv("FIREBASE_PROJECT_ID"),
    "private_key_id": os.getenv("FIREBASE_PRIVATE_KEY_ID"),
    "private_key": os.getenv("FIREBASE_PRIVATE_KEY", "").replace("\\n", "\n"),
    "client_email": os.getenv("FIREBASE_CLIENT_EMAIL"),
    "client_id": os.getenv("FIREBASE_CLIENT_ID"),
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": f"https://www.googleapis.com/robot/v1/metadata/x509/{(os.getenv('FIREBASE_CLIENT_EMAIL') or '').replace('@', '%40')}",
    "universe_domain": "googleapis.com"
}