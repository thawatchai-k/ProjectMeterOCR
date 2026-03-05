import pytesseract
import cv2
import sys
import os

tesseract_path = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
if os.name == 'nt' and os.path.exists(tesseract_path):
    pytesseract.pytesseract.tesseract_cmd = tesseract_path

img_path = r'C:\Project\flask-meter-ocr\app\static\debug\00_global_scan.jpg'
if not os.path.exists(img_path):
    print("File not found:", img_path)
    sys.exit(1)

print(f"Reading {img_path}")
img = cv2.imread(img_path)

data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)

print("\n--- ALL WORDS DETECTED ---")
words = []
for i in range(len(data['text'])):
    t = str(data['text'][i]).strip()
    if t and int(data['conf'][i]) > 10:
        words.append(t)
        print(f"[{int(data['conf'][i])}%] '{t}'")

print("\nAll text joined:")
print(" ".join(words))
