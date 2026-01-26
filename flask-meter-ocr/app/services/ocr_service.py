import pytesseract
from PIL import Image, ImageOps, ImageFilter
import os

# ตั้งค่า path ของ Tesseract สำหรับ Windows
tesseract_path = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
if os.name == 'nt':
    if not os.path.exists(tesseract_path):
            print(f"⚠️ Warning: Tesseract not found at {tesseract_path}")
    pytesseract.pytesseract.tesseract_cmd = tesseract_path

def read_text(image_path: str) -> str:
    print(f"🔹 Processing image: {image_path}")
    img = Image.open(image_path)
    
    # Preprocessing
    img = img.convert('L')  # Convert to grayscale
    # Save debug image to check what Tesseract sees
    debug_dir = r'app/static/debug'
    os.makedirs(debug_dir, exist_ok=True)
    debug_path = os.path.join(debug_dir, f"debug_{os.path.basename(image_path)}")
    img.save(debug_path)
    print(f"🔹 Saved debug image at: {debug_path}")

    # Configure Tesseract
    # Try 1: Specific for digits if possible
    # custom_config = r'--oem 3 --psm 7 outputbase digits'
    
    # Try 2: General text (Relaxed) - Removing 'outputbase digits' and 'psm 7' to let it auto-detect layout
    # PSM 6 = Assume a single uniform block of text.
    custom_config = r'--oem 3 --psm 6'
    
    try:
        text = pytesseract.image_to_string(img, config=custom_config)
        print(f"🔹 Raw OCR Output: '{text}'")
        
        # Post-processing: Extract numbers using Regex
        import re
        
        result = {
            "text": text,
            "serial": None,
            "reading": None
        }

        # --- Attempt 1: Extract Serial Number ---
        # Look for "No." or "S/N" followed by digits/dashes/spaces
        # e.g., "No. 8929 405" -> "8929405"
        serial_match = re.search(r'(?:No|S/N)[.;,:\s]*([A-Za-z0-9-\s]{4,20})', text, re.IGNORECASE)
        if serial_match:
            raw_sn = serial_match.group(1).strip()
            # Merge spaces only if they are between digits
            # No. 8929 405 -> 8929405
            clean_sn = re.sub(r'(?<=\d)\s+(?=\d)', '', raw_sn)
            # Take first token if it still contains non-numeric stuff at the end
            clean_sn = clean_sn.split()[0]
            # Strip trailing noise
            clean_sn = re.sub(r'[^a-zA-Z0-9]+$', '', clean_sn)
            
            if len(re.sub(r'\D', '', clean_sn)) >= 4:
                result['serial'] = clean_sn
        
        if not result['serial']:
             # Fallback: Find long numeric/dashed strings (5+ digits)
             potential_serials = re.findall(r'\b[0-9-]{6,}\b', text)
             if potential_serials:
                 result['serial'] = potential_serials[0]

        # --- Attempt 2: Extract Reading (kWh) ---
        candidates = []
        lines = text.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line: continue
            
            # Step 1: Handle separators
            line_cleaned = re.sub(r'[|:\\\[\]!/]', ' ', line)
            
            # Step 2: Remove Letters
            line_no_letters = re.sub(r'[a-zA-Z]', '', line_cleaned)
            
            # Step 3: Find digit sequences with optional single spaces
            # Matches "8 1 8 8 5" or "8188 5"
            tokens = re.findall(r'\b\d+(?:\s\d+)*\b', line_no_letters)
            
            for token in tokens:
                merged_digits = re.sub(r'\s', '', token)
                
                # Check lengths (Meter readings are usually 4 to 6 digits)
                if 4 <= len(merged_digits) <= 6:
                     # Avoid serial matches
                     if result['serial'] and merged_digits in re.sub(r'\D', '', result['serial']):
                         continue
                     
                     if merged_digits in ['1000', '10000', '5060']: # Skip common specs
                         continue

                     candidates.append(merged_digits)

        print(f"🔹 Reading Candidates: {candidates}")
        
        if candidates:
            # readings usually have more leading zeros
            zeros = [c for c in candidates if c.startswith('0')]
            if zeros:
                result['reading'] = zeros[0]
            else:
                # Prioritize 5-digit numbers for "5-unit meters" as requested
                # If there's a 5-digit candidate, it's likely the winner
                fives = [c for c in candidates if len(c) == 5]
                if fives:
                    result['reading'] = fives[0]
                else:
                    candidates.sort(key=lambda x: abs(5 - len(x)))
                    result['reading'] = candidates[0]

        print(f"🔹 Extracted Result: {result}")
        return result
        
    except Exception as e:
        print(f"❌ Pytesseract Error: {e}")
        raise e
