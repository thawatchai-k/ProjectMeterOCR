from functools import wraps
from flask import jsonify
from flask_jwt_extended import verify_jwt_in_request, get_jwt_identity

def require_role(roles):
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            verify_jwt_in_request()
            user = get_jwt_identity()

            if user["role"] not in roles:
                return jsonify({"error": "forbidden"}), 403

            return fn(*args, **kwargs)
        return wrapper
    return decorator
