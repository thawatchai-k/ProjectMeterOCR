import cv2
import pytesseract

img_path = r'c:\Project\flask-meter-ocr\app\static\debug\00_original.jpg'
print(f"Testing on {img_path}")
img = cv2.imread(img_path)

# test full image
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
gray_2x = cv2.resize(gray, (0,0), fx=2, fy=2)
clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
enh = clahe.apply(gray_2x)

data = pytesseract.image_to_data(enh, output_type=pytesseract.Output.DICT)
words = []
for i in range(len(data['text'])):
    t = str(data['text'][i]).strip()
    if t:
        words.append((t, data['left'][i], data['top'][i], data['width'][i], data['height'][i]))

print("Global text scan:")
for w in words:
    print(w)

