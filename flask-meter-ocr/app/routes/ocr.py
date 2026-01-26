import os
from flask import Blueprint, request, jsonify
from werkzeug.utils import secure_filename
from flask_jwt_extended import jwt_required
from app.services.ocr_service import read_text
from app.models import db
from app.models.ocr_result import OCRResult


ocr_bp = Blueprint("ocr", __name__)

UPLOAD_DIR = "app/static/uploads"
ALLOWED_EXT = {"png", "jpg", "jpeg"}

def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXT


@ocr_bp.route("/ocr", methods=["POST"])
@jwt_required()
def ocr_upload():
    # ❌ ถ้าไม่เจอไฟล์
    if "image" not in request.files:
        return jsonify({"error": "no image file"}), 400

    file = request.files["image"]

    if file.filename == "" or not allowed_file(file.filename):
        return jsonify({"error": "invalid file"}), 400

    os.makedirs(UPLOAD_DIR, exist_ok=True)

    filename = secure_filename(file.filename)
    save_path = os.path.join(UPLOAD_DIR, filename)
    file.save(save_path)

    ocr_data = read_text(save_path)
    
    # read_text now returns a dict
    text_content = ocr_data.get("text", "")
    serial = ocr_data.get("serial", None)
    reading = ocr_data.get("reading", None)

    record = OCRResult(
        image_path=save_path, 
        text=text_content,
        serial_number=serial,
        reading=reading
    )
    db.session.add(record)
    db.session.commit()

    return jsonify({
        "id": record.id,
        "text": text_content,
        "serial": serial,
        "reading": reading
    })


@ocr_bp.route("/history", methods=["GET"])
@jwt_required()
def get_history():
    # เรียงจากล่าสุดไปเก่าสุด
    results = OCRResult.query.order_by(OCRResult.created_at.desc()).all()
    
    data = []
    for r in results:
        # สร้าง URL สำหรับรูปภาพ (สมมติว่า backend map static folder ไว้แล้ว)
        # image_path = "app/static/uploads/filename.jpg"
        # เราต้องแปลงเป็น URL ที่ Flutter เรียกได้ เช่น http://localhost:5000/static/uploads/filename.jpg
        # แต่ใน Database เราเก็บ path เต็ม หรือ relative path?
        # ดูจาก ocr_upload -> save_path = os.path.join(UPLOAD_DIR, filename) -> "app/static/uploads/..."
        
        # แปลง path เป็น url relative
        # เช่น "app/static/uploads/abc.jpg" -> "/static/uploads/abc.jpg"
        relative_path = r.image_path.replace("app", "", 1).replace("\\", "/")
        
        data.append({
            "id": r.id,
            "image_url": relative_path, 
            "text": r.text,
            "serial": r.serial_number,
            "reading": r.reading,
            "created_at": r.created_at.isoformat()
        })

    return jsonify(data), 200
