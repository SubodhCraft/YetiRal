import json
import os
import hashlib
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

DB_PATH = 'database.json'
STATS_PATH = 'stats.json'

def load_json(path):
    if not os.path.exists(path): return {}
    with open(path, 'r') as f:
        return json.load(f)

def save_json(path, data):
    with open(path, 'w') as f:
        json.dump(data, f, indent=4)

def hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()

def get_uid(username):
    return hashlib.sha256((username + "UID_SALT").encode()).hexdigest()[:8].upper()

@app.route('/register', methods=['POST'])
def register():
    data = request.json
    username = data.get('username', '').strip()
    password = data.get('password', '')
    
    if len(username) < 4: return jsonify({"success": False, "message": "Username too short."}), 400
    if len(password) < 6: return jsonify({"success": False, "message": "Password too short."}), 400
    
    db = load_json(DB_PATH)
    lower_key = username.lower()
    
    if lower_key in db:
        return jsonify({"success": False, "message": "Username already exists!"})
        
    db[lower_key] = {
        "hash": hash_password(password),
        "uid": get_uid(lower_key),
        "friends": [],
        "requests": [],
        "equipped_hat": "none",
        "equipped_color": "#FFFFFF",
        "owned_hats": [],
        "profile_pic_path": ""
    }
    save_json(DB_PATH, db)
    return jsonify({"success": True, "message": "Account created!"})

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username', '').strip().lower()
    password = data.get('password', '')
    
    db = load_json(DB_PATH)
    if username not in db:
        return jsonify({"success": False, "message": "User not found."})
        
    user_data = db[username]
    if user_data['hash'] != hash_password(password):
        return jsonify({"success": False, "message": "Incorrect password."})
        
    return jsonify({"success": True, "message": "Login successful!", "uid": user_data['uid'], "username": username})

@app.route('/stats/<username>', methods=['GET'])
def get_stats(username):
    stats = load_json(STATS_PATH)
    lower = username.lower()
    if lower not in stats:
        stats[lower] = {
            "matches_played": 0, "wins": 0, "momos": 0, "xp": 0, "level": 1,
            "last_login_time": 0.0, "active_days_streak": 0, "badges": [], "match_history": []
        }
        save_json(STATS_PATH, stats)
    return jsonify(stats[lower])

@app.route('/stats/update', methods=['POST'])
def update_stats():
    data = request.json
    username = data.get('username', '').lower()
    stats = load_json(STATS_PATH)
    if username not in stats:
        stats[username] = {
            "matches_played": 0, "wins": 0, "momos": 0, "xp": 0, "level": 1,
            "last_login_time": 0.0, "active_days_streak": 0, "badges": [], "match_history": []
        }
    if 'xp' in data: stats[username]['xp'] += data['xp']
    if 'momos_delta' in data: stats[username]['momos'] += data['momos_delta']
    if 'level' in data: stats[username]['level'] = data['level']
    if 'matches_played_delta' in data: stats[username]['matches_played'] += data['matches_played_delta']
    if 'wins_delta' in data: stats[username]['wins'] += data['wins_delta']
    if 'last_login_time' in data: stats[username]['last_login_time'] = data['last_login_time']
    if 'active_days_streak' in data: stats[username]['active_days_streak'] = data['active_days_streak']
    if 'badges' in data: stats[username]['badges'] = data['badges']
    if 'match_history_entry' in data:
        history = stats[username].get('match_history', [])
        history.append(data['match_history_entry'])
        while len(history) > 20:
            history.pop(0)
        stats[username]['match_history'] = history
    save_json(STATS_PATH, stats)
    return jsonify({"success": True, "stats": stats[username]})

@app.route('/stats/sync', methods=['POST'])
def sync_stats():
    """Full stats write — overwrites the record with client-provided values."""
    data = request.json
    username = data.get('username', '').lower()
    stats = load_json(STATS_PATH)
    if username not in stats:
        stats[username] = {}
    for key in ['momos', 'xp', 'level', 'matches_played', 'wins',
                 'last_login_time', 'active_days_streak', 'badges', 'match_history']:
        if key in data:
            stats[username][key] = data[key]
    save_json(STATS_PATH, stats)
    return jsonify({"success": True, "stats": stats[username]})

@app.route('/user/equip_hat', methods=['POST'])
def equip_hat():
    data = request.json
    username = data.get('username', '').lower()
    hat_id = data.get('hat_id', 'none')
    db = load_json(DB_PATH)
    if username not in db:
        return jsonify({"success": False, "message": "User not found."})
    owned = db[username].get('owned_hats', [])
    if hat_id != 'none' and hat_id not in owned:
        return jsonify({"success": False, "message": "Hat not owned."})
    db[username]['equipped_hat'] = hat_id
    save_json(DB_PATH, db)
    return jsonify({"success": True})

@app.route('/user/unlock_hat', methods=['POST'])
def unlock_hat():
    data = request.json
    username = data.get('username', '').lower()
    hat_id = data.get('hat_id', '')
    db = load_json(DB_PATH)
    if username not in db:
        return jsonify({"success": False, "message": "User not found."})
    owned = db[username].setdefault('owned_hats', [])
    if hat_id not in owned:
        owned.append(hat_id)
    save_json(DB_PATH, db)
    return jsonify({"success": True, "owned_hats": owned})

@app.route('/user/update_color', methods=['POST'])
def update_color():
    data = request.json
    username = data.get('username', '').lower()
    color = data.get('color', '#FFFFFF')
    db = load_json(DB_PATH)
    if username not in db:
        return jsonify({"success": False, "message": "User not found."})
    db[username]['equipped_color'] = color
    save_json(DB_PATH, db)
    return jsonify({"success": True})

@app.route('/user/get_by_uid/<uid>', methods=['GET'])
def get_user_by_uid(uid):
    db = load_json(DB_PATH)
    for k, v in db.items():
        if v.get('uid') == uid.upper():
            return jsonify({"success": True, "username": k})
    return jsonify({"success": False, "username": "Unknown"})

@app.route('/user/profile/<username>', methods=['GET'])
def get_user_profile(username):
    db = load_json(DB_PATH)
    lower = username.lower()
    if lower not in db:
        return jsonify({"success": False, "message": "User not found."})
    user = db[lower]
    return jsonify({
        "success": True,
        "profile_pic_path": user.get("profile_pic_path", ""),
        "equipped_hat": user.get("equipped_hat", "none"),
        "equipped_color": user.get("equipped_color", "#FFFFFF"),
        "owned_hats": user.get("owned_hats", [])
    })

@app.route('/user/set_profile_pic', methods=['POST'])
def set_profile_pic():
    data = request.json
    username = data.get('username', '').lower()
    path = data.get('profile_pic_path', '')
    db = load_json(DB_PATH)
    if username not in db:
        return jsonify({"success": False, "message": "User not found."})
    db[username]['profile_pic_path'] = path
    save_json(DB_PATH, db)
    return jsonify({"success": True})
    
@app.route('/friends/send_request', methods=['POST'])
def send_request():
    data = request.json
    sender_username = data.get('sender').lower()
    target_uid = data.get('target_uid').upper()
    
    db = load_json(DB_PATH)
    sender_uid = db[sender_username]['uid']
    
    target_user = None
    for k, v in db.items():
        if v.get('uid') == target_uid:
            target_user = k
            break
            
    if not target_user:
        return jsonify({"success": False, "message": "Player UID not found."})
        
    if target_user == sender_username:
        return jsonify({"success": False, "message": "Cannot add yourself."})
        
    target_data = db[target_user]
    if sender_uid in target_data.get('friends', []):
        return jsonify({"success": False, "message": "Already friends."})
    if sender_uid in target_data.get('requests', []):
        return jsonify({"success": False, "message": "Request already sent."})
        
    target_data.setdefault('requests', []).append(sender_uid)
    save_json(DB_PATH, db)
    return jsonify({"success": True, "message": "Request sent!"})

@app.route('/friends/accept_request', methods=['POST'])
def accept_request():
    data = request.json
    username = data.get('username').lower()
    requester_uid = data.get('requester_uid').upper()
    
    db = load_json(DB_PATH)
    my_data = db[username]
    my_uid = my_data['uid']
    
    if requester_uid not in my_data.get('requests', []):
        return jsonify({"success": False, "message": "Request not found."})
        
    requester_user = None
    for k, v in db.items():
        if v.get('uid') == requester_uid:
            requester_user = k
            break
            
    if requester_user:
        if requester_uid not in my_data.setdefault('friends', []):
            my_data['friends'].append(requester_uid)
        if my_uid not in db[requester_user].setdefault('friends', []):
            db[requester_user]['friends'].append(my_uid)
            
    my_data['requests'].remove(requester_uid)
    save_json(DB_PATH, db)
    return jsonify({"success": True, "message": "Request accepted!"})

@app.route('/friends/reject_request', methods=['POST'])
def reject_request():
    data = request.json
    username = data.get('username').lower()
    requester_uid = data.get('requester_uid').upper()
    
    db = load_json(DB_PATH)
    my_data = db[username]
    if requester_uid in my_data.get('requests', []):
        my_data['requests'].remove(requester_uid)
        save_json(DB_PATH, db)
        return jsonify({"success": True, "message": "Request rejected."})
    return jsonify({"success": False, "message": "Request not found."})

@app.route('/friends/list/<username>', methods=['GET'])
def get_friends(username):
    db = load_json(DB_PATH)
    lower = username.lower()
    if lower in db:
        friends_uids = db[lower].get("friends", [])
        requests_uids = db[lower].get("requests", [])
        
        friends_list = []
        for uid in friends_uids:
            for k, v in db.items():
                if v.get('uid') == uid:
                    friends_list.append({"uid": uid, "username": k})
                    break
                    
        requests_list = []
        for uid in requests_uids:
            for k, v in db.items():
                if v.get('uid') == uid:
                    requests_list.append({"uid": uid, "username": k})
                    break
                    
        return jsonify({
            "friends": friends_list,
            "requests": requests_list
        })
    return jsonify({"friends": [], "requests": []})

@app.route('/change_password', methods=['POST'])
def change_password():
    data = request.json
    username = data.get('username', '').lower()
    old_password = data.get('old_password', '')
    new_password = data.get('new_password', '')
    
    if len(new_password) < 6:
        return jsonify({"success": False, "message": "New password must be at least 6 characters."})
    
    db = load_json(DB_PATH)
    if username not in db:
        return jsonify({"success": False, "message": "User not found."})
    
    user_data = db[username]
    if user_data.get('hash', '') != hash_password(old_password):
        return jsonify({"success": False, "message": "Current password is incorrect."})
    
    user_data['hash'] = hash_password(new_password)
    db[username] = user_data
    save_json(DB_PATH, db)
    return jsonify({"success": True, "message": "Password changed successfully!"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
