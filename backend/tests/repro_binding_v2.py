
import requests
import time
import sys

BASE_URL = "http://localhost:8000/auth"
LOGIN_URL = f"{BASE_URL}/login"
LOGOUT_URL = f"{BASE_URL}/logout"
EMAIL = "test_user@example.com"
PASSWORD = "password123" 

# Color codes
GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"

def log_success(msg):
    print(f"{GREEN}[SUCCESS] {msg}{RESET}")

def log_fail(msg):
    print(f"{RED}[FAIL] {msg}{RESET}")

def main():
    print("=== Starting Device Binding Verification ===\n")

    # 0. Register User (Ignore if exists)
    print("0. Registering test user...")
    requests.post(f"{BASE_URL}/register", json={
        "email": EMAIL,
        "password": PASSWORD,
        "name": "Test User"
    })

    # 1. Login with Device A
    print("1. Logging in with Device A...")
    headers_a = {
        "X-Device-ID": "dev_A",
        "X-Device-Fingerprint": "fingerprint_A",
        "X-Device-Name": "Device A"
    }
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_a)
    
    if resp.status_code != 200:
        log_fail(f"Login failed: {resp.text}")
        return
        
    token_a = resp.json().get("access_token")
    log_success("Device A Logged In")

    # 2. Login with Device B (Should be BLOCKED)
    print("\n2. Attempting login with Device B (Should be blocked)...")
    headers_b = {
        "X-Device-ID": "dev_B",
        "X-Device-Fingerprint": "fingerprint_B",
        "X-Device-Name": "Device B"
    }
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_b)
    
    if resp.status_code == 403:
        log_success("Device B login blocked correctly (Device A is active)")
    else:
        log_fail(f"Device B should be blocked but got {resp.status_code}")

    # 3. Logout Device A (Safe Logout Test)
    print("\n3. Logging out Device A...")
    # NOTE: To test 'expired' token, we can just pass the valid one since the backend treats them same now.
    # To TRULY test expired, we'd need to mock the decoding or wait, but 'Safe Logout' logic applies to valid tokens too.
    # Checks if /logout returns 200 and unbinds.
    api_headers = {"Authorization": f"Bearer {token_a}"}
    resp = requests.post(LOGOUT_URL, headers=api_headers)
    
    if resp.status_code == 200:
        log_success("Logout successful (200 OK)")
    else:
        log_fail(f"Logout failed: {resp.status_code} {resp.text}")

    # 4. Login with Device B (Should SUCCEED now)
    print("\n4. Attempting login with Device B again (Should succeed)...")
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_b)
    
    if resp.status_code == 200:
        log_success("Device B Logged In successfully after Device A logout")
    else:
        log_fail(f"Device B failed to login: {resp.status_code} {resp.text}")

    print("\n=== Verification Complete ===")

if __name__ == "__main__":
    main()
