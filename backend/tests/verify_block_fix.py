
import requests
import json
import time

BASE_URL = "http://localhost:8000"
DEVICE_ID = "test_device_v2"
DEVICE_FINGERPRINT = "test_fingerprint_v2_123"
EMAIL = f"test_{int(time.time())}_v4@example.com"
PASSWORD = "TestPassword@123"

def run_test():
    session = requests.Session()
    
    # 1. Register/Login (Ensure user exists)
    register_data = {"email": EMAIL, "password": PASSWORD, "name": "Test User"}
    reg_resp = session.post(f"{BASE_URL}/auth/register", json=register_data)
    print(f"Registration Status: {reg_resp.status_code}")
    if reg_resp.status_code not in (200, 201):
         print(f"Registration Body: {reg_resp.text}")


    # 2. Login
    headers = {
        "X-Device-ID": DEVICE_ID,
        "X-Device-Fingerprint": DEVICE_FINGERPRINT,
        "X-Device-Name": "Test Device"
    }
    
    login_data = {
        "username": EMAIL,
        "password": PASSWORD
    }
    
    # Use x-www-form-urlencoded for OAuth2
    login_resp = session.post(f"{BASE_URL}/auth/login", data=login_data, headers=headers)
    
    if login_resp.status_code != 200:
        print(f"Login failed: {login_resp.text}")
        return
        
    token = login_resp.json()["access_token"]
    print("Logged in successfully.")
    
    auth_headers = {
        "Authorization": f"Bearer {token}",
        "X-Device-ID": DEVICE_ID,
        "X-Device-Fingerprint": DEVICE_FINGERPRINT
    }

    # 3. Block Device A (Performed by Admin/Device B)
    print("Blocking Device A from Device B...")
    headers_b = {
        "X-Device-ID": "device_b", # Admin/Blocker
        "X-Device-Fingerprint": "fingerprint_b",
        "X-Device-Name": "Admin Device"
    }
    # Login B first to get token
    login_resp_b = session.post(f"{BASE_URL}/auth/login", data=login_data, headers=headers_b)
    token_b = login_resp_b.json()["access_token"]
    auth_headers_b = {"Authorization": f"Bearer {token_b}", "X-Device-ID": "device_b"}

    block_resp = session.post(
        f"{BASE_URL}/auth/devices/toggle-block", 
        json={"device_id": DEVICE_ID},
        headers=auth_headers_b
    )
    
    if block_resp.status_code != 200:
        print(f"Block failed: {block_resp.text}")
        return
        
    print("Device blocked.")
    
    # 3b. Verify VISIBILITY (Crucial Step: Device must still be 'is_trusted=True')
    print("Verifying Locked Device Visibility...")
    # Fetch user details (simulating what the frontend does)
    user_resp = session.get(f"{BASE_URL}/auth/me", headers=auth_headers_b)
    if user_resp.status_code == 200:
        me_data = user_resp.json()
        trusted_devices = me_data.get("trusted_devices", [])
        
        target_device = next((d for d in trusted_devices if d.get("device_id") == DEVICE_ID), None)
        if target_device:
            is_blocked = target_device.get("is_blocked")
            is_trusted = target_device.get("is_trusted")
            print(f"Target Device Status: blocked={is_blocked}, trusted={is_trusted}")
            
            if is_blocked and is_trusted:
                print("SUCCESS: Device is Blocked AND Trusted (Visible).")
            else:
                print(f"FAILURE: device visibility wrong. Blocked: {is_blocked}, Trusted: {is_trusted}")
        else:
            print("FAILURE: Device completely disappeared from list!")
    else:
        print("Could not fetch profile to verify visibility.")
    
    # 4. Verify Access Denied
    print("Verifying access denied...")
    # Try to access protected route
    protected_resp = session.get(f"{BASE_URL}/auth/devices", headers=auth_headers)
    if protected_resp.status_code in (401, 403):
        print(f"Access correctly denied: {protected_resp.status_code}")
    else:
        print(f"FAILED: Access still allowed! {protected_resp.status_code}")
        
    # 5. Verify Login Denied
    print("Verifying login denied...")
    login_resp_2 = session.post(f"{BASE_URL}/auth/login", data=login_data, headers=headers)
    if login_resp_2.status_code == 403:
        print("Login correctly denied (403 Device Blocked)")
    else:
        print(f"FAILED: Login allowed during block! {login_resp_2.status_code}")
        
    # 6. Unblock Device (Using same session/headers might fail if token revoked? 
    # Actually, toggle-block usually requires a valid token from *another* device or session.
    # But for test simplicity, if we self-blocked, our token is revoked.
    # We need to simulate an admin unblock or just assume we can unblock if we hack it, 
    # BUT in reality, a user would use a DIFFERENT device to unblock.
    # Let's try to unblock using the SAME token (which should be revoked) to prove revocation works.
    
    unblock_resp_fail = session.post(
        f"{BASE_URL}/auth/devices/toggle-block", 
        json={"device_id": DEVICE_ID},
        headers=auth_headers
    )
    if unblock_resp_fail.status_code == 401:
        print("Correct: Cannot unblock with revoked token.")
    else:
        print(f"Warning: Able to use revoked token? {unblock_resp_fail.status_code}")

    # We need to login as 'admin' or just re-login if possible (but we are blocked).
    # In a real scenario, use another device. Here, we'll cheat and assume we can login from "Device B"
    print("Logging in from Device B to unblock...")
    headers_b = {
        "X-Device-ID": "device_b",
        "X-Device-Fingerprint": "fingerprint_b",
        "X-Device-Name": "Admin Device"
    }
    login_resp_b = session.post(f"{BASE_URL}/auth/login", data=login_data, headers=headers_b)
    token_b = login_resp_b.json()["access_token"]
    auth_headers_b = {"Authorization": f"Bearer {token_b}"}
    
    print("Unblocking Device A from Device B...")
    unblock_resp = session.post(
        f"{BASE_URL}/auth/devices/toggle-block", 
        json={"device_id": DEVICE_ID},
        headers=auth_headers_b
    )
    
    if unblock_resp.status_code == 200:
        print("Unblock successful.")
    else:
        print(f"Unblock failed: {unblock_resp.text}")
        return

    # 7. Verify Login Allowed Again
    print("Verifying Device A can login again...")
    login_resp_3 = session.post(f"{BASE_URL}/auth/login", data=login_data, headers=headers)
    if login_resp_3.status_code == 200:
        print("SUCCESS: Device A can login again after unblock!")
    else:
        print(f"FAILED: Device A still cannot login! {login_resp_3.status_code} - {login_resp_3.text}")

if __name__ == "__main__":
    run_test()
