import requests
import uuid
import time

BASE_URL = "http://127.0.0.1:8000"

def run_test():
    # 1. Register a new user
    email = f"test_{uuid.uuid4()}@example.com"
    password = "password123"
    print(f"[*] Registering user: {email}")
    
    resp = requests.post(f"{BASE_URL}/auth/register", json={
        "email": email,
        "password": password,
        "name": "Test User"
    })
    if resp.status_code != 200:
        print(f"[!] Registration failed: {resp.text}")
        return

    # 2. Login (Device A)
    print("[*] Logging in with Device A...")
    headers_device_a = {
        "X-Device-ID": "device-a-id",
        "X-Device-Fingerprint": "device-a-fingerprint",
        "X-Device-Name": "Device A"
    }
    
    resp = requests.post(f"{BASE_URL}/auth/login", data={
        "username": email,
        "password": password
    }, headers=headers_device_a)
    
    if resp.status_code != 200:
        print(f"[!] Login failed: {resp.text}")
        return
        
    token_a = resp.json()["access_token"]
    print(f"[*] Login A Success. Token: {token_a[:10]}...")

    # 3. Block Device A
    print("[*] Blocking Device A...")
    headers_auth = {"Authorization": f"Bearer {token_a}"}
    
    # Need to verify if the block endpoint is accessible by the user (it seems it is)
    resp = requests.post(f"{BASE_URL}/auth/devices/toggle-block", json={
        "device_id": "device-a-id"
    }, headers=headers_auth)
    
    if resp.status_code != 200:
        # If the user can't block themselves (which is weird but possible), we might need another way or assume success if 200
        # The endpoint code I saw allows current_user to call it.
        # BUT, waiting... if I block myself, I revoke my own session immediately.
        # So the response might be interrupted or subsequent calls fail.
        print(f"[!] Block failed or session killed immediately: {resp.status_code} {resp.text}")
    else:
        print("[*] Block command sent successfully.")

    # 4. Verify Block Status (Use a fresh login/check or just try to login)
    # Trying to login again with Device A SHOULD FAIL
    print("[*] Attempting to login again with BLOCKED Device A...")
    
    resp = requests.post(f"{BASE_URL}/auth/login", data={
        "username": email,
        "password": password
    }, headers=headers_device_a)
    
    if resp.status_code == 200:
        print("[!!!] FAILURE: Login SUCCEEDED but should have been BLOCKED!")
        print(f"Response: {resp.json()}")
        
        # Check status
        # We need a new token to check status because the old one is revoked
        token_b = resp.json()["access_token"]
        headers_b = {"Authorization": f"Bearer {token_b}"}
        resp = requests.get(f"{BASE_URL}/auth/devices", headers=headers_b)
        devices = resp.json()
        target = next((d for d in devices if d["device_id"] == "device-a-id"), None)
        print(f"Device State after 2nd Login: Blocked={target.get('is_blocked')}, Trusted={target.get('is_trusted')}")
        
    elif resp.status_code == 403:
        print("[*] SUCCESS: Login was blocked with 403.")
        print(f"Response: {resp.json()}")
    else:
        print(f"[?] Unexpected response: {resp.status_code} {resp.text}")

if __name__ == "__main__":
    run_test()
