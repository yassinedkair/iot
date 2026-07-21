from flask import Flask, request, jsonify, g
import numpy as np
import cv2
import requests
import json
import os
import jwt
from datetime import datetime, timedelta, timezone
from functools import wraps
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)

# --------------------------------------------------
# ⚠️ CONFIGURATION
# --------------------------------------------------
ESP32_IP = "192.168.11.107"  # ⚠️ Remplace par l'IP réelle affichée dans le moniteur série de l'ESP32

# ⚠️ Change cette clé secrète en production (utilise une variable d'environnement !)
SECRET_KEY = os.environ.get("APP_SECRET_KEY", "change-moi-en-production-cle-secrete-longue")
TOKEN_EXPIRATION_HOURS = 24 * 7  # le token reste valide 7 jours

USERS_FILE = "users.json"
# --------------------------------------------------

# Chargement du modèle .tflite
try:
    import tensorflow as tf
    interpreter = tf.lite.Interpreter(model_path="plant_model.tflite")
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    print("✅ Le modèle TFLite a été chargé avec succès dans le PC !")
except Exception as e:
    print(f"❌ Erreur lors du chargement du modèle : {e}")

# Liste des classes
classes = ["HIBISCUS_DISEASED", "HIBISCUS_HEALTHY", "Potato___Late_blight", "Potato___healthy", "Tomato_Late_blight", "Tomato_healthy"]

# 📚 BASE DE DONNÉES DES TRAITEMENTS ET CONSEILS (En Français)
TREATMENT_ADVISOR = {
    "hibiscus_healthy": {
        "title": "🎉 Hibiscus en parfaite santé !",
        "steps": [
            "☀️ **Lumière :** Placez-le dans un endroit très lumineux, avec au moins 6 heures de soleil direct par jour.",
            "💧 **Arrosage :** Arrosez régulièrement durant l'été, en laissant le sol sécher légèrement en surface entre deux arrosages.",
            "🌱 **Engrais :** Appliquez un engrais riche en potassium une fois par mois pour stimuler une belle floraison."
        ]
    },
    "hibiscus_diseased": {
        "title": "🚨 Hibiscus Malade (Infection ou Ravageurs) !",
        "steps": [
            "🔍 **Symptômes :** Présence de taches noires, feuilles jaunies ou petits insectes (pucerons) sous les feuilles.",
            "✂️ **Taille :** Coupez immédiatement les branches et feuilles gravement touchées avec un sécateur désinfecté.",
            "🧴 **Remède :** Vaporisez une solution de savon noir diluée dans de l'eau tiède ou un fongicide naturel pour soigner la plante."
        ]
    },
    "potato___healthy": {
        "title": "🎉 Plant de Pomme de Terre Vigoureux et Sain !",
        "steps": [
            "💧 **Arrosage :** Arrosez toujours au pied sans mouiller les feuilles pour éviter l'apparition de champignons.",
            "🥔 **Buttage :** Ramenez de la terre autour de la tige (butter) pour protéger les tubercules de la lumière du soleil.",
            "🌬️ **Espace :** Assurez-vous qu'il y a assez d'espace entre les plants pour une bonne circulation de l'air."
        ]
    },
    "potato___late_blight": {
        "title": "🚨 Mildiou de la Pomme de Terre détecté (Late Blight) !",
        "steps": [
            "🔍 **Symptômes :** Taches brun-noirâtres sur les feuilles qui se propagent vite, avec un duvet blanc humide dessous.",
            "✂️ **Action Vitale :** Coupez et brûlez/jetez immédiatement les feuilles infectées (ne jamais les mettre au compost).",
            "🧴 **Traitement :** Pulvérisez de la **Bouillie Bordelaise** (traitement à base de cuivre) pour stopper la propagation."
        ]
    },
    "tomato_healthy": {
        "title": "🎉 Plant de Tomate vigoureux et en pleine forme !",
        "steps": [
            "☀️ **Exposition :** Un maximum de soleil (6 à 8 heures par jour) pour aider les tomates à mûrir.",
            "✂️ **Taille :** Retirez régulièrement les 'gourmands' (jeunes pousses inutiles) pour concentrer l'énergie sur les fruits.",
            "💧 **Régularité :** Arrosez de manière constante sans excès pour éviter le fendillement des fruits."
        ]
    },
    "tomato_late_blight": {
        "title": "🚨 Mildiou de la Tomate détecté (Late Blight) !",
        "steps": [
            "🔍 **Symptômes :** Taches brunes d'aspect huileux sur les feuilles, tiges brunies et fruits se couvrant de taches dures.",
            "✂️ **Aération :** Enlevez les feuilles du bas pour qu'elles ne touchent pas le sol humide.",
            "🧴 **Traitement :** Appliquez immédiatement un fongicide biologique à base de cuivre et protégez la plante de la pluie si possible."
        ]
    }
}


# ==================================================
# 🔐 GESTION DES UTILISATEURS (users.json)
# ==================================================

def load_users():
    if os.path.exists(USERS_FILE):
        with open(USERS_FILE, 'r') as f:
            try:
                return json.load(f)
            except:
                return {}
    return {}


def save_users(users):
    with open(USERS_FILE, 'w') as f:
        json.dump(users, f, indent=2)


def get_history_file(username):
    """Chaque utilisateur a son propre fichier d'historique."""
    safe_name = "".join(c for c in username if c.isalnum() or c in ("_", "-")).lower()
    return f"history_{safe_name}.json"


# ==================================================
# 🔐 JWT : génération et vérification des tokens
# ==================================================

def generate_token(username):
    payload = {
        "username": username,
        "exp": datetime.now(timezone.utc) + timedelta(hours=TOKEN_EXPIRATION_HOURS),
        "iat": datetime.now(timezone.utc)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


def token_required(f):
    """Décorateur qui protège une route : exige un header
    'Authorization: Bearer <token>' valide. L'utilisateur courant
    est ensuite disponible dans g.current_user."""
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return jsonify({"error": "Token manquant. Veuillez vous connecter."}), 401

        token = auth_header.split(' ', 1)[1]
        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
            g.current_user = payload["username"]
        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Session expirée, veuillez vous reconnecter."}), 401
        except jwt.InvalidTokenError:
            return jsonify({"error": "Token invalide."}), 401

        return f(*args, **kwargs)
    return decorated


# ==================================================
# 🔐 ROUTES D'AUTHENTIFICATION
# ==================================================

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json(silent=True) or {}
    username = (data.get('username') or '').strip()
    password = data.get('password') or ''
    email = (data.get('email') or '').strip()

    if not username or not password:
        return jsonify({"error": "Nom d'utilisateur et mot de passe requis."}), 400
    if len(password) < 6:
        return jsonify({"error": "Le mot de passe doit contenir au moins 6 caractères."}), 400

    users = load_users()
    username_key = username.lower()

    if username_key in users:
        return jsonify({"error": "Ce nom d'utilisateur existe déjà."}), 409

    users[username_key] = {
        "username": username,
        "email": email,
        "password_hash": generate_password_hash(password),
        "created_at": datetime.now().strftime("%d-%m-%Y %H:%M:%S")
    }
    save_users(users)

    token = generate_token(username_key)
    return jsonify({
        "message": "Compte créé avec succès !",
        "token": token,
        "username": username
    }), 201


@app.route('/login', methods=['POST'])
def login():
    data = request.get_json(silent=True) or {}
    username = (data.get('username') or '').strip()
    password = data.get('password') or ''

    if not username or not password:
        return jsonify({"error": "Nom d'utilisateur et mot de passe requis."}), 400

    users = load_users()
    username_key = username.lower()
    user = users.get(username_key)

    if not user or not check_password_hash(user["password_hash"], password):
        return jsonify({"error": "Nom d'utilisateur ou mot de passe incorrect."}), 401

    token = generate_token(username_key)
    return jsonify({
        "message": "Connexion réussie !",
        "token": token,
        "username": user["username"]
    }), 200


# ==================================================
# 📜 HISTORIQUE (par utilisateur)
# ==================================================

def add_to_history(username, status, class_name, treatment_info, confidence, severity):
    history_file = get_history_file(username)
    history = []
    if os.path.exists(history_file):
        with open(history_file, 'r') as f:
            try:
                history = json.load(f)
            except:
                pass

    new_entry = {
        "time": datetime.now().strftime("%d-%m-%Y %H:%M:%S"),
        "status": status,
        "class": class_name,
        "confidence": confidence,
        "severity": severity,
        "treatment": treatment_info
    }
    history.insert(0, new_entry)
    history = history[:10]
    with open(history_file, 'w') as f:
        json.dump(history, f)


def get_plant_and_disease(class_name):
    lower = class_name.lower()

    if "hibiscus" in lower:
        plant, icon = "Hibiscus", "🌺"
    elif "potato" in lower:
        plant, icon = "Pomme de terre", "🥔"
    elif "tomato" in lower:
        plant, icon = "Tomate", "🍅"
    else:
        plant, icon = "Plante", "🌿"

    if "healthy" in lower:
        disease_label = "Aucune maladie détectée"
    elif "late_blight" in lower:
        disease_label = "Mildiou (Late Blight)"
    elif "diseased" in lower:
        disease_label = "Infection / Ravageurs"
    else:
        disease_label = class_name

    return plant, icon, disease_label


def get_severity(confidence, status):
    if status == "Sain":
        return "Aucune", "#2e7d32"
    if confidence >= 85:
        return "Élevée", "#c62828"
    elif confidence >= 60:
        return "Modérée", "#ef6c00"
    else:
        return "Faible", "#f9a825"


def run_inference_and_respond(img, username):
    img_resized = cv2.resize(img, (128, 128))
    img_resized = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)

    input_scale, input_zero_point = input_details[0]['quantization']
    img_quantized = (img_resized.astype(np.float32) / input_scale) + input_zero_point
    img_quantized = np.clip(img_quantized, -128, 127)
    img_input = np.expand_dims(img_quantized, axis=0).astype(np.int8)

    interpreter.set_tensor(input_details[0]['index'], img_input)
    interpreter.invoke()

    output_data = interpreter.get_tensor(output_details[0]['index'])
    if output_details[0]['dtype'] == np.int8:
        output_scale, output_zero_point = output_details[0]['quantization']
        output_data = (output_data.astype(np.float32) - output_zero_point) * output_scale

    probabilities = output_data[0]
    predicted_class_idx = int(np.argmax(probabilities))
    class_name = classes[predicted_class_idx]
    class_key = class_name.lower()

    confidence = float(np.max(probabilities)) * 100
    confidence = round(min(max(confidence, 0), 100), 1)

    plant, icon, disease_label = get_plant_and_disease(class_name)

    if "healthy" in class_key:
        status = "Sain"
        treatment_info = TREATMENT_ADVISOR.get(class_key, TREATMENT_ADVISOR["hibiscus_healthy"])
        try:
            requests.get(f"http://{ESP32_IP}/alert?status=healthy", timeout=3)
        except Exception as e:
            print(f"⚠️ ESP32 injoignable : {e}")
    else:
        status = "Malade"
        treatment_info = TREATMENT_ADVISOR.get(class_key, TREATMENT_ADVISOR["hibiscus_diseased"])
        try:
            requests.get(f"http://{ESP32_IP}/alert?status=unhealthy", timeout=3)
        except Exception as e:
            print(f"⚠️ ESP32 injoignable : {e}")

    severity, severity_color = get_severity(confidence, status)
    add_to_history(username, status, class_name, treatment_info, confidence, severity)

    return {
        "status": status,
        "class": class_name,
        "plant": plant,
        "plant_icon": icon,
        "disease_label": disease_label,
        "confidence": confidence,
        "severity": severity,
        "severity_color": severity_color,
        "timestamp": datetime.now().strftime("%d-%m-%Y %H:%M:%S"),
        "treatment_info": treatment_info
    }


# ==================================================
# 🌐 ROUTES PROTÉGÉES (nécessitent d'être connecté)
# ==================================================

@app.route('/get_history')
@token_required
def get_history():
    history_file = get_history_file(g.current_user)
    if os.path.exists(history_file):
        with open(history_file, 'r') as f:
            return jsonify(json.load(f))
    return jsonify([])


@app.route('/predict_upload', methods=['POST'])
@token_required
def predict_upload():
    try:
        if 'image' not in request.files:
            return jsonify({"status": "Erreur", "class": "Aucune image reçue (champ 'image' manquant)"}), 400

        file = request.files['image']
        img_bytes = file.read()

        npimg = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

        if img is None:
            return jsonify({"status": "Erreur", "class": "Image invalide ou illisible"}), 400

        result = run_inference_and_respond(img, g.current_user)
        return jsonify(result)

    except Exception as e:
        return jsonify({"status": "Erreur", "class": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)