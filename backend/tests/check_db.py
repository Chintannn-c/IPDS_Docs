
from app.db.database import Database
import asyncio
from app.api import auth

def check_user():
    Database.connect()
    db = Database.get_db()
    email = "sharmachintan585@gmail.com"
    user = db.users.find_one({"email": email})
    
    if user:
        print(f"User Found: {user['email']}")
        td = user.get('trusted_devices')
        print(f"Trusted Devices Type: {type(td)}")
        if isinstance(td, list):
            print(f"Trusted Devices Length: {len(td)}")
        print(f"Trusted Devices Content: {td}")
    else:
        print("User not found")

if __name__ == "__main__":
    check_user()
