
import requests
import time

BASE_URL = "http://localhost:8016/auth"
LOGIN_URL = f"{BASE_URL}/login"
DEVICES_URL = f"{BASE_URL}/devices"
EMAIL = f"trusted_{int(time.time())}@example.com"
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
    print("=== Verifying Trusted Device Sync ===\n")
    
    # 0. Register
    print("0. Registering test user...")
    register_url = f"{BASE_URL}/register"
    requests.post(register_url, json={
        "email": EMAIL,
        "password": PASSWORD,
        "name": "Trusted User"
    })
    
    # 1. Login Device A
    print("\n1. Login Device A...")
    fingerprint = "dev_A_fingerprint_trusted"
    headers = {"X-Device-Fingerprint": fingerprint, "X-Device-Name": "Device A"}
    resp = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers)
    
    if resp.status_code != 200:
        log_fail(f"Login Failed: {resp.text}")
        return

    token = resp.json().get("access_token")
    log_success("Logged In")

    # 2. Get Trusted Devices
    print("\n2. Fetching Trusted Devices...")
    auth_headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(DEVICES_URL, headers=auth_headers)
    
    if resp.status_code != 200:
        log_fail(f"Get Devices Failed: {resp.text}")
        return
        
    devices = resp.json()
    print(f"Devices found: {len(devices)}")
    
    found = False
    for d in devices:
        # device_id might be set to fingerprint[:16] or exact fingerprint depending on logic
        # logic says: device_id=device_id or fingerprint[:16], and fingerprint=fingerprint
        if d.get("fingerprint") == fingerprint:
            found = True
            log_success(f"Found current device in trusted list: {d}")
            break
            
    if not found:
        log_fail(f"Current device {fingerprint} NOT found in trusted devices: {devices}")
    else:
        log_success("Verification PASSED")

if __name__ == "__main__":
    main()
