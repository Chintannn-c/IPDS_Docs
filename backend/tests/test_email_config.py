import sys
import os

# Add the backend directory to sys.path to allow imports from 'app'
sys.path.append(os.getcwd())

from app.core.config import settings
from app.core.email_utils import generate_otp

def test_config():
    print("--- VERIFYING EMAIL CONFIGURATION ---")
    print(f"SMTP_HOST: {settings.SMTP_HOST}")
    print(f"SMTP_PORT: {settings.SMTP_PORT}")
    print(f"SMTP_USER: {settings.SMTP_USER}")
    print(f"SMTP_FROM_NAME: {settings.SMTP_FROM_NAME}")
    print(f"SMTP_PASSWORD SET: {bool(settings.SMTP_PASSWORD)}")
    
    otp = generate_otp()
    print(f"GENERATE OTP TEST: {otp} (Length: {len(otp)})")
    
    print("\nSUCCESS: Configuration loaded correctly.")

if __name__ == "__main__":
    test_config()
