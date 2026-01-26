from flask import Blueprint, request, jsonify
from app.models import db
from app.models.user import User
from app.utils.auth import require_role

admin_bp = Blueprint("admin", __name__)

@admin_bp.route("/api/admin/create-user", methods=["POST"])
@require_role(["admin"])
def create_user():
    data = request.json

    user = User(
        username=data["username"],
        role=data["role"]
    )
    user.set_password(data["password"])

    db.session.add(user)
    db.session.commit()

    return jsonify({"message": "user created successfully"})
