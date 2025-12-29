import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    SECRET_KEY = "supersecretkey_change_this_in_production"
    ALGORITHM = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES = 120
    ENCRYPTION_KEY = b'supersecretencryptionkey12345678' # Must be 32 url-safe base64-encoded bytes in real usage
    
    # Email Configuration for MFA OTP
    SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
    SMTP_USER = os.getenv("SMTP_USER", "")  # Your Gmail address
    SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")  # Gmail App Password
    SMTP_FROM_NAME = os.getenv("SMTP_FROM_NAME", "SecureStorage IPDS")
    SMTP_SENDER = os.getenv("SMTP_USER", "") # Primary sender email
    
    # MFA OTP Settings
    MFA_OTP_LENGTH = 6
    MFA_OTP_EXPIRE_MINUTES = 2

settings = Settings()
