# Institutional Error Catalog & Resolution Registry

This guide provides a comprehensive reference of all user-facing error codes implemented across the **Campus Operating System (CPOS)**. 

---

## 1. Error Handling Philosophy

CPOS enforces strict principles for all user-facing errors:
1. **Mild and Non-Intimidating**: Messages are written in polite, plain English. Raw technical exceptions, stack traces, HTTP status numbers, and internal subsystem jargon (e.g., `SocketException`, `v4l2_ioctl`, `JSON parse error`) are strictly intercepted and never exposed directly in the UI.
2. **Actionable Guidance**: Every message provides immediate, friendly advice on what the user should do next (e.g., checking alignment, verifying permissions, or trying an alternate channel).
3. **Unique Reference Code**: Every message includes a standardized institutional reference code (format: `CPOS-<SUBSYSTEM>-<NUMBER>`).
4. **Resolution Traceability**: Users can provide this reference code to Campus IT Helpdesk, where staff can look up the exact technical cause, diagnostic commands, and recovery procedures in this registry.

---

## 2. Error Code Index by Subsystem

| Prefix | Domain | Scope |
| :--- | :--- | :--- |
| **`CPOS-CAM`** | Camera & Video Streaming | Hardware detection, V4L2 device locks, OS privacy permissions, frame grabbers |
| **`CPOS-OPT`** | Optical Attendance | Ephemeral QR codes, HMAC signatures, 6-second rotation drift, anti-proxy rules |
| **`CPOS-AUTH`** | Authentication & IAM | Smart pass logins, account holds, token expiration, RBAC permissions |
| **`CPOS-NET`** | Network & Synchronization | Offline mode, timeouts, gateway health, outbox journal reconciliation |
| **`CPOS-FEE`** | Fees & Payment Gateway | Invoices, UPI/RuPay/NetBanking/Challan transactions, PDF receipt downloads |
| **`CPOS-LIB`** | Library & Circulation | Borrowing quotas, physical checkout approvals, PDF uploads, return deadlines |
| **`CPOS-ACAD`** | Academics & Sessional CIE | Evaluation marksheet freezes, timetable slot conflicts, formal exam disputes |
| **`CPOS-SYS`** | Core System & Vault | Local persistent database access, storage permissions, runtime boundaries |

---

## 3. Master Error Catalog & Resolution Registry

### 3.1 Camera & Video Streaming (`CPOS-CAM`)

#### `CPOS-CAM-101`: Camera Not Detected
- **Mild User Message**: `"We could not detect a connected camera. Please make sure your webcam is plugged in or enabled. (Ref: CPOS-CAM-101)"`
- **Technical Root Cause**: No video device node detected at `/dev/video0` or platform camera descriptor list is empty.
- **IT Support Resolution**:
  1. Verify physical hardware cable or laptop hardware privacy shutter.
  2. On Linux, run `v4l2-ctl --list-devices` or `ls -l /dev/video*`.
  3. Ensure user is a member of the `video` group: `sudo usermod -aG video $USER`.

#### `CPOS-CAM-102`: Camera In Use
- **Mild User Message**: `"Your camera is currently being used by another application. Please close other video tools and try again. (Ref: CPOS-CAM-102)"`
- **Technical Root Cause**: Video descriptor is locked by an existing process (`Device or resource busy`).
- **IT Support Resolution**:
  1. Identify the locking process: `fuser /dev/video0` or `lsof /dev/video0`.
  2. Terminate background video tools or browser tabs holding the camera lock.
  3. Re-open the attendance scanner.

#### `CPOS-CAM-103`: Camera Permission Needed
- **Mild User Message**: `"Camera access is turned off. Please allow camera access in your system settings to scan attendance. (Ref: CPOS-CAM-103)"`
- **Technical Root Cause**: Operating system or browser sandbox policy blocked camera access.
- **IT Support Resolution**:
  1. **Web**: Click the camera icon in the browser URL bar and set permission to *Allow*.
  2. **Android**: *Settings -> Apps -> Campus Client -> Permissions -> Camera -> Allow*.
  3. **iOS / macOS**: *Settings -> Privacy & Security -> Camera -> Campus Client -> Enabled*.

#### `CPOS-CAM-104`: Camera Feed Interrupted
- **Mild User Message**: `"The camera feed paused unexpectedly. Please refresh or reopen the scanner. (Ref: CPOS-CAM-104)"`
- **Technical Root Cause**: The underlying video frame pipeline desynchronized or was terminated by OS power saving.
- **IT Support Resolution**:
  1. Switch tabs to reload the viewfinder.
  2. Ensure USB power-saving mode is disabled on external USB webcams.

---

### 3.2 Optical Attendance Protocol (`CPOS-OPT`)

#### `CPOS-OPT-201`: Code Out of Alignment
- **Mild User Message**: `"Please align your camera reticle steadily with the rolling QR code on the lecture display. (Ref: CPOS-OPT-201)"`
- **Technical Root Cause**: Scanned frame does not match `CPOS:OPT:...` format or barcode decode failed checksum.
- **IT Support Resolution**:
  1. Steady the camera and center the green reticle on the projected classroom screen.
  2. Avoid sharp angles or screen glare from classroom fluorescent lights.

#### `CPOS-OPT-202`: Attendance Code Refreshed
- **Mild User Message**: `"The classroom QR code just updated. Please hold steady and scan the active display code. (Ref: CPOS-OPT-202)"`
- **Technical Root Cause**: Scanned optical frame timestamp is older than the 6-second validity window.
- **IT Support Resolution**:
  1. Optical QR frames refresh rapidly to prevent screenshot sharing and proxy attendance.
  2. Point device at the active live classroom projector and hold steady for 1-2 seconds.
  3. Verify device clock is synchronized with standard network time (NTP).

#### `CPOS-OPT-203`: Session Concluded
- **Mild User Message**: `"This lecture attendance broadcast has been finalized by the instructor. (Ref: CPOS-OPT-203)"`
- **Technical Root Cause**: Session ID marked concluded by faculty host.
- **IT Support Resolution**:
  1. Faculty has closed the attendance window for this slot.
  2. Consult instructor if late admission authorization is permitted.

#### `CPOS-OPT-204`: Verification Incomplete
- **Mild User Message**: `"We could not complete your attendance check right now. Please scan once more. (Ref: CPOS-OPT-204)"`
- **Technical Root Cause**: HMAC-SHA256 verification mismatch or ledger recording exception.
- **IT Support Resolution**:
  1. Scan a fresh live frame from the active lecture broadcast.
  2. Check Student Attendance Analytics to verify if attendance was already recorded.

---

### 3.3 Authentication & Identity Management (`CPOS-AUTH`)

#### `CPOS-AUTH-101`: Incorrect Credentials
- **Mild User Message**: `"The campus handle or password entered does not match our records. Please verify and try again. (Ref: CPOS-AUTH-101)"`
- **Technical Root Cause**: Password hash check failed or identity handle not found in directory.
- **IT Support Resolution**:
  1. Verify student/faculty canonical handle format (e.g. `2024.cs.042`).
  2. Verify Caps Lock state.
  3. Initiate institutional password reset through Campus IT Portal.

#### `CPOS-AUTH-102`: Account Inactive
- **Mild User Message**: `"Your campus portal account is currently inactive. Please check in with the registrar office. (Ref: CPOS-AUTH-102)"`
- **Technical Root Cause**: User entity flagged with `active=false` or pending disciplinary review.
- **IT Support Resolution**:
  1. Verify enrollment and fee clearance status in registrar ERP.
  2. Reactivate account record via Administration Portal once cleared.

#### `CPOS-AUTH-103`: Session Ended
- **Mild User Message**: `"Your portal session has ended. Please log in again to continue safely. (Ref: CPOS-AUTH-103)"`
- **Technical Root Cause**: JWT bearer token expired and refresh handshake failed.
- **IT Support Resolution**:
  1. Re-enter credentials on the login screen to issue a new secure session token.

#### `CPOS-AUTH-104`: Access Restricted
- **Mild User Message**: `"You do not have administrative permission to access this campus portal feature. (Ref: CPOS-AUTH-104)"`
- **Technical Root Cause**: User role lacks the required RBAC scope for this action.
- **IT Support Resolution**:
  1. Confirm user is logged in with appropriate faculty/administrator profile.
  2. Contact system administrator to adjust scoped role assignments.

---

### 3.4 Network & Data Synchronization (`CPOS-NET`)

#### `CPOS-NET-301`: Offline Mode Active
- **Mild User Message**: `"You are currently working offline. Offline changes will automatically sync once reconnected. (Ref: CPOS-NET-301)"`
- **Technical Root Cause**: No internet route to campus server (`SocketException` / TCP connection refused).
- **IT Support Resolution**:
  1. Campus client automatically operates in offline-first mode; all data is preserved locally.
  2. Connect to campus Wi-Fi or cellular network to resume automatic synchronization.

#### `CPOS-NET-302`: Connection Timed Out
- **Mild User Message**: `"The campus server took longer than expected to reply. Please try your request again. (Ref: CPOS-NET-302)"`
- **Technical Root Cause**: HTTP client roundtrip deadline exceeded timeout threshold (4000ms).
- **IT Support Resolution**:
  1. Tap retry to re-dispatch the request.
  2. Verify network latency on local campus subnet.

#### `CPOS-NET-303`: Service Temporarily Busy
- **Mild User Message**: `"The campus service is temporarily busy. Please try again in a few moments. (Ref: CPOS-NET-303)"`
- **Technical Root Cause**: Backend returned HTTP 502/503/504 gateway response.
- **IT Support Resolution**:
  1. Backend cluster is undergoing scheduled maintenance or handling peak load.
  2. Wait 30 seconds and refresh.

#### `CPOS-NET-304`: Sync Paused
- **Mild User Message**: `"Data sync paused momentarily. Your local changes are intact and will resume shortly. (Ref: CPOS-NET-304)"`
- **Technical Root Cause**: Outbox journal replay encountered temporary transaction conflict.
- **IT Support Resolution**:
  1. Local records remain safe in client SQLite vault.
  2. Trigger manual sync from dashboard or wait for automatic retry interval.

---

### 3.5 Fees & Payment Gateway (`CPOS-FEE`)

#### `CPOS-FEE-401`: Invoice Notice
- **Mild User Message**: `"Unable to refresh the invoice ledger at this moment. Showing cached records. (Ref: CPOS-FEE-401)"`
- **Technical Root Cause**: Fee ledger API query failed or returned format error.
- **IT Support Resolution**:
  1. Cached invoices are displayed from local storage.
  2. Pull to refresh when connected to campus network.

#### `CPOS-FEE-402`: Payment Incomplete
- **Mild User Message**: `"Your transaction could not be finished by the payment provider. Please try another channel. (Ref: CPOS-FEE-402)"`
- **Technical Root Cause**: Payment gateway authorization declined, OTP expired, or card limit reached.
- **IT Support Resolution**:
  1. Verify banking limits or OTP entry.
  2. Choose an alternative payment method (UPI QR, NetBanking, RuPay, or Offline Challan).

#### `CPOS-FEE-403`: Challan Unavailable
- **Mild User Message**: `"Unable to generate your offline payment challan right now. Please try again in a few moments. (Ref: CPOS-FEE-403)"`
- **Technical Root Cause**: Virtual Account Number (VAN) generator failed to allocate clearing sequence.
- **IT Support Resolution**:
  1. Retry challan generation in 1 minute.
  2. Pay fee online directly via instant UPI or NetBanking.

#### `CPOS-FEE-404`: Receipt Notice
- **Mild User Message**: `"Unable to download your receipt PDF to storage right now. Please check file permissions. (Ref: CPOS-FEE-404)"`
- **Technical Root Cause**: File download or storage write permission was denied by OS.
- **IT Support Resolution**:
  1. Allow file storage permissions for Campus Client in OS Settings.
  2. Choose a valid destination folder (e.g. `Downloads` or `Documents`).

---

### 3.6 Library & Circulation (`CPOS-LIB`)

#### `CPOS-LIB-501`: Borrowing Quota Reached
- **Mild User Message**: `"You have reached the maximum active book loans allowed by campus library policy. (Ref: CPOS-LIB-501)"`
- **Technical Root Cause**: Active book loan count has reached institutional ceiling (3 volumes).
- **IT Support Resolution**:
  1. Return an existing borrowed physical book at circulation counter before taking out a new volume.

#### `CPOS-LIB-502`: Copies Checked Out
- **Mild User Message**: `"All physical copies of this title are currently on loan to other campus scholars. (Ref: CPOS-LIB-502)"`
- **Technical Root Cause**: Available copies count in physical book inventory is 0.
- **IT Support Resolution**:
  1. Check earliest return date on book catalog card.
  2. Access the digital E-Book edition (unlimited concurrent borrowing).

#### `CPOS-LIB-503`: PDF Upload Incomplete
- **Mild User Message**: `"We could not upload your PDF document. Please ensure it is a valid PDF under 50 MB. (Ref: CPOS-LIB-503)"`
- **Technical Root Cause**: Uploaded file failed PDF magic byte check or exceeded 50 MB threshold.
- **IT Support Resolution**:
  1. Verify the file is an authentic, uncorrupted PDF.
  2. Compress file if size exceeds 50 MB.

#### `CPOS-LIB-504`: Authorization Required
- **Mild User Message**: `"This book action requires counter verification from the Library In-Charge. (Ref: CPOS-LIB-504)"`
- **Technical Root Cause**: Action requires physical verification by librarian.
- **IT Support Resolution**:
  1. Present physical book or Smart ID pass at library counter for clearance.

---

### 3.7 Academics & Examinations (`CPOS-ACAD`)

#### `CPOS-ACAD-601`: Grading Period Closed
- **Mild User Message**: `"Marks submission for this evaluation is closed following HOD approval. (Ref: CPOS-ACAD-601)"`
- **Technical Root Cause**: Continuous Internal Evaluation (CIE) marksheet frozen by Department Head.
- **IT Support Resolution**:
  1. Contact Department Head or Examination Controller for formal marksheet unfreezing approval.

#### `CPOS-ACAD-602`: Schedule Notice
- **Mild User Message**: `"A timetable schedule overlap was detected for this section room or instructor. (Ref: CPOS-ACAD-602)"`
- **Technical Root Cause**: Overlapping timetable slot detected for instructor or classroom on the same day.
- **IT Support Resolution**:
  1. Inspect Timetable grid for conflicting room/instructor allocations.
  2. Assign slot to an alternate unoccupied lecture hall.

#### `CPOS-ACAD-603`: Dispute Window Passed
- **Mild User Message**: `"The formal review window for this examination result is no longer active. (Ref: CPOS-ACAD-603)"`
- **Technical Root Cause**: Formal result dispute deadline (7 days post-publication) has expired.
- **IT Support Resolution**:
  1. Review university academic calendar.
  2. Submit special petition to Academic Dean if extenuating medical/emergency grounds exist.

---

### 3.8 Core System & Vault Storage (`CPOS-SYS`)

#### `CPOS-SYS-901`: Unexpected Application Notice
- **Mild User Message**: `"We encountered an unexpected application hiccup. Please try your action again. (Ref: CPOS-SYS-901)"`
- **Technical Root Cause**: Unhandled exception caught at presentation layer boundary.
- **IT Support Resolution**:
  1. Retry the action or navigate to dashboard and back.
  2. Report reference code to campus IT if recurrent.

#### `CPOS-SYS-902`: Storage Restricted
- **Mild User Message**: `"Could not access local device storage. Please check app file permissions. (Ref: CPOS-SYS-902)"`
- **Technical Root Cause**: Filesystem I/O exception or permission denied on local cache directory.
- **IT Support Resolution**:
  1. Ensure disk space is available on host machine.
  2. Verify storage read/write permissions in system application settings.
