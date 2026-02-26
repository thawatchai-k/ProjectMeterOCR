from app import create_app

app = create_app()

if __name__ == "__main__":
    # 0.0.0.0 เพื่อให้ Device อื่นๆ หรือ Emulator เชื่อมต่อได้
    app.run(host='0.0.0.0', port=5000, debug=True)
