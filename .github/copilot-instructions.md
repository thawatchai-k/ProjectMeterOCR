# Meter OCR Application - AI Agent Instructions

## Project Overview

**meter-ocr** is a full-stack application for optical character recognition (OCR) of meter readings. It consists of two main components:
- **Backend**: Flask REST API with MySQL database and JWT authentication
- **Frontend**: Flutter mobile app for image capture and submission

The system captures meter images on mobile, sends them to the Flask backend, processes them via Tesseract OCR, and returns extracted text.

## Architecture & Key Components

### Backend (Flask) - `flask-meter-ocr/`

#### Core Structure
- **Entry Point**: `run.py` - Starts Flask dev server with debug mode enabled
- **App Factory**: `app/__init__.py` - Initializes Flask app, database, JWT, and migration tools
- **Database**: MySQL at `localhost:3306/meter_ocr_db` (configured in `config.py`)

#### Data Models (`app/models/`)
- **User** (`user.py`): Username, password_hash, role-based access. Methods: `set_password()`, `check_password()`
- **OCRResult** (`ocr_result.py`): Stores image_path, extracted text, and created_at timestamp

#### Routes (`app/routes/`)
- **Auth Routes** (`auth_routes.py`):
  - `POST /api/login` - Returns JWT token with role claims
  - Uses `flask_jwt_extended` for token generation
  - Additional claims: role embedded in token for authorization
  
- **OCR Routes** (`ocr.py`):
  - `POST /api/ocr` - Requires JWT, accepts multipart form with "image" field
  - Validates: `.png`, `.jpg`, `.jpeg` files only
  - Flow: File upload → Tesseract OCR processing → DB storage → Returns {id, text}
  - Saves to `app/static/uploads/` with `secure_filename()`

#### Services (`app/services/`)
- **OCR Service** (`ocr_service.py`): `read_text(image_path)` wrapper around Tesseract via PIL

#### Auth Utilities (`app/utils/auth.py`)
- `require_role(roles)`: Decorator for role-based endpoint protection

#### Database Migrations (`migrations/`)
- Uses Alembic (Flask-Migrate)
- Key migrations: User table creation, OCRResult table, password_hash rename
- To run: `flask db upgrade`

### Frontend (Flutter) - `meter_ocr_app/`

#### Core Structure
- **Entry Point**: `lib/main.dart` - Initializes MaterialApp with LoginScreen
- **Screens** (`lib/screens/`):
  - `login_screen.dart` - Authentication entry point
  - `ocr_screen.dart` - Image capture and OCR submission
- **Services** (`lib/services/`):
  - `auth_service.dart` - Login logic and token management
  - `api_service.dart` - HTTP client for Flask backend communication

#### Theme & Navigation
- Material Design (blue primary swatch)
- Debug banner disabled in production

## Critical Workflows

### Running the Backend
1. **Database Setup**:
   ```bash
   flask db upgrade  # Apply Alembic migrations
   python create_admin.py  # Create initial admin user
   ```

2. **Start Server**:
   ```bash
   python run.py  # Runs on http://localhost:5000 with debug=True
   ```

3. **Key Configuration** (`app/__init__.py`):
   - JWT tokens: Currently `False` expiry (dev mode) - change to `timedelta(hours=8)` for production
   - Database credentials hardcoded (change in `config.py` for deployments)

### Running the Flutter App
```bash
flutter run  # Standard Flutter development
```

## Project-Specific Patterns & Conventions

### Authentication & Authorization
- **Pattern**: JWT tokens with role claims embedded
- **Token Claims**: `{"identity": user_id, "role": user_role}`
- **Implementation**: Use `@jwt_required()` on routes, `get_jwt_identity()` to access claims
- **Authorization**: `require_role(['admin', 'user'])` decorator for role-based protection
- **Important**: Auth decorator must be applied AFTER `@route()` decorator

### File Upload Handling
- **Location**: `app/static/uploads/` (created on-demand via `os.makedirs()`)
- **Validation**: 
  - Whitelist extensions: {png, jpg, jpeg}
  - Use `secure_filename()` to prevent path traversal
  - Check file existence before processing
- **Naming**: Original secure filename preserved (no UUID generation observed)

### Database Patterns
- **ORM**: SQLAlchemy with Flask-SQLAlchemy
- **Migrations**: Alembic-based via Flask-Migrate
- **Sessions**: Auto-commit pattern via `db.session.add()` + `db.session.commit()`
- **Model Registration**: Import models in `app/__init__.py` BEFORE initializing migrate
- **Password Handling**: Always use Werkzeug's `generate_password_hash()` and `check_password_hash()`

### Error Handling
- **API Responses**: `jsonify()` with error dicts and HTTP status codes (400, 401, 403)
- **Observed Pattern**: `{"error": "message"}` format
- **No Custom Exception Classes**: Uses Flask built-in exceptions

### Naming Conventions
- **Blueprint URLs**: Prefix with `/api` in `register_blueprint()` call
- **Form Fields**: Lowercase underscore for file inputs (e.g., "image" field in OCR endpoint)
- **Files**: Thai comments mixed with English code (preserve if editing)

## External Dependencies & Integration Points

### Backend Dependencies
- **Flask**: Web framework
- **Flask-SQLAlchemy**: ORM
- **Flask-Migrate / Alembic**: Database migrations
- **Flask-JWT-Extended**: JWT token management
- **Tesseract-OCR**: Image text extraction (via pytesseract)
- **Pillow (PIL)**: Image loading
- **PyMySQL**: MySQL driver (in connection string)
- **Werkzeug**: Secure file handling, password hashing

### Frontend Dependencies
- **Flutter**: Mobile framework
- **Dart**: Language for Flutter
- **image_picker**: Image capture from camera/gallery
- **shared_preferences**: Local token/session storage (implied)

### Cross-Component Communication
- **Frontend → Backend**:
  - Login: `POST /api/login` → receive JWT
  - OCR Upload: `POST /api/ocr` with multipart form (requires Bearer token in Authorization header)
- **Data Format**: JSON for requests/responses

## Development Notes

### Known Issues & Workarounds
- Debug print statements in OCR route (`print("========== OCR DEBUG =========")`) - Remove before production
- Database credentials in plaintext in `app/__init__.py` and `config.py` - Use environment variables
- No input sanitization on OCR text results - May contain raw Tesseract output

### Testing Considerations
- No test files observed in structure - Consider adding `tests/` directory
- OCR accuracy depends on Tesseract configuration and image quality
- Flutter image picker requires permissions (iOS/Android manifest configuration)

### Extension Points
- **New Routes**: Follow pattern in `auth_routes.py` or `ocr.py` - create Blueprint, register in `app/__init__.py`
- **New Models**: Create in `app/models/`, import in factory, generate migration via `flask db migrate`
- **New Flutter Screens**: Create in `lib/screens/`, add navigation in `main.dart` or routing service
- **New Services**: Create in `app/services/` (backend) or `lib/services/` (frontend), follow function-based approach

## TODO for AI Agents

When working on this codebase:
1. Always apply JWT decorator BEFORE route decorator if adding auth
2. Use `secure_filename()` for any file operations
3. Verify model imports happen in `app/__init__.py` before `migrate.init_app()`
4. Update both Alembic migrations AND model files for schema changes
5. Replace hardcoded credentials (DB, JWT secret) with environment variables before pushing
6. Consider adding tests in `tests/` directory for critical paths
