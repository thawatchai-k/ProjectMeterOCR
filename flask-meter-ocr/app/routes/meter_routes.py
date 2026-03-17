from flask import Blueprint, request, jsonify
from app.models import db
from app.models.meter import Meter

meter_bp = Blueprint('meter', __name__)

@meter_bp.route('/meters', methods=['POST'])
def add_meter():
    data = request.get_json()
    serial_number = data.get('serial_number')
    building = data.get('building')
    floor = data.get('floor')
    reading = data.get('reading')  # เพิ่มรับค่า reading
    image_path = data.get('image_path')  # เพิ่มรับ image_path

    if not serial_number:
        return jsonify({"error": "Serial number is required"}), 400

    existing = Meter.query.filter_by(serial_number=serial_number).first()
    
    if existing:
        # ถ้ามี reading มาด้วย ให้บันทึกค่ามิเตอร์
        if reading:
            from app.models.meter_reading import MeterReading
            new_reading = MeterReading(
                meter_id=existing.id,
                reading=reading,
                image_path=image_path
            )
            db.session.add(new_reading)
            db.session.commit()
            return jsonify({
                "message": "Reading saved successfully",
                "meter": existing.to_dict(),
                "reading": new_reading.to_dict()
            }), 200
        else:
            # ถ้าไม่มี reading คืนข้อมูลมิเตอร์เดิม
            return jsonify({
                "message": "Meter already exists",
                "meter": existing.to_dict()
            }), 200

    # ถ้าไม่มีมิเตอร์นี้ ให้สร้างใหม่
    new_meter = Meter(serial_number=serial_number, building=building, floor=floor)
    db.session.add(new_meter)
    db.session.commit()

    # ถ้ามี reading มาด้วย ให้บันทึกค่ามิเตอร์
    if reading:
        from app.models.meter_reading import MeterReading
        new_reading = MeterReading(
            meter_id=new_meter.id,
            reading=reading,
            image_path=image_path
        )
        db.session.add(new_reading)
        db.session.commit()
        return jsonify({
            "message": "Meter created and reading saved successfully",
            "meter": new_meter.to_dict(),
            "reading": new_reading.to_dict()
        }), 201

    return jsonify(new_meter.to_dict()), 201

@meter_bp.route('/meters', methods=['GET'])
def get_meters():
    meters = Meter.query.order_by(Meter.created_at.desc()).all()
    return jsonify([m.to_dict() for m in meters]), 200

@meter_bp.route('/meters/check', methods=['POST'])
def check_meter():
    """ตรวจสอบว่า S/N มีอยู่ในระบบหรือไม่"""
    data = request.get_json()
    serial_number = data.get('serial_number')
    
    if not serial_number:
        return jsonify({"error": "Serial number is required"}), 400
    
    meter = Meter.query.filter_by(serial_number=serial_number).first()
    if meter:
        return jsonify({
            "exists": True,
            "meter": meter.to_dict()
        }), 200
    else:
        return jsonify({
            "exists": False,
            "message": "This S/N is not found in the system"
        }), 404

from app.utils.auth import require_role

@meter_bp.route('/meters/<int:meter_id>', methods=['DELETE'])
@require_role(["admin"])
def delete_meter(meter_id):
    try:
        meter = Meter.query.get(meter_id)
        if not meter:
            return jsonify({"error": "Meter not found"}), 404
        
        db.session.delete(meter)
        db.session.commit()
        return jsonify({"message": "Deleted successfully (including all history)"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": f"Failed to delete: {str(e)}"}), 500

from app.models.meter_reading import MeterReading
from werkzeug.utils import secure_filename
import os

UPLOAD_DIR = "app/static/uploads/readings"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@meter_bp.route('/readings', methods=['POST'])
def save_reading():
    # รับเป็น Form Data (เพราะอาจมีรูปใหม่) หรือ JSON
    # กรณีนี้สมมติว่ารับค่า text แล้ว (รูปอาจจะใช้อันเดิมหรือใหม่ก็ได้)
    # เพื่อความง่าย รับ JSON: { serial_number, reading, image_path? }
    
    data = request.get_json()
    serial_number = data.get('serial_number')
    reading = data.get('reading')
    image_path = data.get('image_path') # Optional path (จาก OCR result)

    if not serial_number or not reading:
         return jsonify({"error": "S/N and Reading are required"}), 400

    meter = Meter.query.filter_by(serial_number=serial_number).first()
    if not meter:
        return jsonify({"error": "Meter not found. Please register this meter first."}), 404

    new_reading = MeterReading(
        meter_id=meter.id,
        reading=reading,
        image_path=image_path
    )
    db.session.add(new_reading)
    db.session.commit()

    return jsonify(new_reading.to_dict()), 201

@meter_bp.route('/readings/update', methods=['POST'])
def update_reading():
    """สำหรับแก้ไขค่ามิเตอร์และบันทึกทันที"""
    data = request.get_json()
    serial_number = data.get('serial_number')
    reading = data.get('reading')
    image_path = data.get('image_path')

    if not serial_number or not reading:
        return jsonify({"error": "S/N and Reading are required"}), 400

    # ตรวจสอบว่ามีมิเตอร์นี้อยู่หรือไม่
    meter = Meter.query.filter_by(serial_number=serial_number).first()
    if not meter:
        # ถ้าไม่มี ให้สร้างใหม่
        meter = Meter(serial_number=serial_number)
        db.session.add(meter)
        db.session.flush()  # Get ID without committing

    # บันทึนค่ามิเตอร์ใหม่
    new_reading = MeterReading(
        meter_id=meter.id,
        reading=reading,
        image_path=image_path
    )
    db.session.add(new_reading)
    db.session.commit()

    return jsonify({
        "message": "Reading saved successfully",
        "meter": meter.to_dict(),
        "reading": new_reading.to_dict()
    }), 200

@meter_bp.route('/meters/<int:meter_id>/readings', methods=['GET'])
def get_meter_readings(meter_id):
    meter = Meter.query.get(meter_id)
    if not meter:
        return jsonify({"error": "Meter not found"}), 404
        
    readings = MeterReading.query.filter_by(meter_id=meter_id).order_by(MeterReading.created_at.desc()).all()
    return jsonify([r.to_dict() for r in readings]), 200
