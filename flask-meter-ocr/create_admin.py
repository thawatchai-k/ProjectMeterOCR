from app import create_app
from app.models import db
from app.models.user import User

app = create_app()

with app.app_context():
    user = User(username="admin", role="admin")
    user.set_password("1234")
    db.session.add(user)
    db.session.commit()
    print("Admin created successfully")
