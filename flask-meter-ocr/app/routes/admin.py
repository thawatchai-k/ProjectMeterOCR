from flask import Blueprint, request, jsonify
from app.models import db
from app.models.user import User
from app.utils.auth import require_role

admin_bp = Blueprint("admin", __name__)

@admin_bp.route("/api/admin/create-user", methods=["POST"])
@require_role(["admin"])
def create_user():
    data = request.json
    username = data.get("username")
    password = data.get("password")
    role = data.get("role")

    if not username or not password or not role:
        return jsonify({"error": "Missing required fields"}), 400

    existing = User.query.filter_by(username=username).first()
    if existing:
        return jsonify({"error": "Username already exists"}), 400

    user = User(
        username=username,
        role=role
    )
    user.set_password(password)

    db.session.add(user)
    db.session.commit()

    return jsonify({"message": f"User {username} created successfully as {role}"}), 201

@admin_bp.route("/api/admin/users", methods=["GET"])
@require_role(["admin"])
def list_users():
    users = User.query.all()
    user_list = [{"id": u.id, "username": u.username, "role": u.role} for u in users]
    return jsonify(user_list), 200

@admin_bp.route("/api/admin/users/<int:user_id>", methods=["DELETE"])
@require_role(["admin"])
def delete_user(user_id):
    user = User.query.get(user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404
    
    if user.role == "admin":
        return jsonify({"error": "Cannot delete admin user"}), 403

    db.session.delete(user)
    db.session.commit()
    return jsonify({"message": "User deleted successfully"}), 200
