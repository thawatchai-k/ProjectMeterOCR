from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

from app.models.user import User
from app.models.ocr_result import OCRResult
from app.models.meter import Meter
from app.models.meter_reading import MeterReading
