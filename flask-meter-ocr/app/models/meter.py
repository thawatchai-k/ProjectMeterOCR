from app.models import db
from datetime import datetime

class Meter(db.Model):
    __tablename__ = "meters"

    id = db.Column(db.Integer, primary_key=True)
    serial_number = db.Column(db.String(100), unique=True, nullable=False)
    building = db.Column(db.String(100), nullable=True)
    floor = db.Column(db.String(50), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    # Relationship to readings with cascade delete
    readings = db.relationship("MeterReading", back_populates="meter", cascade="all, delete-orphan")

    def to_dict(self):
        return {
            "id": self.id,
            "serial_number": self.serial_number,
            "building": self.building,
            "floor": self.floor,
            "created_at": self.created_at.isoformat()
        }
