import pytesseract
import cv2
import numpy as np
import os
import re

# ตั้งค่า path ของ Tesseract
tesseract_path = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
if os.name == 'nt' and os.path.exists(tesseract_path):
    pytesseract.pytesseract.tesseract_cmd = tesseract_path

# === Debug ===
DEBUG_DIR = "app/static/debug"
os.makedirs(DEBUG_DIR, exist_ok=True)

def save_debug(name, img):
    path = os.path.join(DEBUG_DIR, f"{name}.jpg")
    cv2.imwrite(path, img)
    print(f"  💾 DEBUG: {path}")

def auto_correct_rotation(img):
    """หมุนภาพอัตโนมัติ"""
    best_angle = 0
    best_score = 0
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
            words = [str(data['text'][j]).strip() for j in range(len(data['text']))
                     if str(data['text'][j]).strip() and int(data['conf'][j]) > 30]
            score = len(words)
            if score > best_score:
                best_score = score
                best_angle = angle
        except:
            pass
    
    print(f"  ✅ Best rotation: {best_angle}°")
    if best_angle == 90: return cv2.rotate(img, cv2.ROTATE_90_COUNTERCLOCKWISE)
    elif best_angle == 180: return cv2.rotate(img, cv2.ROTATE_180)
    elif best_angle == 270: return cv2.rotate(img, cv2.ROTATE_90_CLOCKWISE)
    return img

def create_black_on_white(crop, is_reading=True):
    """
    ทำภาพให้เป็น 'ตัวหนังสือสีดำ พื้นหลังสีขาว 100%'
    is_reading=True: เลขดั้งเดิมสีขาว บนพื้นดำ (ค่าหน่วยไฟ) -> Invert
    is_reading=False: เลขดั้งเดิมสีดำ บนพื้นสีเงิน (S/N) -> Binarize
    """
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY) if len(crop.shape) == 3 else crop.copy()
    
    # ขยายภาพ 3 เท่า
    gray = cv2.resize(gray, (0, 0), fx=3, fy=3, interpolation=cv2.INTER_CUBIC)
    
    # ลด Noise
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    
    thresholds = []
    
    if is_reading:
        # ค่าหน่วยไฟเลขขาวบนดำ -> Invert เพื่อให้เป็นเลขดำบนขาว
        inv = cv2.bitwise_not(blurred)
        _, t1 = cv2.threshold(inv, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        thresholds.append((t1, "reading_otsu"))
        
        _, t2 = cv2.threshold(blurred, 150, 255, cv2.THRESH_BINARY_INV)
        thresholds.append((t2, "reading_fixed"))
    else:
        # S/N เลขดำบนสีเงิน
        t1 = cv2.adaptiveThreshold(blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                   cv2.THRESH_BINARY, 21, 10)
        thresholds.append((t1, "serial_adaptive"))
        
        _, t2 = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        thresholds.append((t2, "serial_otsu"))
        
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        enh = clahe.apply(blurred)
        _, t3 = cv2.threshold(enh, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        thresholds.append((t3, "serial_clahe_otsu"))
        
        # เพิ่มโหมด High Contrast สำหรับเลขที่พื้นหลังสว่างมาก
        _, t4 = cv2.threshold(blurred, 180, 255, cv2.THRESH_BINARY)
        thresholds.append((t4, "serial_high_contrast"))

    processed_images = []
    for thresh, name in thresholds:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        clean = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
        
        # สำหรับเลข 7-segment: เชื่อมช่องว่างด้วย Morph Close
        kernel_close = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        clean = cv2.morphologyEx(clean, cv2.MORPH_CLOSE, kernel_close)
        
        padded = cv2.copyMakeBorder(clean, 50, 50, 50, 50, cv2.BORDER_CONSTANT, value=255)
        save_debug(f"clean_{name}", padded)
        processed_images.append(padded)
        
    return processed_images

def read_text(image_path: str, reading_roi: dict = None, serial_roi: dict = None) -> dict:
    print(f"\n{'='*60}")
    print(f"🔹 OCR Engine v7.7 (ROI-Ready): {image_path}")
    print(f"{'='*60}")
    
    img = cv2.imread(image_path)
    if img is None: return {"text": "", "serial": None, "reading": None}
    
    img = auto_correct_rotation(img)
    save_debug("00_original", img)
    h, w = img.shape[:2]
    
    final_result = {"serial": None, "reading": None, "text": ""}
    reading_crops = []
    serial_crops = []

    # ============================================================
    # 0. Manual ROI Cropping (Priority)
    # ============================================================
    if reading_roi and isinstance(reading_roi, dict):
        try:
            rx, ry, rw, rh = reading_roi['x'], reading_roi['y'], reading_roi['w'], reading_roi['h']
            # แปลงพิกัดสัมพัทธ์ (0-1) เป็นพิกัดจริง
            x1, y1 = int(rx * w), int(ry * h)
            x2, y2 = int((rx + rw) * w), int((ry + rh) * h)
            # ป้องกันขอบรูป
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(w, x2), min(h, y2)
            
            if x2 > x1 and y2 > y1:
                crop = img[y1:y2, x1:x2]
                reading_crops.append(crop)
                print(f"  🎯 Manual ROI Reading: ({x1}, {y1}) to ({x2}, {y2})")
                save_debug("roi_reading_manual", crop)
        except Exception as e:
            print(f"  ⚠️ Manual ROI Reading Error: {e}")

    if serial_roi and isinstance(serial_roi, dict):
        try:
            sx, sy, sw, sh = serial_roi['x'], serial_roi['y'], serial_roi['w'], serial_roi['h']
            x1, y1 = int(sx * w), int(sy * h)
            x2, y2 = int((sx + sw) * w), int((sy + sh) * h)
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(w, x2), min(h, y2)
            
            if x2 > x1 and y2 > y1:
                crop = img[y1:y2, x1:x2]
                serial_crops.append(crop)
                print(f"  🎯 Manual ROI Serial: ({x1}, {y1}) to ({x2}, {y2})")
                save_debug("roi_serial_manual", crop)
        except Exception as e:
            print(f"  ⚠️ Manual ROI Serial Error: {e}")

    # ============================================================
    # 1. ค้นหา Anchor (ถ้ายังไม่ได้ ROI หรือต้องการหาเพิ่ม)
    # ============================================================
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray_2x = cv2.resize(gray, (w*2, h*2), interpolation=cv2.INTER_CUBIC)

    if not reading_crops or not serial_crops:
        print("\n--- Scanning for anchors ---")
    
    # ลองหลายเทคนิคเพื่อหา Anchor
    processing_variants = [
        ("clahe", cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(gray_2x)),
        ("otsu", cv2.threshold(gray_2x, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1])
    ]
    
    for proc_name, enhanced_img in processing_variants:
        
        print(f"  🔍 Scanning with {proc_name}...")
        save_debug(f"scan_{proc_name}", enhanced_img)
        
        try:
            # ลอง PSM 3 (Auto) และ 11 (Sparse text)
            for psm in [3, 11, 13]:
                
                config = f'--oem 3 --psm {psm}'
                data = pytesseract.image_to_data(enhanced_img, config=config, output_type=pytesseract.Output.DICT)
                
                for i in range(len(data['text'])):
                    txt = str(data['text'][i]).upper().strip()
                    if not txt: continue
                    
                    # --- 1) Anchor สำหรับค่าไฟ: /5A, /10A, /15A ---
                    reading_anchors = ['/5A', '5A', 'OSA', '/SA', 'SA', 'ISA', '/15A', '10A', '15A', '‘SA', '‘5A', '(SA', 'ISA', 'I5A']
                    if any(anchor in txt for anchor in reading_anchors):
                        ax, ay, aw, ah = data['left'][i]//2, data['top'][i]//2, data['width'][i]//2, data['height'][i]//2
                        
                        # ROI: กลับมาใช้แบบที่เน้นความแม่นยำ (Tight margins)
                        x1 = max(0, ax - int(ah * 1.0)) 
                        x2 = min(w, ax + int(ah * 12.0)) 
                        y1 = max(0, ay - int(ah * 1.0))
                        y2 = min(h, ay + int(ah * 2.1))
                        
                        if x2 > x1 and y2 > y1:
                            crop = img[y1:y2, x1:x2]
                            reading_crops.append(crop)
                            save_debug(f"roi_reading_{len(reading_crops)}", crop)

                    # --- 2) Anchor สำหรับ S/N: No. ---
                    serial_anchors = ['NO.', 'NO', 'N0.', 'N0', 'NO:', 'N0:', 'N.O.', 'NOIL', 'NOI', 'NON', 'NOM']
                    if (any(txt.startswith(anchor) for anchor in serial_anchors) or 'VHO' in txt or 'N0.' in txt):
                        ax, ay, aw, ah = data['left'][i]//2, data['top'][i]//2, data['width'][i]//2, data['height'][i]//2
                        
                        # ROI: สำหรับ S/N (เน้นบรรทัดเดียวกัน)
                        x1 = max(0, ax - int(ah * 2.0))
                        x2 = min(w, ax + int(ah * 22.0)) 
                        y1 = max(0, ay - int(ah * 0.8))
                        y2 = min(h, ay + int(ah * 1.8))
                        
                        if x2 > x1 and y2 > y1:
                            crop = img[y1:y2, x1:x2]
                            serial_crops.append(crop)
                            save_debug(f"roi_serial_{len(serial_crops)}", crop)
        except Exception as e:
            print(f"  ⚠️ Scan error: {e}")

    # ============================================================
    # 1.5 Fallback: Scan All if anchors not found
    # ============================================================
    if not reading_crops or not serial_crops:
        print("\n--- Fallback: Full Image Digit Hunt ---")
        # ใช้ภาพ 2x enhanced ดั้งเดิม (clahe)
        enhanced_fallback = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(gray_2x)
        try:
            for psm in [3, 6, 11, 13]:
                config = f'--oem 3 --psm {psm} -c tessedit_char_whitelist=0123456789'
                data = pytesseract.image_to_data(enhanced_fallback, config=config, output_type=pytesseract.Output.DICT)
                
                for i in range(len(data['text'])):
                    txt = str(data['text'][i]).strip()
                    conf = int(data['conf'][i])
                    if not txt or conf < 30: continue
                    
                    # Hunt for Reading (4-5 digits)
                    if not reading_crops and len(txt) in [4, 5] and txt not in ['1000', '2000']:
                        ax, ay, aw, ah = data['left'][i]//2, data['top'][i]//2, data['width'][i]//2, data['height'][i]//2
                        x1, x2 = max(0, ax-20), min(w, ax+aw+20)
                        y1, y2 = max(0, ay-20), min(h, ay+ah+20)
                        crop = img[y1:y2, x1:x2]
                        reading_crops.append(crop)
                        print(f"  🎯 Fallback Reading Found: '{txt}' at y={ay}")
                        save_debug("roi_reading_fallback", crop)
                    
                    # Hunt for Serial (7-8 digits)
                    if not serial_crops and len(txt) in [7, 8]:
                        ax, ay, aw, ah = data['left'][i]//2, data['top'][i]//2, data['width'][i]//2, data['height'][i]//2
                        x1, x2 = max(0, ax-30), min(w, ax+aw+30)
                        y1, y2 = max(0, ay-30), min(h, ay+ah+30)
                        crop = img[y1:y2, x1:x2]
                        serial_crops.append(crop)
                        print(f"  🎯 Fallback Serial Found: '{txt}' at y={ay}")
                        save_debug("roi_serial_fallback", crop)
        except Exception as e:
            print(f"  ⚠️ Fallback hunt failed: {e}")

    # ============================================================
    # 2. OCR Reading (บังคับ 4 หลัก)
    # ============================================================
    if reading_crops:
        print("\n--- OCR Reading (Target: 4 digits) ---")
        readings = []
        for r_idx, crop in enumerate(reading_crops):
            clean_images = create_black_on_white(crop, is_reading=True)
            for idx, img_bw in enumerate(clean_images):
                # เน้น PSM 7 (Single Line) และ 8 (Single Word) เป็นหลัก
                for psm in [7, 8, 6]:
                    config = f'--oem 3 --psm {psm} -c tessedit_char_whitelist=0123456789'
                    data = pytesseract.image_to_data(img_bw, config=config, output_type=pytesseract.Output.DICT)
                    
                    for i in range(len(data['text'])):
                        txt = str(data['text'][i]).strip()
                        conf = int(data['conf'][i])
                        if not txt or conf < 40: continue # กรองความมั่นใจต่ำทิ้ง
                        
                        digits = re.sub(r'\D', '', txt)
                        if len(digits) >= 4:
                            res = digits[:4]
                            if res not in ['1000', '2000', '0000']:
                                readings.append(res)
                                print(f"    📖 [Crop {r_idx}, PSM {psm}] Word: '{txt}' (Conf: {conf}) -> {res}")
        
        if readings:
            final_result['reading'] = max(set(readings), key=readings.count)
            print(f"  ✅ Best Reading: {final_result['reading']}")

    # ============================================================
    # 3. OCR Serial (บังคับ 7 หลัก)
    # ============================================================
    if serial_crops:
        print("\n--- OCR Serial (Target: 7 digits) ---")
        serials = []
        for s_idx, crop in enumerate(serial_crops):
            clean_images = create_black_on_white(crop, is_reading=False)
            for idx, img_bw in enumerate(clean_images):
                for psm in [7, 8, 6]:
                    config = f'--oem 3 --psm {psm} -c tessedit_char_whitelist=0123456789'
                    data = pytesseract.image_to_data(img_bw, config=config, output_type=pytesseract.Output.DICT)
                    
                    for i in range(len(data['text'])):
                        txt = str(data['text'][i]).strip()
                        conf = int(data['conf'][i])
                        if not txt or conf < 40: continue
                        
                        clean_d = re.sub(r'\D', '', txt)
                        if len(clean_d) == 7 and clean_d not in ['1000100', '2000200', '4200000']:
                            serials.append(clean_d)
                            print(f"    📖 [Crop {s_idx}, PSM {psm}] Word: '{txt}' (Conf: {conf}) -> {clean_d}")
        
        if serials:
            # กรองค่าที่พบบ่อยที่สุดและไม่ใช่ขยะ
            final_result['serial'] = max(set(serials), key=serials.count)
            print(f"  ✅ Best Serial: {final_result['serial']}")

    print(f"\n{'='*60}")
    print(f"✅ FINAL -> S/N: {final_result['serial']}, Reading: {final_result['reading']}")
    print(f"{'='*60}\n")
    return final_result
