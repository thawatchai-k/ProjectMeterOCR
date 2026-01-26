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

    if not serial_number:
        return jsonify({"error": "Serial number is required"}), 400

    existing = Meter.query.filter_by(serial_number=serial_number).first()
    if existing:
        return jsonify({"error": "Meter with this serial number already exists"}), 400

    new_meter = Meter(serial_number=serial_number, building=building, floor=floor)
    db.session.add(new_meter)
    db.session.commit()

    return jsonify(new_meter.to_dict()), 201

@meter_bp.route('/meters', methods=['GET'])
def get_meters():
    meters = Meter.query.order_by(Meter.created_at.desc()).all()
    return jsonify([m.to_dict() for m in meters]), 200

@meter_bp.route('/meters/<int:meter_id>', methods=['DELETE'])
def delete_meter(meter_id):
    meter = Meter.query.get(meter_id)
    if not meter:
        return jsonify({"error": "Meter not found"}), 404
    
    db.session.delete(meter)
    db.session.commit()
    return jsonify({"message": "Deleted successfully"}), 200

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
