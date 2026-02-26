import pytesseract
import cv2
import numpy as np
from PIL import Image
import os
import re

# ตั้งค่า path ของ Tesseract
tesseract_path = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
if os.name == 'nt' and os.path.exists(tesseract_path):
    pytesseract.pytesseract.tesseract_cmd = tesseract_path

# === Debug: บันทึกภาพ preprocessed ลง disk เพื่อตรวจสอบ ===
DEBUG_DIR = "app/static/debug"
os.makedirs(DEBUG_DIR, exist_ok=True)

def save_debug(name, img):
    """Save debug image for inspection"""
    path = os.path.join(DEBUG_DIR, f"{name}.jpg")
    cv2.imwrite(path, img)
    print(f"  💾 DEBUG saved: {path}")


def preprocess_for_text_detection(gray):
    """สร้างหลายเวอร์ชันของภาพเพื่อเพิ่มโอกาสตรวจจับข้อความ"""
    results = []
    
    # Strategy 1: CLAHE (Contrast Limited Adaptive Histogram Equalization)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)
    results.append(("clahe", enhanced))
    
    # Strategy 2: Simple Binary Threshold
    _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    results.append(("otsu", binary))
    
    # Strategy 3: Adaptive Threshold
    adaptive = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                      cv2.THRESH_BINARY, 21, 10)
    results.append(("adaptive", adaptive))
    
    # Strategy 4: Sharpen + CLAHE
    kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
    sharpened = cv2.filter2D(enhanced, -1, kernel)
    results.append(("sharp_clahe", sharpened))
    
    return results


def run_tesseract_multi(gray, psm=3, digits_only=False):
    """ลอง OCR หลายวิธี เลือกผลลัพธ์ที่ได้ข้อความมากที่สุด"""
    preprocessed_list = preprocess_for_text_detection(gray)
    
    best_text = ""
    best_data = None
    best_name = ""
    
    config_str = f'--oem 3 --psm {psm}'
    if digits_only:
        config_str += ' digits'
    
    for name, processed in preprocessed_list:
        try:
            if psm == 3 or psm == 6:
                data = pytesseract.image_to_data(processed, output_type=pytesseract.Output.DICT)
                text_parts = [str(t) for t in data['text'] if str(t).strip()]
                text = " ".join(text_parts)
                if len(text) > len(best_text):
                    best_text = text
                    best_data = data
                    best_name = name
            else:
                text = pytesseract.image_to_string(processed, config=config_str).strip()
                if len(text) > len(best_text):
                    best_text = text
                    best_data = None
                    best_name = name
        except Exception as e:
            print(f"  ⚠️ Tesseract error with {name}: {e}")
            continue
    
    print(f"  🏆 Best strategy: '{best_name}' -> '{best_text[:80]}'")
    return best_text, best_data


def extract_reading_from_region(img, region_name="reading"):
    """
    อ่านค่าหน่วยไฟจากบริเวณตัวเลขขาวบนพื้นดำ (ส่วนบนของมิเตอร์)
    ใช้หลายวิธี preprocessing เพื่อเพิ่มความแม่นยำ
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img.copy()
    
    results = []
    
    # Method 1: Invert + CLAHE + Threshold (สำหรับเลขขาวบนพื้นดำ)
    clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)
    inverted = cv2.bitwise_not(enhanced)
    _, thresh1 = cv2.threshold(inverted, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    save_debug(f"{region_name}_method1_otsu_inv", thresh1)
    
    # Method 2: Direct Adaptive Threshold Inverted
    thresh2 = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                     cv2.THRESH_BINARY_INV, 15, 8)
    save_debug(f"{region_name}_method2_adaptive_inv", thresh2)
    
    # Method 3: High Contrast + Binary
    high_contrast = cv2.convertScaleAbs(gray, alpha=2.0, beta=-50)
    _, thresh3 = cv2.threshold(high_contrast, 127, 255, cv2.THRESH_BINARY_INV)
    save_debug(f"{region_name}_method3_highcontrast", thresh3)
    
    for i, thresh in enumerate([thresh1, thresh2, thresh3], 1):
        # ขยาย 3x เพื่อให้ Tesseract อ่านตัวเลขได้ชัดขึ้น
        scaled = cv2.resize(thresh, (0, 0), fx=3, fy=3, interpolation=cv2.INTER_CUBIC)
        
        # ลอง PSM 7 (single line) และ PSM 8 (single word)
        for psm in [7, 8, 13]:
            try:
                config = f'--oem 3 --psm {psm} -c tessedit_char_whitelist=0123456789'
                text = pytesseract.image_to_string(scaled, config=config).strip()
                digits = re.sub(r'\D', '', text)
                if digits:
                    results.append((digits, f"m{i}_psm{psm}"))
                    print(f"    📖 {region_name} method{i} psm{psm}: '{text}' -> digits: '{digits}'")
            except:
                pass
    
    return results


def extract_serial_from_region(img, region_name="serial"):
    """
    อ่านค่า S/N จากบริเวณตัวเลขดำบนพื้นขาว/เงิน (ส่วนล่างของมิเตอร์)
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img.copy()
    
    results = []
    
    # Method 1: CLAHE + Otsu (standard)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    enhanced = clahe.apply(gray)
    _, thresh1 = cv2.threshold(enhanced, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    save_debug(f"{region_name}_method1_otsu", thresh1)
    
    # Method 2: Adaptive Threshold
    thresh2 = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                     cv2.THRESH_BINARY, 15, 8)
    save_debug(f"{region_name}_method2_adaptive", thresh2)
    
    # Method 3: Sharpen + Binary
    kernel = np.array([[-1,-1,-1], [-1,9,-1], [-1,-1,-1]])
    sharpened = cv2.filter2D(enhanced, -1, kernel)
    _, thresh3 = cv2.threshold(sharpened, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    save_debug(f"{region_name}_method3_sharpen", thresh3)
    
    for i, thresh in enumerate([thresh1, thresh2, thresh3], 1):
        scaled = cv2.resize(thresh, (0, 0), fx=3, fy=3, interpolation=cv2.INTER_CUBIC)
        
        for psm in [7, 8, 6]:
            try:
                config = f'--oem 3 --psm {psm} -c tessedit_char_whitelist=0123456789'
                text = pytesseract.image_to_string(scaled, config=config).strip()
                digits = re.sub(r'\D', '', text)
                if digits:
                    results.append((digits, f"m{i}_psm{psm}"))
                    print(f"    📖 {region_name} method{i} psm{psm}: '{text}' -> digits: '{digits}'")
            except:
                pass
    
    return results


def find_anchor_and_extract(img, gray_scan, data, anchor_words, offset_rect, 
                            extract_func, region_name):
    """ใช้ anchor word เพื่อหาตำแหน่ง ROI แล้วดึงข้อมูลจาก ROI นั้น"""
    h, w = img.shape[:2]
    
    for i in range(len(data['text'])):
        text = str(data['text'][i]).upper().strip()
        if not text:
            continue
        if any(word in text for word in anchor_words):
            x = data['left'][i]
            y = data['top'][i]
            box_w = data['width'][i]
            box_h = data['height'][i]
            
            print(f"  🎯 Found anchor '{text}' at ({x},{y}) size ({box_w}x{box_h})")
            
            # คำนวณ ROI
            roi_x = max(0, x + int(offset_rect[0] * box_w))
            roi_y = max(0, y + int(offset_rect[1] * box_h))
            roi_w = min(w - roi_x, int(offset_rect[2] * box_w))
            roi_h = min(h - roi_y, int(offset_rect[3] * box_h))
            
            if roi_w <= 0 or roi_h <= 0:
                continue
                
            crop = img[roi_y:roi_y+roi_h, roi_x:roi_x+roi_w]
            if crop.size == 0:
                continue
            
            save_debug(f"{region_name}_roi_crop", crop)
            results = extract_func(crop, region_name)
            if results:
                return results
    
    return []


def advanced_fix_digits(text):
    """แก้ไขตัวเลขที่มักสลับกันจากปัญหาความคอนทราสต์ต่ำ"""
    def replacer(match):
        s = match.group(0)
        s = s.replace('S', '5').replace('s', '5')
        s = s.replace('O', '0').replace('o', '0')
        s = s.replace('G', '6').replace('g', '6')
        s = s.replace('A', '4')
        s = s.replace('B', '8')
        s = s.replace('Z', '2').replace('z', '2')
        s = s.replace('T', '7')
        return s
    return re.sub(r'[A-Za-z0-9]+', replacer, text)


def clean_ocr_text(text):
    """ล้างข้อมูลขยะจาก OCR"""
    text = "\n".join([line.strip() for line in text.split('\n')])
    text = re.sub(r'(?<=\d)\s+(?=\d)', '', text)
    mapping = {
        'O': '0', 'o': '0', 'I': '1', 'i': '1', 'l': '1',
        'S': '5', 's': '5', 'B': '8', 'G': '6', 'T': '7',
        'Z': '2', 'z': '2', 'A': '4', 'U': '0', 'V': '0'
    }
    for char, digit in mapping.items():
        text = re.sub(f'(?<=\d){char}', digit, text)
        text = re.sub(f'{char}(?=\d)', digit, text)
    return text


def extract_numbers(text):
    temp_text = text.replace('|', '').replace('[', '').replace(']', '').replace('(', '').replace(')', '')
    for char, digit in [('O', '0'), ('o', '0'), ('S', '5'), ('s', '5'), ('I', '1'), ('i', '1')]:
        temp_text = temp_text.replace(char, digit)
    return re.findall(r'\d{4,8}', temp_text)


def select_best_reading(candidates, blacklist, current_year=2026):
    """เลือก reading ที่ดีที่สุดจากหลาย candidates"""
    scored = []
    for digits, method in candidates:
        # ค่าหน่วยไฟมัก 4-5 หลัก
        if len(digits) < 3 or len(digits) > 6:
            continue
        if digits in blacklist:
            continue
        # กรองปี
        try:
            if 2010 <= int(digits) <= current_year + 1:
                continue
        except ValueError:
            continue
        
        # คะแนน: ความยาว 4-5 ได้คะแนนสูง
        score = 10
        if 4 <= len(digits) <= 5:
            score += 5
        scored.append((score, digits, method))
    
    scored.sort(reverse=True)
    if scored:
        print(f"  ✅ Best reading: {scored[0][1]} (score: {scored[0][0]}, method: {scored[0][2]})")
        return scored[0][1]
    return None


def select_best_serial(candidates):
    """เลือก serial ที่ดีที่สุดจากหลาย candidates"""
    scored = []
    for digits, method in candidates:
        # S/N มัก 7 หลัก
        if len(digits) < 5 or len(digits) > 10:
            continue
        
        score = 10
        if len(digits) == 7:
            score += 10  # ตรง 7 หลัก = คะแนนสูงสุด
        elif 6 <= len(digits) <= 8:
            score += 3
        scored.append((score, digits, method))
    
    scored.sort(reverse=True)
    if scored:
        print(f"  ✅ Best serial: {scored[0][1]} (score: {scored[0][0]}, method: {scored[0][2]})")
        return scored[0][1]
    return None


def auto_correct_rotation(img):
    """
    ตรวจจับและแก้ไขการหมุนของภาพอัตโนมัติ
    ลอง 4 มุม (0, 90, 180, 270) แล้วเลือกมุมที่ Tesseract อ่านข้อความได้มากที่สุด
    """
    best_angle = 0
    best_score = 0
    
    # ลดขนาดภาพเพื่อทดสอบเร็วขึ้น
    h, w = img.shape[:2]
    scale = min(1.0, 800.0 / max(h, w))
    small = cv2.resize(img, (int(w * scale), int(h * scale)))
    
    rotations = {
        0: small,
        90: cv2.rotate(small, cv2.ROTATE_90_COUNTERCLOCKWISE),
        180: cv2.rotate(small, cv2.ROTATE_180),
        270: cv2.rotate(small, cv2.ROTATE_90_CLOCKWISE),
    }
    
    for angle, rotated in rotations.items():
        gray = cv2.cvtColor(rotated, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        enhanced = clahe.apply(gray)
        
        try:
            data = pytesseract.image_to_data(enhanced, output_type=pytesseract.Output.DICT)
            words = []
            for j in range(len(data['text'])):
                txt = str(data['text'][j]).strip()
                conf = int(data['conf'][j]) if data['conf'][j] != '-1' else 0
                if txt and conf > 30:
                    words.append(txt)
            
            score = len(words)
            text_preview = " ".join(words[:10])
            print(f"  🔄 {angle}°: {score} words -> '{text_preview}'")
            
            if score > best_score:
                best_score = score
                best_angle = angle
        except Exception as e:
            print(f"  ⚠️ Rotation test {angle}° error: {e}")
    
    print(f"  ✅ Best rotation: {best_angle}° ({best_score} words)")
    
    # หมุนภาพต้นฉบับ (ขนาดเต็ม)
    if best_angle == 90:
        return cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)
    elif best_angle == 180:
        return cv2.rotate(img, cv2.ROTATE_180)
    elif best_angle == 270:
        return cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    return img


def read_text(image_path: str) -> dict:
    print(f"\n{'='*60}")
    print(f"🔹 OCR Engine v2.1 - Auto-Rotate + Multi-Strategy: {image_path}")
    print(f"{'='*60}")
    
    img = cv2.imread(image_path)
    if img is None: 
        print("❌ Failed to read image!")
        return {"text": "", "serial": None, "reading": None}
    
    h, w = img.shape[:2]
    print(f"📐 Original image size: {w}x{h}")
    
    # ============================================================
    # STEP 0: Auto-Rotation Detection
    # ============================================================
    print("\n--- Step 0: Auto-Rotation Detection ---")
    img = auto_correct_rotation(img)
    h, w = img.shape[:2]
    print(f"📐 After rotation: {w}x{h}")
    save_debug("00_original", img)
    
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # ============================================================
    # STEP 1: Global Text Detection - ลอง preprocessor หลายตัว
    # ============================================================
    print("\n--- Step 1: Global Text Detection ---")
    
    # ขยาย 2x เพื่อให้ Tesseract หาข้อความได้ง่ายขึ้น
    gray_2x = cv2.resize(gray, (w * 2, h * 2), interpolation=cv2.INTER_CUBIC)
    
    best_text, best_data = run_tesseract_multi(gray_2x, psm=6)
    
    # ถ้า PSM 6 ไม่ได้ผล ลอง PSM 3
    if len(best_text.split()) < 5:
        print("  🔄 Retrying with PSM 3...")
        text2, data2 = run_tesseract_multi(gray_2x, psm=3)
        if len(text2) > len(best_text):
            best_text = text2
            best_data = data2
    
    detected_words = best_text.split()
    print(f"🔍 All detected words: {detected_words}")
    
    # ปรับพิกัดกลับ (เพราะขยาย 2x)
    if best_data:
        for key in ['left', 'top', 'width', 'height']:
            best_data[key] = [int(v / 2) for v in best_data[key]]
    
    final_result = {"serial": None, "reading": None, "text": best_text}
    
    blacklist = ['1000', '2000', '1200', '220', '240', '50', '60']
    current_year = 2026
    
    # ============================================================
    # STEP 2: Anchor-based ROI Extraction
    # ============================================================
    print("\n--- Step 2: Anchor-based ROI Extraction ---")
    
    if best_data:
        # A. Reading: ค้นจากคำว่า kWh, WATT (ตัวเลขอยู่ทางซ้ายและด้านล่าง)
        reading_cands = find_anchor_and_extract(
            img, gray_2x, best_data,
            ["KWH", "KW", "WATT", "HOUR"],
            [-8.0, -1.0, 9.0, 6.0],  # ดูทางซ้ายกว้างๆ ลงด้านล่าง
            extract_reading_from_region,
            "reading_anchor"
        )
        if reading_cands:
            result = select_best_reading(reading_cands, blacklist, current_year)
            if result:
                final_result['reading'] = result

        # B. Serial: ค้นจากคำว่า No., NO, S/N (ตัวเลขอยู่ทางขวา)
        serial_cands = find_anchor_and_extract(
            img, gray_2x, best_data,
            ["NO.", "NO", "S/N", "SN"],
            [0.5, -0.5, 10.0, 3.0],  # ดูทางขวากว้างๆ
            extract_serial_from_region,
            "serial_anchor"
        )
        if serial_cands:
            result = select_best_serial(serial_cands)
            if result:
                final_result['serial'] = result

    # ============================================================
    # STEP 3: Region-based Scanning (ถ้า anchor ไม่เจอ)
    # ============================================================
    if not final_result['reading'] or not final_result['serial']:
        print("\n--- Step 3: Region-based Scanning ---")
        
        # แบ่งภาพเป็นส่วนๆ ตามตำแหน่งที่คาดว่าจะมีข้อมูล
        # ส่วนบน (20-50% จากบน): มักเป็นค่าหน่วยไฟ (เลขขาวบนดำ)
        # ส่วนล่าง (50-80% จากบน): มักเป็น S/N (เลขดำบนขาว/เงิน)
        
        if not final_result['reading']:
            print("  🔎 Scanning UPPER region for reading...")
            upper_y1 = int(h * 0.10)
            upper_y2 = int(h * 0.50)
            upper_region = img[upper_y1:upper_y2, :]
            save_debug("region_upper", upper_region)
            
            reading_cands = extract_reading_from_region(upper_region, "region_reading")
            if reading_cands:
                result = select_best_reading(reading_cands, blacklist, current_year)
                if result:
                    final_result['reading'] = result
        
        if not final_result['serial']:
            print("  🔎 Scanning LOWER region for serial...")
            lower_y1 = int(h * 0.40)
            lower_y2 = int(h * 0.75)
            lower_region = img[lower_y1:lower_y2, :]
            save_debug("region_lower", lower_region)
            
            serial_cands = extract_serial_from_region(lower_region, "region_serial")
            if serial_cands:
                result = select_best_serial(serial_cands)
                if result:
                    final_result['serial'] = result

    # ============================================================
    # STEP 4: Full-image Fallback
    # ============================================================
    if not final_result['reading'] or not final_result['serial']:
        print("\n--- Step 4: Full-image Fallback ---")
        
        # ลอง OCR ทั้งภาพด้วยหลายวิธี
        preprocessed_list = preprocess_for_text_detection(gray)
        
        all_nums = []
        for name, processed in preprocessed_list:
            try:
                scaled = cv2.resize(processed, (0, 0), fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
                raw_text = pytesseract.image_to_string(scaled, config='--oem 3 --psm 6')
                print(f"  📄 Fallback {name}: '{raw_text[:100]}...'")
                cleaned = advanced_fix_digits(raw_text)
                cleaned = clean_ocr_text(cleaned)
                nums = extract_numbers(cleaned)
                for n in nums:
                    all_nums.append((n, f"fallback_{name}"))
            except Exception as e:
                print(f"  ⚠️ Fallback {name} error: {e}")
        
        if not final_result['serial']:
            serial_cands = [(n, m) for n, m in all_nums if 6 <= len(n) <= 8]
            if serial_cands:
                result = select_best_serial(serial_cands)
                if result:
                    final_result['serial'] = result
        
        if not final_result['reading']:
            reading_cands = [(n, m) for n, m in all_nums if 3 <= len(n) <= 6]
            if reading_cands:
                result = select_best_reading(reading_cands, blacklist, current_year)
                if result:
                    final_result['reading'] = result

    print(f"\n{'='*60}")
    print(f"✅ FINAL RESULT -> S/N: {final_result['serial']}, Reading: {final_result['reading']}")
    print(f"{'='*60}\n")
    return final_result
