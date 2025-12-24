
import requests
import time

BASE_URL = "http://localhost:8000/auth"
LOGIN_URL = f"{BASE_URL}/login"
LOGOUT_URL = f"{BASE_URL}/logout"
REGISTER_URL = f"{BASE_URL}/register"
BLOCK_URL = f"{BASE_URL}/devices/toggle-block"
REMOVE_URL = f"{BASE_URL}/devices/remove"

EMAIL = f"multidevice_{int(time.time())}@example.com"
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
    print("=== Verifying Multi-Device Management ===\n")
    
    # 0. Register
    print("0. Registering test user...")
    requests.post(REGISTER_URL, json={
        "email": EMAIL,
        "password": PASSWORD,
        "name": "Multi User"
    })
    
    # 1. Login Device A
    print("\n1. Login Device A...")
    fp_a = "device_A_fingerprint"
    headers_a = {"X-Device-Fingerprint": fp_a, "X-Device-Name": "Device A"}
    resp_a = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_a)
    
    if resp_a.status_code != 200:
        log_fail(f"Device A Login Failed: {resp_a.text}")
        return
    token_a = resp_a.json().get("access_token")
    log_success("Device A Logged In")

    # 2. Login Device B (Should ALSO Success - No blocking)
    print("\n2. Login Device B (Should SUCCEED)...")
    fp_b = "device_B_fingerprint"
    headers_b = {"X-Device-Fingerprint": fp_b, "X-Device-Name": "Device B"}
    resp_b = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_b)
    
    if resp_b.status_code == 200:
        log_success("Device B Logged In (Multi-Device Active)")
    else:
        log_fail(f"Device B Blocked unexpectedly! Status: {resp_b.status_code}, Resp: {resp_b.text}")
        return
    token_b = resp_b.json().get("access_token")

    # 3. Block Device B (Using Device A's token)
    print("\n3. Block Device B (Using Device A session)...")
    # First get device ID of B (via /auth/devices) or just assume format if generated in login
    # Let's fetch devices
    devices_resp = requests.get(f"{BASE_URL}/devices", headers={"Authorization": f"Bearer {token_a}"})
    devices = devices_resp.json()
    print(f"DEBUG: Devices Found: {devices}")
    
    device_b_id = next((d.get('device_id') for d in devices if d.get('fingerprint') == fp_b or d.get('device_id') == fp_b), None)
    
    if not device_b_id:
        log_fail(f"Could not find Device B ({fp_b}) in trusted list")
        print(f"DEBUG: Looking for fingerprint: {fp_b}")
        return
        
    print(f"   Blocking Device ID: {device_b_id}")
    block_resp = requests.post(BLOCK_URL, json={"device_id": device_b_id}, headers={"Authorization": f"Bearer {token_a}"})
    
    if block_resp.status_code == 200:
        log_success("Device B Blocked via API")
    else:
        log_fail(f"Block Failed: {block_resp.text}")
        return

    # 4. Try Login Device B again (Should FAIL - 403)
    print("\n4. Login Device B again (Should FAIL)...")
    resp_b_retry = requests.post(LOGIN_URL, data={"username": EMAIL, "password": PASSWORD}, headers=headers_b)
    
    if resp_b_retry.status_code == 403:
        log_success("Device B Blocked from Login (Correct)")
    else:
        log_fail(f"Device B Login Succeeded (Should be blocked)! Status: {resp_b_retry.status_code}")
        return

    # 5. Remove Device A (Using Device B token... oh wait B is blocked. Using A to remove A? Or new Device C?)
    # Let's use Device A to Remove Device A (Self-logout/Remove)
    print("\n5. Remove Device A (Self-removal)...")
    device_a_id = next((d['device_id'] for d in devices if d.get('fingerprint') == fp_a), None)
    remove_resp = requests.post(REMOVE_URL, json={"device_id": device_a_id}, headers={"Authorization": f"Bearer {token_a}"})
    
    if remove_resp.status_code == 200:
        log_success("Device A Removed via API")
    else:
        log_fail(f"Remove Failed: {remove_resp.text}")
        return

    log_success("ALL CHECKS PASSED")

if __name__ == "__main__":
    main()
