from flask import Flask
from app.models import db
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager
from flask_cors import CORS
from datetime import timedelta

migrate = Migrate()
jwt = JWTManager()

def create_app():
    app = Flask(__name__)

    # Enable CORS for all routes with full configuration
    CORS(app, resources={r"/*": {"origins": "*"}}, supports_credentials=True)

    # Load config from config.py
    app.config.from_object('config.Config')

    # 🔧 DEV (Override for testing token expiration flow)
    # app.config["JWT_ACCESS_TOKEN_EXPIRES"] = False # Commented out to test expiration
    app.config["JWT_ACCESS_TOKEN_EXPIRES"] = timedelta(hours=8) # Set to 8 hours for testing

    # init extensions (ต้องมาก่อน register blueprint)
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)

    # import models
    from app.models import user, ocr_result

    # import routes
    from app.routes.auth_routes import auth_bp
    from app.routes.ocr import ocr_bp
    from app.routes.meter_routes import meter_bp
    from app.routes.admin import admin_bp

    # register blueprints
    app.register_blueprint(auth_bp, url_prefix='/api')
    app.register_blueprint(ocr_bp, url_prefix='/api')
    app.register_blueprint(meter_bp, url_prefix='/api')
    app.register_blueprint(admin_bp) # admin_bp already has /api prefix in the file
    
    # Auto-create tables (Dev mode convenience)
    with app.app_context():
        db.create_all()

    return app

