class DeviceBlockedException(Exception):
    def __init__(self, detail: str, device_id: str, device_name: str):
        self.detail = detail
        self.device_id = device_id
        self.device_name = device_name

class UnauthorizedDeviceException(Exception):
    def __init__(self, detail: str, device_id: str, device_name: str):
        self.detail = detail
        self.device_id = device_id
        self.device_name = device_name
