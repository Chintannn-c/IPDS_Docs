
import time
import uuid
import requests

BASE_URL = "http://localhost:8013/auth"
LOGIN_URL = f"{BASE_URL}/login"
LOGOUT_URL = f"{BASE_URL}/logout"
EMAIL = f"strict_{int(time.time())}@example.com"
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
    print("=== Starting Strict Device Binding Verification ===\n")
    
    # 0. Register/Reset
    print("0. Registering test user...")
    requests.post(f"{BASE_URL}/register", json={
        "email": EMAIL,
        "password": PASSWORD,
        "name": "Strict User"
    })
    
    # 1. Login Device A (First Login - Should SUCCEED)
    print("\n1. Login Device A (Expect SUCCESS)...")
    headers_a = {"X-Device-Fingerprint": "dev_A_fingerprint", "X-Device-Name": "Device A"}
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_a)
    
    token_a = None
    if resp.status_code == 200:
        log_success("Device A Logged In")
        token_a = resp.json().get("access_token")
    else:
        log_fail(f"Device A Failed: {resp.text}")
        return

    # 2. Login Device B (Should SUCCEED and REPLACE A)
    print("\n2. Login Device B (Expect SUCCESS and REPLACE A)...")
    headers_b = {"X-Device-Fingerprint": "dev_B_fingerprint", "X-Device-Name": "Device B"}
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_b)
    
    if resp.status_code == 200:
        log_success("Device B Logged In (Auto-Replaced A)")
    else:
        log_fail(f"Device B should NOT be blocked: {resp.status_code}: {resp.text}")

    # 3. Login Device A Again (Relogin - Should SUCCEED)
    print("\n3. Login Device A Again (Expect SUCCESS - Relogin)...")
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_a)
    
    if resp.status_code == 200:
        log_success("Device A Relogin Success")
        token_a = resp.json().get("access_token") # Refresh token
    else:
        log_fail(f"Device A Relogin Failed: {resp.text}")

    # 4. Logout Device A
    print("\n4. Logout Device A...")
    # Provide the fingerprint in header for the new logout logic
    logout_headers = {"Authorization": f"Bearer {token_a}", "X-Device-Fingerprint": "dev_A_fingerprint"}
    resp = requests.post(LOGOUT_URL, headers=logout_headers)
    
    if resp.status_code == 200:
        log_success("Device A Logged Out")
    else:
        log_fail(f"Logout Failed: {resp.text}")

    # 5. Login Device B (New Session - Should SUCCEED now)
    print("\n5. Login Device B (Expect SUCCESS now)...")
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_b)
    
    if resp.status_code == 200:
        log_success("Device B Logged In Success")
    else:
        log_fail(f"Device B Failed (Should succeed after logout): {resp.text}")

    print("\n=== Verification Complete ===")

if __name__ == "__main__":
    main()
