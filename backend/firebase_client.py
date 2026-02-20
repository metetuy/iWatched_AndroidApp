import firebase_admin
from firebase_admin import credentials, firestore
from config import FIREBASE_CRED_DICT

cred = credentials.Certificate(FIREBASE_CRED_DICT)
firebase_admin.initialize_app(cred)

db = firestore.client()