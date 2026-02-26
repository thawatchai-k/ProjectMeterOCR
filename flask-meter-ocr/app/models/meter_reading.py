from app.models import db
from datetime import datetime

class MeterReading(db.Model):
    __tablename__ = "meter_readings"

    id = db.Column(db.Integer, primary_key=True)
    meter_id = db.Column(db.Integer, db.ForeignKey('meters.id'), nullable=False)
    reading = db.Column(db.String(50), nullable=False)
    image_path = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Relationship
    meter = db.relationship("Meter", back_populates="readings")

    def to_dict(self):
        return {
            "id": self.id,
            "meter_id": self.meter_id,
            "serial_number": self.meter.serial_number if self.meter else None,
            "reading": self.reading,
            "image_path": self.image_path,
            "created_at": self.created_at.isoformat()
        }
