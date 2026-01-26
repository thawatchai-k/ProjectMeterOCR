from flask import Blueprint, request, jsonify
from app.models.user import User
from flask_jwt_extended import create_access_token

auth_bp = Blueprint("auth", __name__)

@auth_bp.route("/login", methods=["POST"])
def login():
    data = request.json
    user = User.query.filter_by(username=data.get("username")).first()

    if not user or not user.check_password(data.get("password")):
        return jsonify({"error": "invalid credentials"}), 401

    # สร้าง JWT token
    token = create_access_token(
    identity=str(user.id),
    additional_claims={
        "role": user.role
    }
)


    return jsonify({
        "access_token": token,
        "user": {
            "id": user.id,
            "username": user.username,
            "role": user.role
        }
    })
