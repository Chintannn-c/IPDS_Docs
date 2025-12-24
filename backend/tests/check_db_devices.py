
from app.db.database import Database
from app.core.config import settings
import asyncio

async def check():
    db = Database.get_db()
    # We need to run this in context or just use pymongo directly if Database is async wrapper?
    # Database.get_db() returns db instance.
    
    # Actually Database.get_db() might be sync or async depending on implementation.
    # checking imports: from app.db.database import Database
    # usage: db.users.find_one
    
    # Let's just use pymongo directly to be sure
    from pymongo import MongoClient
    client = MongoClient(settings.MONGO_URI)
    db_name = settings.MONGO_DB_NAME
    db = client[db_name]
    
    users = list(db.users.find())
    print(f"Total Users: {len(users)}")
    for u in users:
        print(f"User: {u.get('email')}")
        td = u.get('trusted_devices', [])
        print(f"  Trusted Devices ({len(td)}):")
        for d in td:
            print(f"    - {d.get('name')} ({d.get('fingerprint')})")

if __name__ == "__main__":
    check()
