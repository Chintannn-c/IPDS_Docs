# app/core/email_utils.py

import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import random
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = int(os.getenv("SMTP_PORT", 587))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
SMTP_FROM_NAME = os.getenv("SMTP_FROM_NAME", "IPDS Docs")


def generate_otp(length: int = 6) -> str:
    """
    Generate a numeric OTP of given length.
    Default length is 6 digits.
    """
    return ''.join([str(random.randint(0, 9)) for _ in range(length)])


def send_otp_email(to_email: str, otp: str, purpose: str = "general") -> bool:
    """
    Send OTP to the user's email.
    Returns True if sent successfully, False otherwise.
    
    Args:
        to_email: Recipient email address
        otp: The one-time password to send
        purpose: The purpose of the OTP (enable_mfa, disable_mfa, login, general)
    """
    # ⚡ ALWAYS print OTP to console first (for debugging/testing)
    print("\n" + "="*60)
    print(f"🔐 OTP CODE FOR {purpose.upper()}")
    print(f"📧 Email: {to_email}")
    print(f"🔢 OTP: {otp}")
    print("="*60 + "\n")
    
    try:
        # Customize subject and body based on purpose
        if purpose == "enable_mfa":
            subject = "Enable Two-Factor Authentication - Verification Code"
            body = f"""Your verification code to enable Two-Factor Authentication is:

{otp}

This code is valid for 5 minutes.

If you did not request this, please ignore this email."""
        elif purpose == "disable_mfa":
            subject = "Disable Two-Factor Authentication - Verification Code"
            body = f"""Your verification code to disable Two-Factor Authentication is:

{otp}

This code is valid for 5 minutes.

If you did not request this, please ignore this email and your MFA will remain enabled."""
        elif purpose == "login":
            subject = "Login Verification Code"
            body = f"""Your login verification code is:

{otp}

This code is valid for 5 minutes.

If you did not attempt to log in, please change your password immediately."""
        elif purpose == "password_reset":
            subject = "Password Reset Code"
            body = f"""You have requested to reset your password.

Your password reset code is:

{otp}

This code is valid for 2 minutes.

If you did not request a password reset, please ignore this email and your password will remain unchanged."""
        else:
            subject = "Your One-Time Password (OTP)"
            body = f"Your OTP is: {otp}\n\nThis OTP is valid for a limited time."

        msg = MIMEMultipart()
        msg['From'] = f"{SMTP_FROM_NAME} <{SMTP_USER}>"
        msg['To'] = to_email
        msg['Subject'] = subject

        msg.attach(MIMEText(body, 'plain'))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)

        print(f"✅ [SUCCESS] OTP email sent to {to_email}")
        return True

    except Exception as e:
        print("\n" + "⚠️"*30)
        print(f"❌ [ERROR] Failed to send OTP email: {e}")
        print(f"📧 Email was supposed to go to: {to_email}")
        print(f"🔢 OTP CODE (use this): {otp}")
        print(f"💡 SMTP Config: Host={SMTP_HOST}, Port={SMTP_PORT}, User={SMTP_USER}")
        print("⚠️"*30 + "\n")
        return False


def send_security_alert_email(to_email: str, alert_message: str, change_password_url: str = None) -> bool:
    """
    Send security alert email to the user with instructions to change password.
    """
    # Note: Deep linking would require app setup - for now showing manual instructions
    
    try:
        subject = "⚠️ Security Alert: Suspicious Activity Detected"
        
        # Plain text version
        body_text = f"""Dear User,

{alert_message}

IMPORTANT: Please change your password immediately!

How to change your password:
1. Open the SecureStorage IPDS app on your device
2. Go to Profile (tap your profile icon)
3. Select "Change Password"
4. Enter your current password and create a new one

If you did not attempt to login, someone may be trying to access your account.

Best regards,
{SMTP_FROM_NAME} Team
"""

        # HTML version with instructions (mobile-friendly)
        html_body = f"""
<!DOCTYPE html>
<html>
<head>
    <style>
        body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; background: #f5f5f5; }}
        .container {{ max-width: 600px; margin: 20px auto; padding: 30px; background: white; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .header {{ text-align: center; padding-bottom: 20px; border-bottom: 2px solid #f44336; }}
        .alert-icon {{ font-size: 48px; }}
        .alert-box {{ 
            background: #ffebee; 
            border-left: 4px solid #f44336; 
            padding: 15px 20px; 
            margin: 20px 0; 
            border-radius: 4px;
        }}
        .steps-box {{
            background: #e3f2fd;
            border-left: 4px solid #2196F3;
            padding: 15px 20px;
            margin: 20px 0;
            border-radius: 4px;
        }}
        .step {{ margin: 8px 0; }}
        .step-number {{
            display: inline-block;
            width: 24px;
            height: 24px;
            background: #2196F3;
            color: white;
            border-radius: 50%;
            text-align: center;
            line-height: 24px;
            font-size: 12px;
            font-weight: bold;
            margin-right: 10px;
        }}
        .footer {{ color: #888; font-size: 12px; margin-top: 30px; text-align: center; padding-top: 20px; border-top: 1px solid #eee; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="alert-icon">🚨</div>
            <h2 style="color: #d32f2f; margin: 10px 0;">Security Alert</h2>
        </div>
        
        <p>Dear User,</p>
        
        <div class="alert-box">
            <strong>{alert_message}</strong>
        </div>

        <p style="color: #d32f2f; font-weight: bold;">⚠️ IMPORTANT: Please change your password immediately!</p>
        
        <div class="steps-box">
            <strong>How to change your password:</strong>
            <div class="step"><span class="step-number">1</span> Open the <strong>SecureStorage IPDS</strong> app</div>
            <div class="step"><span class="step-number">2</span> Tap your <strong>Profile</strong> icon</div>
            <div class="step"><span class="step-number">3</span> Select <strong>"Change Password"</strong></div>
            <div class="step"><span class="step-number">4</span> Enter your current password and create a new one</div>
        </div>
        
        <p style="color: #666; font-size: 14px;">
            If you did not attempt to login, someone may be trying to access your account. 
            Changing your password will log out all devices and secure your account.
        </p>
        
        <div class="footer">
            <p>Best regards,<br><strong>{SMTP_FROM_NAME} Team</strong></p>
            <p style="font-size: 11px;">If you did not request this email, please ignore it.</p>
        </div>
    </div>
</body>
</html>
"""

        msg = MIMEMultipart('alternative')
        msg['From'] = f"{SMTP_FROM_NAME} <{SMTP_USER}>"
        msg['To'] = to_email
        msg['Subject'] = subject

        # Attach both plain text and HTML
        msg.attach(MIMEText(body_text, 'plain'))
        msg.attach(MIMEText(html_body, 'html'))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)

        print(f"[DEBUG] Security alert with Change Password button sent to {to_email}")
        return True

    except Exception as e:
        print(f"[ERROR] Failed to send security alert email: {e}")
        return False

