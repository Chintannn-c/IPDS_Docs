
import requests
import time

BASE_URL = "http://localhost:8026/auth"
LOGIN_URL = f"{BASE_URL}/login"
LOGOUT_URL = f"{BASE_URL}/logout"
REGISTER_URL = f"{BASE_URL}/register"
EMAIL = f"strict_lock_{int(time.time())}@example.com"
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
    print("=== Verifying Strict Single-Device Lock ===\n")
    
    # 0. Register
    print("0. Registering test user...")
    requests.post(REGISTER_URL, json={
        "email": EMAIL,
        "password": PASSWORD,
        "name": "Strict User"
    })
    
    # 1. Login Device A
    print("\n1. Login Device A (Should Success & Lock)...")
    fp_a = "device_A_fingerprint"
    headers_a = {"X-Device-Fingerprint": fp_a, "X-Device-Name": "Device A"}
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_a)
    
    if resp.status_code != 200:
        log_fail(f"Device A Login Failed: {resp.text}")
        return
    token_a = resp.json().get("access_token")
    log_success("Device A Logged In & Locked")

    # 2. Login Device B (Should be BLOCKED)
    print("\n2. Login Device B (Should be BLOCKED)...")
    fp_b = "device_B_fingerprint"
    headers_b = {"X-Device-Fingerprint": fp_b, "X-Device-Name": "Device B"}
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_b)
    
    if resp.status_code == 403:
        log_success(f"Device B Blocked as expected: {resp.json().get('detail')}")
    else:
        log_fail(f"Device B NOT Blocked! Status: {resp.status_code}, Resp: {resp.text}")
        return

    # 3. Logout Device A (Should Unlock)
    print("\n3. Logout Device A (Should Unlock)...")
    headers_logout_a = {"Authorization": f"Bearer {token_a}", "X-Device-Fingerprint": fp_a}
    resp = requests.post(LOGOUT_URL, headers=headers_logout_a)
    
    if resp.status_code == 200:
        log_success("Device A Logged Out")
    else:
        log_fail(f"Device A Logout Failed: {resp.text}")
        return

    # 4. Login Device B (Should Success now)
    print("\n4. Login Device B (Should Success)...")
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_b)
    
    if resp.status_code == 200:
        log_success("Device B Logged In (Lock Acquired)")
    else:
        log_fail(f"Device B Failed to Login after Unlock: {resp.text}")
        return

    log_success("ALL CHECKS PASSED")

if __name__ == "__main__":
    main()
