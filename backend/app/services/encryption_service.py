from cryptography.fernet import Fernet
import os
from dotenv import load_dotenv

load_dotenv()

# Load key from env or use default for dev (warn in logs)
KEY = os.getenv("ENCRYPTION_KEY")
if not KEY:
    print("WARNING: ENCRYPTION_KEY not found in env, using unsafe default!")
    KEY = b'Z7wQ1Q8Y_5z5Z7wQ1Q8Y_5z5Z7wQ1Q8Y_5z5Z7wQ1Q8='

if isinstance(KEY, str):
    KEY = KEY.encode()

cipher_suite = Fernet(KEY)

def encrypt_data(data: bytes) -> bytes:
    return cipher_suite.encrypt(data)

def decrypt_data(data: bytes) -> bytes:
    return cipher_suite.decrypt(data)
