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
        # e.g., "No. 8249 578"
        serial_match = re.search(r'(?:No|S/N)[.;,:\s]*([A-Za-z0-9-\s]{4,15})', text, re.IGNORECASE)
        if serial_match:
            # Clean up the match (remove trailing spaces/newlines)
            res_sn = serial_match.group(1).split()[0] # Take only the first word/token
            # Clean up artifacts like dashes or dots at the end
            res_sn = re.sub(r'[^a-zA-Z0-9]+$', '', res_sn)
            if len(re.sub(r'\D', '', res_sn)) >= 4:
                result['serial'] = res_sn
        
        if not result['serial']:
             # Fallback: Find long numeric/dashed strings
             potential_serials = re.findall(r'\b[0-9-]{5,}\b', text)
             if potential_serials:
                 result['serial'] = potential_serials[0]

        # --- Attempt 2: Extract Reading (kWh) ---
        candidates = []
        lines = text.split('\n')
        
        for line in lines:
            line = line.strip()
            if not line: continue
            
            # Step 1: Remove Letters and Label artifacts
            # "B08 42 kWh" -> "08 42"
            line_no_letters = re.sub(r'[a-zA-Z]', '', line)
            
            # Step 2: Split by common separators (/, |, \, :)
            parts = re.split(r'[/|\\:]', line_no_letters)
             
            for part in parts:
                # Truncate at first dot (handle "100.10" -> "100")
                if '.' in part:
                    part = part.split('.')[0]
                     
                # Extract only decimals, but preserve spacing for potential "0 8 4 2"
                clean_digits = re.sub(r'[^0-9\s]', '', part).strip()
                # Remove internal spaces for length check
                digits_only = clean_digits.replace(" ", "")
                 
                # Meter readings are usually 4 to 7 digits
                if len(digits_only) >= 4 and len(digits_only) <= 7:
                     # Avoid serial matches: if a candidate is a subset of the serial, skip it
                     if result['serial'] and digits_only in re.sub(r'\D', '', result['serial']):
                         continue
                     
                     candidates.append(digits_only)

        print(f"🔹 Reading Candidates: {candidates}")
        
        if candidates:
            # readings usually have more leading zeros or are "most isolated"
            # for now, take the first valid one
            result['reading'] = candidates[0]

        print(f"🔹 Extracted Result: {result}")
        return result
        
    except Exception as e:
        print(f"❌ Pytesseract Error: {e}")
        raise e
