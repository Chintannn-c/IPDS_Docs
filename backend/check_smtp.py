import os
from dotenv import load_dotenv

load_dotenv()

print("--- SMTP CONFIG CHECK ---")
print(f"SMTP_HOST: '{os.getenv('SMTP_HOST')}'")
print(f"SMTP_PORT: '{os.getenv('SMTP_PORT')}'")
print(f"SMTP_USER: '{os.getenv('SMTP_USER')}'")
print(f"SMTP_PASSWORD_SET: {bool(os.getenv('SMTP_PASSWORD'))}")
print(f"SMTP_FROM_NAME: '{os.getenv('SMTP_FROM_NAME')}'")
print("--- END CHECK ---")
