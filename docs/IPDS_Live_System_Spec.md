# IPDS Live System Specification

## 1. Overview
This document outlines the technical specification for the "Intrusion Prevention & Detection System" (IPDS) Live Monitoring Dashboard. The system focuses on real-time visibility of file movements, user activities, and security threats within the file storage ecosystem.

---

## 2. Live Activity Stream

### Feature Explanation
A central feed displaying real-time actions occurring within the system. This acts as the "pulse" of the application, allowing operators to monitor user behavior and system events as they happen.

### Key Requirements
-   **Real-time Updates**: The stream must populate instantly without manual refreshing.
-   **Rich Context**: Each log entry must answer "Who, What, Where, When, and Status".
-   **Visual Indicators**: Color-coded status markers for quick assessment.

### Data Flow
1.  **Event Trigger**: User performs an action (e.g., Dashboard -> Upload File).
2.  **Backend Processing**: API processes the request and emits an event (e.g., `audit_log_created`) via WebSocket manager.
3.  **Frontend Consumption**: Flutter client receives the WebSocket message and prepends the new log entry to the `ActivityStream` list.

### UI/UX Elements
-   **Status Icons**:
    -   🟢 **Success**: Completed actions (Uploads, Logins).
    -   🔵 **Info**: Passive events (Viewed file, Navigation).
    -   🟠 **Warning**: Suspicious activity (MFA failed, Strange location).
    -   🔴 **Error/Critical**: Access denied, System errors.
-   **Action Types**: `Created`, `Forwarded`, `Approved`, `Commented`, `Closed`, `Deleted`.

---

## 3. File Movement Tracking System

### Feature Explanation
A dedicated tracking module for the lifecycle of a file. It enforces a strict state machine to visualizes exactly where a file is in its processing pipeline and identifies bottlenecks.

### Progression Stages
1.  **Initiated**: File uploaded/created by User A.
2.  **Verified**: Integrity check passed / Initial review by Supervisor.
3.  **Approved**: Final sign-off by Admin/Manager.
4.  **Closed**: Archival or final destination reached.

### Features
-   **Real-time Progress Bar**: Visual stepper showing specific stage completion.
-   **Time Tracking**:
    -   *Time-in-Stage*: How long the file has been stuck in the current step.
    -   *Total Lifecycle Time*: Time from 'Initiated' to 'Closed'.
-   **Stall Detection**: If a file remains in `Initiated` or `Verified` for > 24 hours, flag as "Delayed".

### Data Flow (State Machine)
-   `File` object has a `status` field.
-   `Transitions`:
    -   `initiate()` -> Sets status to `INITIATED`, timestamps `initiated_at`.
    -   `verify()` -> Sets status to `VERIFIED`, timestamps `verified_at`.
    -   `approve()` -> Sets status to `APPROVED`, timestamps `approved_at`.
    -   `close()` -> Sets status to `CLOSED`, timestamps `closed_at`.

---

## 4. Notification System

### Feature Explanation
A proactive alerting system to draw attention to critical events that require immediate intervention.

### Alert Categories
1. **High-Priority (Critical)**:
   - Security breaches (IPDS Alerts).
   - Failed MFA attempts (Multiple).
   - Unauthorized access attempts to restricted files.
2. **Delayed File Warnings (Warning)**:
   - File stuck in stage > Threshold time.
3. **System Events (Info/Error)**:
   - Backend disconnects.
   - Database latency spikes.

### Triggers & Rules
| Event Type | Condition | Notification Priority | Action |
| :--- | :--- | :--- | :--- |
| **MFA Failure** | > 3 failures in 5 min | **High** | Alert Admin + Lock User |
| **File Delay** | Status unchanged > 24h | **Medium** | Email Supervisor |
| **IPDS Threat** | Risk Score > 80 | **High** | Push Notification to All Admins |
| **New Upload** | File uploaded to restricted folder | **Low** | In-app Toast |

---

## 5. Search and Filters

### Feature Explanation
Tools for operators to slice and dice the massive influx of logs and file data to find specific incidents or trends.

### Filter Criteria
-   **File ID**: Exact match.
-   **User**: Dropdown/Autocomplete of system users.
-   **Department**: Filter by user tags/groups.
-   **Status**: `Success`, `Warning`, `Error`, `Blocked`.
-   **Date Range**: Start Date - End Date (with time).
-   **Privacy**: `Public`, `Redacted`, `Private`.
-   **Keyword**: Full-text search on Log Message.

### Implementation Logic
-   **Frontend**: Maintain local state for active filters.
-   **Real-time Interaction**:
    -   When filters are active, *incoming* real-time logs must be validated against filters before being added to the view.
    -   *Example*: If filtering for "User: John", a new log from "User: Sarah" is received via WS but ignored (not rendered).

---

## 6. Data Models (Examples)

### A. Activity Log (IPDS Log)
```json
{
  "log_id": "log_882391",
  "timestamp": "2025-12-08T16:05:00Z",
  "actor": {
    "user_id": "u_123",
    "name": "Alex Operator",
    "role": "Level 2 Admin",
    "ip_address": "192.168.1.45"
  },
  "action": "FILE_APPROVE",
  "target": {
    "type": "FILE",
    "id": "f_5592",
    "name": "Q4_Report.pdf"
  },
  "status": "SUCCESS",
  "metadata": {
    "previous_stage": "VERIFIED",
    "new_stage": "APPROVED",
    "time_taken_seconds": 3400
  }
}
```

### B. File Tracking Object
```json
{
  "file_id": "f_5592",
  "current_stage": "APPROVED",
  "stages": {
    "initiated": {
      "completed": true,
      "timestamp": "2025-12-08T10:00:00Z",
      "actor": "u_123"
    },
    "verified": {
      "completed": true,
      "timestamp": "2025-12-08T15:00:00Z",
      "actor": "u_456"
    },
    "approved": {
      "completed": true,
      "timestamp": "2025-12-08T16:05:00Z",
      "actor": "u_789"
    },
    "closed": {
      "completed": false,
      "timestamp": null
    }
  },
  "is_delayed": false,
  "sla_deadline": "2025-12-09T10:00:00Z"
}
```

---

## 7. Implementation Strategy: Real-Time Updates

### Hybrid Approach (Recommended)

1.  **WebSocket (Push)**:
    -   **Usage**: Instant notifications, appending new logs to the top of the stream, updating live progress bars.
    -   **Events**: `log.new`, `file.stage_changed`, `alert.critical`.

2.  **REST API (Pull)**:
    -   **Usage**: Initial data load, historical search, complex filtering, pagination.
    -   **Endpoint**: `GET /api/logs?page=1&limit=50&filter=...`

### Why Hybrid?
-   WebSockets are efficient for small, frequent updates but bad for fetching large datasets (history).
-   REST is robust for querying and filtering existing database records.

### Event Handling "Smart Update"
When a WebSocket event is received:
1.  Check if current view is "Live" mode (no historical date filters).
2.  If **Yes** -> Prepend data to list.
3.  If **No** (User is looking at last week's data) -> Show a "New events available" badge instead of auto-scrolling, to avoid disrupting the user's investigation.
