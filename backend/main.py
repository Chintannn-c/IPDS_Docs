from fastapi import FastAPI, Request, WebSocket, Query
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os

from app.api import auth, files, items, logs, ipds, live, notifications, test_notifications, summaries
from app.db.database import Database

# Import both IPDS versions - use V2 by default
from app.services.ipds_engine import IPDSMiddleware
try:
    from app.services.ipds_engine_v2 import IPDSMiddlewareV2
    IPDS_V2_AVAILABLE = True
except ImportError:
    IPDS_V2_AVAILABLE = False

from app.core.exceptions import DeviceBlockedException, UnauthorizedDeviceException
from app.websocket_manager import router as ws_router
  # ✅ Import WebSocket router

app = FastAPI(
    title="IPDS Docs API", 
    version="2.0.0",
    description="Intelligent Protection & Detection System with advanced security features"
)

# ------------------------------
# Exception Handlers
# ------------------------------
@app.exception_handler(DeviceBlockedException)
async def device_blocked_exception_handler(request: Request, exc: DeviceBlockedException):
    return JSONResponse(
        status_code=403,
        content={
            "detail": exc.detail,
            "device_id": exc.device_id,
            "device_name": exc.device_name,
            "error_type": "device_blocked"
        },
    )

@app.exception_handler(UnauthorizedDeviceException)
async def unauthorized_device_exception_handler(request: Request, exc: UnauthorizedDeviceException):
    return JSONResponse(
        status_code=401,
        content={
            "detail": exc.detail,
            "device_id": exc.device_id,
            "device_name": exc.device_name,
            "error_type": "unauthorized_device"
        },
    )

# ------------------------------
# Middleware
# ------------------------------
# IPDS Middleware (Intrusion Prevention & Detection)
# Use V2 if available and enabled, otherwise fall back to V1
USE_IPDS_V2 = os.environ.get("USE_IPDS_V2", "true").lower() == "true"

if USE_IPDS_V2 and IPDS_V2_AVAILABLE:
    print("🛡️ Using IPDS Middleware V2 (Enhanced Security)")
    app.add_middleware(IPDSMiddlewareV2)
else:
    print("🛡️ Using IPDS Middleware V1 (Standard)")
    app.add_middleware(IPDSMiddleware)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

# ------------------------------
# Database Events
# ------------------------------
@app.on_event("startup")
async def startup_db_client():
    Database.connect()

@app.on_event("shutdown")
async def shutdown_db_client():
    Database.close()

# ------------------------------
# Routers
# ------------------------------
app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(files.router, prefix="/files", tags=["Files"])
app.include_router(items.router, prefix="/items", tags=["Items"])
app.include_router(logs.router, prefix="/logs", tags=["Logs"])
app.include_router(ipds.router, prefix="/ipds", tags=["IPDS"])
app.include_router(live.router, prefix="/live", tags=["Live Monitor"])
app.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
app.include_router(test_notifications.router, prefix="/test", tags=["Test Notifications"])
app.include_router(summaries.router, prefix="/summaries", tags=["Summaries"])
app.include_router(ws_router, prefix="/ws", tags=["WebSocket"])

# ------------------------------
# Root Endpoint
# ------------------------------
@app.get("/")
async def root():
    return {"message": "IPDS Docs System Online"}

# ------------------------------
# Uvicorn Entry
# ------------------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8014, reload=True)

