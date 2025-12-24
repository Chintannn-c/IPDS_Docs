from pymongo import MongoClient
import os

# Load MongoDB URI from environment or use default
MONGO_URI = os.getenv("MONGO_URI", "mongodb://localhost:27017")
DB_NAME = "secure_storage_ids"

class Database:
    """Singleton-like wrapper for MongoDB connection."""
    client: MongoClient = None
    db = None

    @staticmethod
    def connect():
        """Establish connection to MongoDB with error handling."""
        try:
            Database.client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
            # Trigger a server call to verify connection
            Database.client.server_info()
            Database.db = Database.client[DB_NAME]
            print("Connected to MongoDB")
        except Exception as e:
            Database.client = None
            Database.db = None
            print(f"Failed to connect to MongoDB: {e}")

    @staticmethod
    def get_db():
        """Return the database instance (may be None if connection failed)."""
        return Database.db

    @staticmethod
    def close():
        """Close the MongoDB client if it exists."""
        if Database.client:
            Database.client.close()
            Database.client = None
            Database.db = None

# Initialize connection at import time
Database.connect()

def test_connection() -> bool:
    """Quick helper to test connectivity; returns True if successful."""
    try:
        test_client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        test_client.server_info()
        return True
    except Exception:
        return False

# Export a convenient instance
db = Database()
