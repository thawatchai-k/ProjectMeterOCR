from app.models import db
from datetime import datetime

class OCRResult(db.Model):
    __tablename__ = "ocr_results"

    id = db.Column(db.Integer, primary_key=True)
    image_path = db.Column(db.String(255), nullable=False)
    text = db.Column(db.Text, nullable=False)
    serial_number = db.Column(db.String(100), nullable=True)
    reading = db.Column(db.String(50), nullable=True) # Storing as string to preserve formatting if needed
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
