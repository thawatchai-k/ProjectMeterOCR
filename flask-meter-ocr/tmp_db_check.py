import os
import pymysql
from dotenv import load_dotenv

load_dotenv()

def check_db():
    try:
        connection = pymysql.connect(
            host=os.getenv('DB_HOST'),
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            database=os.getenv('DB_NAME'),
            port=int(os.getenv('DB_PORT', 3306)),
            cursorclass=pymysql.cursors.DictCursor
        )

        with connection.cursor() as cursor:
            # Check for the specific S/N
            sql = "SELECT * FROM meters WHERE serial_number LIKE %s"
            cursor.execute(sql, ('%9108966%',))
            result = cursor.fetchall()
            print(f"Searching for '9108966': {result}")

            # List all meters if not found
            if not result:
                cursor.execute("SELECT serial_number FROM meters LIMIT 20")
                all_meters = cursor.fetchall()
                print(f"Top 20 meters: {all_meters}")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        if 'connection' in locals():
            connection.close()

if __name__ == "__main__":
    check_db()
