
import asyncio
import websockets
import requests
import json
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

BASE_URL = "http://localhost:8025/auth"
WS_URL = "ws://localhost:8025/ws/ipds/ws"

async def reproduction():
    import time
    email = f"repro_ws_{int(time.time())}@example.com"
    password = "password123"
    
    # 1. Register/Login
    logging.info(f"1. Registering {email}...")
    try:
        requests.post(f"{BASE_URL}/register", json={"email": email, "password": password, "name": "Repro User"})
    except:
        pass
        
    # Login Device A (Controller)
    resp_a = requests.post(f"{BASE_URL}/login", data={"username": email, "password": password}, headers={"X-Device-Fingerprint": "DEVICE_A_FP", "X-Device-Name": "Device A"})
    token_a = resp_a.json()["access_token"]
    user_id = resp_a.json().get("user", {}).get("id")
    logging.info(f"Device A logged in.")

    # Login Device B (Target)
    resp_b = requests.post(f"{BASE_URL}/login", data={"username": email, "password": password}, headers={"X-Device-Fingerprint": "DEVICE_B_FP", "X-Device-Name": "Device B"})
    token_b = resp_b.json()["access_token"]
    logging.info(f"Device B logged in.")
    
    # Get Device B ID
    devices = requests.get(f"{BASE_URL}/devices", headers={"Authorization": f"Bearer {token_a}"}).json()
    with open("repro_output.txt", "w") as f:
        f.write(json.dumps(devices, indent=2))
    
    logging.info(f"Devices List written to repro_output.txt")
    
    device_b = next((d for d in devices if d.get('fingerprint') == 'DEVICE_B_FP'), None)
    if not device_b:
        logging.error("Device B not found in list!")
        return
    device_b_id = device_b['device_id']
    logging.info(f"Device B ID: {device_b_id}")

    # 3. Connect Device B to WebSocket
    logging.info("Connecting Device B to WebSocket...")
    async with websockets.connect(f"{WS_URL}?token={token_b}") as websocket:
        # Read initial message
        init_msg = await websocket.recv()
        logging.info(f"Device B WS Connected: {init_msg}")
        
        # 4. Trigger Removal from Device A
        logging.info("Triggering removal of Device B from Device A...")
        remove_resp = requests.post(f"{BASE_URL}/devices/remove", json={"device_id": device_b_id}, headers={"Authorization": f"Bearer {token_a}"})
        logging.info(f"Remove response: {remove_resp.status_code} {remove_resp.text}")
        
        # 5. Wait for event
        logging.info("Waiting for device_removed event on Device B...")
        try:
            msg = await asyncio.wait_for(websocket.recv(), timeout=5.0)
            data = json.loads(msg)
            logging.info(f"Received WS Message: {data}")
            
            if data.get("type") == "device_removed":
                logging.info("SUCCESS: Received device_removed event!")
                logging.info(f"Target Fingerprint in Data: {data.get('data', {}).get('device_fingerprint')}")
            else:
                logging.error(f"FAIL: Received unexpected message type: {data.get('type')}")
                
        except asyncio.TimeoutError:
            logging.error("FAIL: Timeout waiting for WebSocket event")
            
if __name__ == "__main__":
    asyncio.get_event_loop().run_until_complete(reproduction())
