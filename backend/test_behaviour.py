import requests
import json
import time
from tabulate import tabulate
from termcolor import colored

# --- AYARLAR ---
BASE_URL = "http://127.0.0.1:8000"

# BURAYA DİKKAT:
# Eğer uygulamanı daha önce kullandıysan, Firebase'deki GERÇEK bir User UID'sini buraya yapıştır.
# Eğer yoksa rastgele bir şey bırak, "Yeni Kullanıcı" olarak test ederiz.
TEST_USER_ID = "MVJHZvSXGGeBYKMRB66YlgWEdG33" 

def print_header(text, color='blue'):
    print("\n" + "="*60)
    print(colored(f" {text} ", 'white', f'on_{color}', attrs=['bold']))
    print("="*60)

def get_model_brain():
    """Modelin o anki ilgi alanlarını (Keyword Ağırlıkları) çeker"""
    try:
        resp = requests.get(f"{BASE_URL}/debug/user/{TEST_USER_ID}")
        if resp.status_code == 200:
            return resp.json()
        return {}
    except:
        return {}

def run_test():
    print_header(f"FIREBASE & BACKEND TESTİ: {TEST_USER_ID}", 'magenta')
    
    print(colored("\nℹ️  BİLGİ: Bu testi çalıştırırken diğer terminaldeki SERVER LOGLARINI izle.", 'yellow'))
    print(colored("    Orada '📥 Firebase'den kullanıcı verisi çekiliyor' yazısını görmelisin.\n", 'yellow'))

    # --- ADIM 1: FIREBASE HAFIZA KONTROLÜ ---
    print(colored("1. Kullanıcı Profili Sorgulanıyor...", 'cyan'))
    
    start_time = time.time()
    brain_data = get_model_brain()
    duration = time.time() - start_time
    
    print(f"   ⏱️  Yanıt Süresi: {duration:.2f} saniye")

    if 'status' in brain_data and brain_data['status'] == 'New User':
        print(colored("   -> SONUÇ: Yeni Kullanıcı (veya Firebase'de veri yok). Cold Start çalışacak.", 'white', attrs=['bold']))
    else:
        print(colored("   -> SONUÇ: Eski Kullanıcı! Model seni hatırladı.", 'green', attrs=['bold']))
        if 'top_interests' in brain_data:
            print("\n   🧠 Modelin Hatırladıkları (En yüksek puanlı ilgiler):")
            items = list(brain_data['top_interests'].items())[:5]
            print(tabulate(items, headers=["Keyword", "Puan"], tablefmt="simple"))

    # --- ADIM 2: ÖNERİ İSTEME ---
    print(colored("\n2. Film Önerileri İsteniyor...", 'cyan'))
    try:
        resp = requests.get(f"{BASE_URL}/recommendations/{TEST_USER_ID}?count=5")
        movies = resp.json()['results']
        
        table_data = []
        for m in movies:
            table_data.append([m['tmdb_id'], m.get('title', '-')[:30], m['index']])
            
        print(tabulate(table_data, headers=["TMDB ID", "Film Adı", "CSV Index"], tablefmt="grid"))
        
    except Exception as e:
        print(colored(f"❌ Öneri Hatası: {e}", 'red'))
        return

    # --- ADIM 3: SWIPE SİMÜLASYONU ---
    if movies:
        target = movies[0]
        print(colored(f"\n3. Swipe Gönderiliyor: {target.get('title', 'Film')} -> LIKE", 'cyan'))
        
        payload = {
            "user_id": TEST_USER_ID,
            "movie_index": target['index'],
            "action": "LIKE"
        }
        
        resp_swipe = requests.post(f"{BASE_URL}/swipe", json=payload)
        
        if resp_swipe.status_code == 200:
            print(colored("   ✅ Swipe Başarılı! RAM güncellendi.", 'green'))
        else:
            print(colored(f"   ❌ Swipe Hatası: {resp_swipe.text}", 'red'))

    # --- ADIM 4: DEĞİŞİM KONTROLÜ ---
    print(colored("\n4. Model Güncellemesi Kontrol Ediliyor...", 'cyan'))
    new_brain_data = get_model_brain()
    
    # Basit bir karşılaştırma
    if new_brain_data != brain_data:
        print(colored("   ✅ BAŞARILI: Profil vektörü değişti!", 'green', attrs=['bold']))
    else:
        print(colored("   ⚠️ UYARI: Profil değişmedi (Belki puan etkisi düşüktü).", 'yellow'))

    print_header("TEST TAMAMLANDI", 'magenta')

if __name__ == "__main__":
    run_test()