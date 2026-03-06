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

def smart_deskew(img):
    """
    แก้อาการภาพถ่ายเอียง (5-15 องศา) เพื่อให้ Tesseract และ OpenCV วางกรอบได้ตรง
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 50, 150, apertureSize=3)
    
    # หาเส้นตรงในภาพ
    lines = cv2.HoughLinesP(edges, 1, np.pi / 180, 100, minLineLength=100, maxLineGap=10)
    
    if lines is None: return img, 0.0
    
    angles = []
    for line in lines:
        x1, y1, x2, y2 = line[0]
        angle = np.degrees(np.arctan2(y2 - y1, x2 - x1))
        # เก็บเฉพาะเส้นที่นอนราบบวกลบไม่เกิน 15 องศา (ไม่เอาเส้นตั้งฉาก)
        if -15 < angle < 15:
            angles.append(angle)
            
    if not angles: return img, 0.0
    
    # หาค่าเฉลี่ยมุมตัดขยะเอียงทิ้ง
    median_angle = np.median(angles)
    
    if abs(median_angle) < 0.5: return img, median_angle # ตรงอยู่แล้ว ไม่ต้องหมุน
    
    print(f"  📐 Deskewing image by {median_angle:.2f}° (Fixing tilt)")
    
    (h, w) = img.shape[:2]
    center = (w // 2, h // 2)
    M = cv2.getRotationMatrix2D(center, median_angle, 1.0) 
    # ใช้ BORDER_REPLICATE เพื่อไม่ให้ขอบดำโพล่มาหลอก Contour
    rotated = cv2.warpAffine(img, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
    
    return rotated, median_angle

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
        
        # 1) Otsu (Global)
        _, t1 = cv2.threshold(inv, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        thresholds.append((t1, "reading_otsu"))
        
        # 2) Adaptive (Local - ดีสำหรับเงาสะท้อนในกล่องดำ)
        t3 = cv2.adaptiveThreshold(inv, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                   cv2.THRESH_BINARY, 31, 10)
        thresholds.append((t3, "reading_adaptive"))
        
        # 3) Fixed
        _, t2 = cv2.threshold(blurred, 150, 255, cv2.THRESH_BINARY_INV)
        thresholds.append((t2, "reading_fixed"))
    else:
        # --- Technique 2: High Contrast Grayscale (S/N) ---
        # เลิกใช้ Adaptive Threshold เปลี่ยนเป็น Grayscale ภาพดิบปรับ Contrast จัดๆ
        high_contrast = cv2.convertScaleAbs(gray, alpha=2.5, beta=-60)
        thresholds.append((high_contrast, "serial_high_contrast_gray"))
        
        # เก็บ Otsu ไว้เป็นตัวเลือกรอง
        _, t2 = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        thresholds.append((t2, "serial_otsu"))

    processed_images = []
    for thresh, name in thresholds:
        if "gray" not in name:
            kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
            clean = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
            
            kernel_close = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
            clean = cv2.morphologyEx(clean, cv2.MORPH_CLOSE, kernel_close)
        else:
            clean = thresh  # ไม่ทำ Morphology กับภาพ Grayscale
            
        padded = cv2.copyMakeBorder(clean, 50, 50, 50, 50, cv2.BORDER_CONSTANT, value=255)
        save_debug(f"clean_{name}", padded)
        processed_images.append(padded)
        
    return processed_images

def read_text(image_path: str, reading_roi: dict = None, serial_roi: dict = None) -> dict:
    print(f"\n{'='*60}")
    print(f"🔹 OCR Engine v9.0 (Dynamic Contours & Deskew): {image_path}")
    print(f"{'='*60}")
    
    img = cv2.imread(image_path)
    if img is None: return {"text": "", "serial": None, "reading": None}
    
    # ปิดการหมุนภาพ 90 องศาอัตโนมัติ (ข้าม auto_correct_rotation ไปเลย)
    
    # ใช้ Smart Deskew แก้ภาพตะแคง 5-15 องศา
    img, tilt_angle = smart_deskew(img)
    
    save_debug("00_original_deskewed", img)
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

    # แปลงสีเพื่อใช้ในการค้นหา
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    gray_2x = cv2.resize(gray, (w*2, h*2), interpolation=cv2.INTER_CUBIC)

    # ============================================================
    # 0.5 Mission: Geometric Hunt (Physical Discovery)
    # ============================================================
    print("\n--- Mission: Geometric Hunt ---")
    
    # 1) ค้นตามหา "Reading Box" (กล่องสี่เหลี่ยมสีดำขนาดใหญ่)
    try:
        # 1. เบลอภาพนิดหน่อยเพื่อลด Noise ขยะ
        blurred_geom = cv2.GaussianBlur(gray, (5, 5), 0)
        
        # 2. หาพื้นที่สีดำ (เพื่อให้จับสีดำได้ง่ายขึ้นเมื่อมีเงา)
        _, thresh_black = cv2.threshold(blurred_geom, 85, 255, cv2.THRESH_BINARY_INV)
        
        # 3. ใช้ Morphological Close เพื่อ "อุดรอยรั่ว" 
        kernel_box = cv2.getStructuringElement(cv2.MORPH_RECT, (25, 5))
        closed_black = cv2.morphologyEx(thresh_black, cv2.MORPH_CLOSE, kernel_box)
        save_debug("debug_closed_black_box", closed_black)
        
        # 4. หาเส้นขอบ (Contours) จากภาพที่อุดรอยรั่วแล้ว
        contours, _ = cv2.findContours(closed_black, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for cnt in contours:
            x, y, w_cnt, h_cnt = cv2.boundingRect(cnt)
            aspect_ratio = w_cnt / float(h_cnt)
            
            # 5. ขยายช่วง Aspect Ratio ให้กว้างขึ้น (1.8 - 7.0)
            if 1.8 < aspect_ratio < 7.0 and w_cnt > w * 0.15 and y < h * 0.6:
                area = w_cnt * h_cnt
                if area > 4000: 
                    # ตัดขอบล่างออก 15% เพื่อเลี่ยงตัวหนังสือ 1,000, 100, 10 ด้านล่าง
                    y_tight = y
                    h_tight = int(h_cnt * 0.85)
                    crop = img[y_tight:y_tight+h_tight, x:x+w_cnt]
                    reading_crops.append(crop)
                    print(f"  🎯 Geometric Reading Box Found: ({x}, {y}, {w_cnt}x{h_cnt}) -> Tightened")
                    save_debug(f"roi_reading_geom_{len(reading_crops)}", crop)
    except Exception as e:
        print(f"  ⚠️ Geometric Reading Hunt error: {e}")

    # 2) ค้นตามหา "Serial Line" (แถวตัวเลขแนวนอน)
    try:
        # ใช้ Adaptive Threshold เพื่อหาขอบตัวเลขสำหรับ S/N
        binary = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 51, 10)
        # ใช้ Morph Close แนวนอนที่กว้างขึ้นเพื่อเชื่อมช่องว่างระหว่างชุดตัวเลข (เช่น 9108 966)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (80, 4)) 
        morphed = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
        save_debug("scan_geometric_serial_morph", morphed)
        contours, _ = cv2.findContours(morphed, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for cnt in contours:
            x, y, w_cnt, h_cnt = cv2.boundingRect(cnt)
            aspect_ratio = w_cnt / float(h_cnt)
            
            # กรองรูปทรงที่น่าจะเป็นแถว S/N (ยาวๆ และอยู่ช่วงกลางถึงล่าง)
            if aspect_ratio > 4.5 and w_cnt > 120 and h * 0.4 < y < h * 0.95:
                # เผื่อขอบด้านข้างมากขึ้นสำหรับ S/N
                crop = img[max(0, y-15):min(h, y+h_cnt+15), max(0, x-20):min(w, x+w_cnt+20)]
                serial_crops.append(crop)
                print(f"  🎯 Geometric Serial Line Found: ({x}, {y}, {w_cnt}x{h_cnt})")
                save_debug(f"roi_serial_geom_{len(serial_crops)}", crop)
    except Exception as e:
        print(f"  ⚠️ Geometric Serial Hunt error: {e}")

    # ============================================================
    # 1. ค้นหา Anchor (ถ้ายังไม่ได้ ROI หรือต้องการหาเพิ่ม)
    # ============================================================
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
            for psm in [3, 11, 13]:
                config = f'--oem 3 --psm {psm} -c tessedit_char_whitelist=0123456789'
                data = pytesseract.image_to_data(enhanced_fallback, config=config, output_type=pytesseract.Output.DICT)
                
                # ลองรวบรวมข้อความทั้งหมดในภาพมาเช็ค Serial (สำหรับกรณีลอยๆ)
                raw_text = " ".join([str(t).strip() for t in data['text'] if str(t).strip()])
                clean_raw = re.sub(r'\D', '', raw_text)
                
                for i in range(len(data['text'])):
                    txt = str(data['text'][i]).strip()
                    conf = int(data['conf'][i])
                    if not txt or conf < 30: continue
                    
                    digits = re.sub(r'\D', '', txt)
                    # Hunt for Reading (4-5 digits)
                    if not reading_crops and len(digits) in [4, 5] and digits not in ['1000', '2000']:
                        ax, ay, aw, ah = data['left'][i]//2, data['top'][i]//2, data['width'][i]//2, data['height'][i]//2
                        x1, x2 = max(0, ax-20), min(w, ax+aw+20)
                        y1, y2 = max(0, ay-20), min(h, ay+ah+20)
                        crop = img[y1:y2, x1:x2]
                        reading_crops.append(crop)
                        print(f"  🎯 Fallback Reading Found: '{digits}' at y={ay}")
                        save_debug("roi_reading_fallback", crop)
                    
                    # Hunt for Serial (7-8 digits ในคำเดียว)
                    if not serial_crops and len(digits) in [7, 8]:
                        ax, ay, aw, ah = data['left'][i]//2, data['top'][i]//2, data['width'][i]//2, data['height'][i]//2
                        x1, x2 = max(0, ax-30), min(w, ax+aw+30)
                        y1, y2 = max(0, ay-30), min(h, ay+ah+30)
                        crop = img[y1:y2, x1:x2]
                        serial_crops.append(crop)
                        print(f"  🎯 Fallback Serial Found: '{digits}' at y={ay}")
                        save_debug("roi_serial_fallback", crop)
                
                # กรณี Serial ถูกแยกเป็นหลายคำใน Fallback
                if not serial_crops:
                    match = re.search(r'(\d{7,8})', clean_raw)
                    if match:
                        print(f"  🎯 Fallback Serial Found (Multi-word): {match.group(1)}")
                        # เนื่องจากเป็น Multi-word การหาพิกัดจะยากหน่อย เอา ROI ทั้งภาพหรือแถบกลางภาพ
                        y1, y2 = int(h*0.4), int(h*0.9)
                        crop = img[y1:y2, 0:w]
                        serial_crops.append(crop)
                        save_debug("roi_serial_fallback_wide", crop)

        except Exception as e:
            print(f"  ⚠️ Fallback hunt failed: {e}")

    # ============================================================
    # 2. OCR Reading (บังคับ 4 หลัก)
    # ============================================================
    if reading_crops:
        print("\n--- OCR Reading (Target: 4 digits) ---")
        readings = []
        for r_idx, crop in enumerate(reading_crops):
            
            # --- Technique 2: Dynamic Contour Blobbing (V9.0) ---
            print(f"  🧠 Extracting Digits via Dynamic Contours (Crop {r_idx})...")
            
            # 1. ขยายร่างเพื่อให้เห็นช่องไฟชัดขึ้น
            big_crop = cv2.resize(crop, None, fx=2.5, fy=2.5, interpolation=cv2.INTER_CUBIC)
            gray_crop = cv2.cvtColor(big_crop, cv2.COLOR_BGR2GRAY) if len(big_crop.shape) == 3 else big_crop.copy()
            
            # 2. ปรับ Contrast & Adaptive เพื่อเจาะเอาเฉพาะตัวเลขขาว
            dark_adj = cv2.convertScaleAbs(gray_crop, alpha=1.5, beta=-30)
            binary_crop = cv2.adaptiveThreshold(dark_adj, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                                cv2.THRESH_BINARY_INV, 31, 10)
            
            # 3. หรี่ตาหาอวัยวะตัวอักษร
            contours_digit, _ = cv2.findContours(binary_crop, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            # 4. กรองเฉพาะ Contours ที่มีขนาดเหมือนตัวเลข
            digit_blobs = []
            h_big, w_big = big_crop.shape[:2]
            for cnt_d in contours_digit:
                xd, yd, wd, hd = cv2.boundingRect(cnt_d)
                
                # กรองขยะ: ต้องสูงอย่างน้อย 35% ของความสูงทั้งหมด แต่ไม่เกิน 95% (ไม่ใช่กรอบนอก)
                # และกว้างในระดับพอดีตัวเลข
                if h_big * 0.35 < hd < h_big * 0.95 and wd > 10:
                    digit_blobs.append((xd, yd, wd, hd))
            
            # 5. เรียงลำดับจากซ้ายไปขวา
            digit_blobs = sorted(digit_blobs, key=lambda b: b[0])
            
            blob_reading = ""
            for s, (xd, yd, wd, hd) in enumerate(digit_blobs[:4]): # เอาแค่ 4 ตัวแรก ตัดทศนิยมทิ้ง
                # ดึงภาพตัวหนังสือ (เผื่อขอบนิดหน่อย)
                blob_img = binary_crop[max(0, yd-5):min(h_big, yd+hd+5), max(0, xd-5):min(w_big, xd+wd+5)]
                
                # Invert ให้เป็นเลขดำบนพื้นขาว
                bw_blob = cv2.bitwise_not(blob_img)
                
                # เติมพื้นที่หายใจหนาๆ
                padded_blob = cv2.copyMakeBorder(bw_blob, 30, 30, 30, 30, cv2.BORDER_CONSTANT, value=255)
                save_debug(f"clean_reading_blob_{r_idx}_{s}", padded_blob)
                
                # ส่งให้อ่านตัวเลขอิสระ!
                config = '--oem 3 --psm 10 -c tessedit_char_whitelist=0123456789'
                char = pytesseract.image_to_string(padded_blob, config=config).strip()
                digits = re.sub(r'\D', '', char)
                blob_reading += digits[0] if digits else "?"
                
            print(f"    🧠 [Contour Blobbing] Raw Result: '{blob_reading}'")
            if "?" not in blob_reading and len(blob_reading) == 4 and blob_reading not in ['1000', '2000', '0000']:
                readings.append(blob_reading)
                print(f"    ⭐ [Contour Blobbing] Accepted: '{blob_reading}'")

            # --- วิธีดั้งเดิม (เผื่อสับตกขอบ) ---
            clean_images = create_black_on_white(crop, is_reading=True)
            for idx, img_bw in enumerate(clean_images):
                # เน้น PSM 7 (Single Line) และ 8 (Single Word) เป็นหลัก
                for psm in [7, 8, 6]:
                    config = f'--oem 3 --psm {psm} -c tessedit_char_whitelist=0123456789'
                    data = pytesseract.image_to_data(img_bw, config=config, output_type=pytesseract.Output.DICT)
                    
                    for i in range(len(data['text'])):
                        txt = str(data['text'][i]).strip()
                        conf = int(data['conf'][i])
                        if not txt or conf < 30: continue 
                        
                        digits = re.sub(r'\D', '', txt)
                        # รองรับ 4-5 หลัก (เผื่อเศษทศนิยม)
                        if len(digits) >= 4:
                            res = digits[:4]
                            if res not in ['1000', '2000', '0000']:
                                readings.append(res)
                                print(f"    📖 [Reading] Word: '{txt}' (Conf: {conf}) -> {res}")
        
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
                    
                # รวบรวมข้อความทั้งหมดในภาพมาต่อกัน (เพื่อรับมือกับช่องว่าง เช่น 9108 966)
                full_text = " ".join([str(t).strip() for t in data['text'] if str(t).strip()])
                avg_conf = sum([int(c) for c in data['conf'] if int(c) > 0]) / max(1, len([c for c in data['conf'] if int(c) > 0]))
                
                if full_text:
                    print(f"    🔍 [Serial Raw] PSM {psm}: '{full_text}' (Avg Conf: {avg_conf:.1f})")
                    
                    # ล้างอักขระที่ไม่ใช่ตัวเลข
                    clean_d = re.sub(r'\D', '', full_text)
                    
                    # ตรวจสอบความยาว 7 หรือ 8 หลัก
                    if len(clean_d) in [7, 8] and clean_d not in ['1000100', '2000200', '4200000']:
                        serials.append(clean_d)
                        print(f"    ✨ Found Serial: {clean_d}")
                    elif len(clean_d) > 8:
                        # กรณีอ่านติดขยะมาด้วย ให้ลองหาแพทเทิร์น 7-8 หลักในนั้น
                        match = re.search(r'(\d{7,8})', clean_d)
                        if match:
                            candidate = match.group(1)
                            serials.append(candidate)
                            print(f"    ✨ Found Serial (Regex): {candidate}")
        
        if serials:
            # กรองค่าที่พบบ่อยที่สุดและไม่ใช่ขยะ
            final_result['serial'] = max(set(serials), key=serials.count)
            print(f"  ✅ Best Serial: {final_result['serial']}")

    print(f"\n{'='*60}")
    print(f"✅ FINAL -> S/N: {final_result['serial']}, Reading: {final_result['reading']}")
    print(f"{'='*60}\n")
    return final_result
