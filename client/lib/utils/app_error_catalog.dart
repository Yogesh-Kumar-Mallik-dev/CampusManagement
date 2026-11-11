class AppErrorItem {
  final String code;
  final String title;
  final String userMessage;
  final String technicalReason;
  final String resolutionSteps;

  const AppErrorItem({
    required this.code,
    required this.title,
    required this.userMessage,
    required this.technicalReason,
    required this.resolutionSteps,
  });

  String get displayString => '$userMessage (Ref: $code)';

  @override
  String toString() => displayString;
}

class AppErrorCatalog {
  // ---------------------------------------------------------------------------
  // CAMERA & OPTICAL ATTENDANCE (CAM & OPT)
  // ---------------------------------------------------------------------------
  static const cameraNotFound = AppErrorItem(
    code: 'CPOS-CAM-101',
    title: 'Camera Not Detected',
    userMessage: 'We could not detect a connected camera. Please make sure your webcam is plugged in or enabled.',
    technicalReason: 'No video capture device found at /dev/video0 or platform video descriptor list is empty.',
    resolutionSteps: 'Verify hardware connection, enable webcam switch/shutter, check v4l2 device nodes or permissions.',
  );

  static const cameraInUse = AppErrorItem(
    code: 'CPOS-CAM-102',
    title: 'Camera In Use',
    userMessage: 'Your camera is currently being used by another application. Please close other video tools and try again.',
    technicalReason: 'V4L2 or AVFoundation device descriptor is locked exclusively by another OS process.',
    resolutionSteps: 'Close background video conferencing applications, browser tabs using webcam, or release /dev/video0 lock.',
  );

  static const cameraPermissionDenied = AppErrorItem(
    code: 'CPOS-CAM-103',
    title: 'Camera Permission Needed',
    userMessage: 'Camera access is turned off. Please allow camera access in your system settings to scan attendance.',
    technicalReason: 'User or OS policy denied camera permission (AVFoundation, Android Manifest, or Web mediaDevices).',
    resolutionSteps: 'Open system or browser privacy settings, locate Campus Management, and switch Camera permission to Allow.',
  );

  static const cameraStreamInterrupted = AppErrorItem(
    code: 'CPOS-CAM-104',
    title: 'Camera Feed Interrupted',
    userMessage: 'The camera feed paused unexpectedly. Please refresh or reopen the scanner.',
    technicalReason: 'Incoming MJPEG video stream desynced, sub-process terminated, or frame buffer corrupted.',
    resolutionSteps: 'Reopen the camera scanner tab or inspect device hardware stability.',
  );

  static const opticalUnrecognized = AppErrorItem(
    code: 'CPOS-OPT-201',
    title: 'Code Out of Alignment',
    userMessage: 'Please align your camera reticle steadily with the rolling QR code on the lecture display.',
    technicalReason: 'Scanned frame does not conform to CPOS:OPT rolling frame payload grammar or has missing checksum.',
    resolutionSteps: 'Hold device steadily, focus on projector screen, eliminate screen glare, and keep QR centered in green reticle.',
  );

  static const opticalExpired = AppErrorItem(
    code: 'CPOS-OPT-202',
    title: 'Attendance Code Refreshed',
    userMessage: 'The classroom QR code just updated. Please hold steady and scan the active display code.',
    technicalReason: 'Captured optical token timestamp exceeds the 6-second rolling validity window.',
    resolutionSteps: 'Scan directly from the active live classroom broadcast instead of previously saved frames.',
  );

  static const opticalSessionClosed = AppErrorItem(
    code: 'CPOS-OPT-203',
    title: 'Session Concluded',
    userMessage: 'This lecture attendance broadcast has been finalized by the instructor.',
    technicalReason: 'Optical session marked ended in active sessions table or session ID does not match active class.',
    resolutionSteps: 'Confirm with your faculty instructor that the optical attendance broadcast is actively running.',
  );

  static const opticalVerificationFailed = AppErrorItem(
    code: 'CPOS-OPT-204',
    title: 'Verification Incomplete',
    userMessage: 'We could not complete your attendance check right now. Please scan once more.',
    technicalReason: 'HMAC signature verification failed or attendance ledger write rejected.',
    resolutionSteps: 'Scan a freshly generated optical frame from the instructor display.',
  );

  // ---------------------------------------------------------------------------
  // AUTHENTICATION & IDENTITY (AUTH)
  // ---------------------------------------------------------------------------
  static const authCredentialsMismatch = AppErrorItem(
    code: 'CPOS-AUTH-101',
    title: 'Incorrect Credentials',
    userMessage: 'The campus handle or password entered does not match our records. Please verify and try again.',
    technicalReason: 'Password hash check failed or user identity handle was not found in directory.',
    resolutionSteps: 'Confirm student/faculty ID format, check Caps Lock, or contact campus IT helpdesk for password reset.',
  );

  static const authAccountSuspended = AppErrorItem(
    code: 'CPOS-AUTH-102',
    title: 'Account Inactive',
    userMessage: 'Your campus portal account is currently inactive. Please check in with the registrar office.',
    technicalReason: 'User record has active=false or suspended disciplinary hold flag.',
    resolutionSteps: 'Contact student affairs or registrar desk to verify enrollment and clearance status.',
  );

  static const authSessionExpired = AppErrorItem(
    code: 'CPOS-AUTH-103',
    title: 'Session Ended',
    userMessage: 'Your portal session has ended. Please log in again to continue safely.',
    technicalReason: 'JWT access token expired or refresh handshake rejected.',
    resolutionSteps: 'Log back in through the sign-in screen to renew your secure session.',
  );

  static const authPermissionDenied = AppErrorItem(
    code: 'CPOS-AUTH-104',
    title: 'Access Restricted',
    userMessage: 'You do not have administrative permission to access this campus portal feature.',
    technicalReason: 'User role does not possess the requisite RBAC permission scope for this action.',
    resolutionSteps: 'Ensure you are signed in with the correct authorized institutional role.',
  );

  // ---------------------------------------------------------------------------
  // NETWORK & CONNECTIVITY (NET)
  // ---------------------------------------------------------------------------
  static const networkOffline = AppErrorItem(
    code: 'CPOS-NET-301',
    title: 'Offline Mode Active',
    userMessage: 'You are currently working offline. Offline changes will automatically sync once reconnected.',
    technicalReason: 'No network route to backend host; SocketException or network interface down.',
    resolutionSteps: 'Check Wi-Fi or mobile data connection. Saved offline records remain safe in local vault.',
  );

  static const networkTimeout = AppErrorItem(
    code: 'CPOS-NET-302',
    title: 'Connection Timed Out',
    userMessage: 'The campus server took longer than expected to reply. Please try your request again.',
    technicalReason: 'HTTP roundtrip exceeded client timeout deadline.',
    resolutionSteps: 'Check network bandwidth or latency and retry the action.',
  );

  static const serverMaintenance = AppErrorItem(
    code: 'CPOS-NET-303',
    title: 'Service Temporarily Busy',
    userMessage: 'The campus service is temporarily busy. Please try again in a few moments.',
    technicalReason: 'HTTP 502/503/504 gateway response from campus backend cluster.',
    resolutionSteps: 'Wait a moment for backend service auto-recovery or check campus system status.',
  );

  static const syncInterrupted = AppErrorItem(
    code: 'CPOS-NET-304',
    title: 'Sync Paused',
    userMessage: 'Data sync paused momentarily. Your local changes are intact and will resume shortly.',
    technicalReason: 'Offline journal replay encountered temporary transaction conflict or dropped packet.',
    resolutionSteps: 'Trigger manual sync button or re-open the screen once connection stabilizes.',
  );

  // ---------------------------------------------------------------------------
  // FEES & PAYMENTS (FEE)
  // ---------------------------------------------------------------------------
  static const feeInvoiceQueryFailed = AppErrorItem(
    code: 'CPOS-FEE-401',
    title: 'Invoice Notice',
    userMessage: 'Unable to refresh the invoice ledger at this moment. Showing cached records.',
    technicalReason: 'Fee ledger query endpoint returned non-200 or parsing error.',
    resolutionSteps: 'Inspect local offline fee cache or refresh after checking internet connection.',
  );

  static const feePaymentFailed = AppErrorItem(
    code: 'CPOS-FEE-402',
    title: 'Payment Incomplete',
    userMessage: 'Your transaction could not be finished by the payment provider. Please try another channel.',
    technicalReason: 'Payment gateway rejected charge attempt, bank declined, or timeout occurred.',
    resolutionSteps: 'Verify card/UPI limits, ensure bank server is responsive, or choose alternate payment mode.',
  );

  static const feeChallanFailed = AppErrorItem(
    code: 'CPOS-FEE-403',
    title: 'Challan Unavailable',
    userMessage: 'Unable to generate your offline payment challan right now. Please try again in a few moments.',
    technicalReason: 'VAN virtual account generator failed to allocate unique bank clearing sequence.',
    resolutionSteps: 'Retry challan generation or pay via direct UPI/NetBanking online channel.',
  );

  static const feeReceiptDownloadFailed = AppErrorItem(
    code: 'CPOS-FEE-404',
    title: 'Receipt Notice',
    userMessage: 'Unable to download your receipt PDF to storage right now. Please check file permissions.',
    technicalReason: 'FilePicker or local filesystem write operation failed or was cancelled.',
    resolutionSteps: 'Ensure download directory permissions are granted or select an alternate save location.',
  );

  // ---------------------------------------------------------------------------
  // LIBRARY & LOANS (LIB)
  // ---------------------------------------------------------------------------
  static const libQuotaExceeded = AppErrorItem(
    code: 'CPOS-LIB-501',
    title: 'Borrowing Quota Reached',
    userMessage: 'You have reached the maximum active book loans allowed by campus library policy.',
    technicalReason: 'Active loan count for student user has reached the institutional limit of 3 volumes.',
    resolutionSteps: 'Return an existing physical book before borrowing additional catalog volumes.',
  );

  static const libBookUnavailable = AppErrorItem(
    code: 'CPOS-LIB-502',
    title: 'Copies Checked Out',
    userMessage: 'All physical copies of this title are currently on loan to other campus scholars.',
    technicalReason: 'Book inventory available copies count equals 0.',
    resolutionSteps: 'Check back after scheduled return dates or access digital e-book version if available.',
  );

  static const libUploadFailed = AppErrorItem(
    code: 'CPOS-LIB-503',
    title: 'PDF Upload Incomplete',
    userMessage: 'We could not upload your PDF document. Please ensure it is a valid PDF under 50 MB.',
    technicalReason: 'PDF book binary upload failed format check, exceeded size threshold, or was interrupted.',
    resolutionSteps: 'Verify the document is an uncorrupted PDF format and within size constraints.',
  );

  static const libApprovalPending = AppErrorItem(
    code: 'CPOS-LIB-504',
    title: 'Authorization Required',
    userMessage: 'This book action requires counter verification from the Library In-Charge.',
    technicalReason: 'Workflow state is awaiting librarian authorization.',
    resolutionSteps: 'Present your physical pass or book at the circulation desk for counter clearance.',
  );

  // ---------------------------------------------------------------------------
  // ACADEMICS & EXAMINATIONS (ACAD & EXAM)
  // ---------------------------------------------------------------------------
  static const acadGradingLocked = AppErrorItem(
    code: 'CPOS-ACAD-601',
    title: 'Grading Period Closed',
    userMessage: 'Marks submission for this evaluation is closed following HOD approval.',
    technicalReason: 'Continuous Internal Evaluation marksheet has been frozen by department HOD.',
    resolutionSteps: 'Contact Department Head or Examination Controller for marksheet revision requests.',
  );

  static const acadScheduleConflict = AppErrorItem(
    code: 'CPOS-ACAD-602',
    title: 'Schedule Notice',
    userMessage: 'A timetable schedule overlap was detected for this section room or instructor.',
    technicalReason: 'Overlapping time slot detected on same weekday for instructor or classroom.',
    resolutionSteps: 'Adjust timetable slot hours or reassign to an alternate vacant classroom.',
  );

  static const acadDisputeClosed = AppErrorItem(
    code: 'CPOS-ACAD-603',
    title: 'Dispute Window Passed',
    userMessage: 'The formal review window for this examination result is no longer active.',
    technicalReason: 'Dispute filing deadline (typically 7 days post-result publication) has expired.',
    resolutionSteps: 'Consult your academic dean or examination controller for special re-evaluation requests.',
  );

  // ---------------------------------------------------------------------------
  // SYSTEM & GENERAL (SYS)
  // ---------------------------------------------------------------------------
  static const systemUnexpected = AppErrorItem(
    code: 'CPOS-SYS-901',
    title: 'Notice',
    userMessage: 'We encountered an unexpected application hiccup. Please try your action again.',
    technicalReason: 'Unhandled exception caught in presentation layer boundary.',
    resolutionSteps: 'Retry the operation or restart the client application if the issue persists.',
  );

  static const storageAccessRestricted = AppErrorItem(
    code: 'CPOS-SYS-902',
    title: 'Storage Restricted',
    userMessage: 'Could not access local device storage. Please check app file permissions.',
    technicalReason: 'Filesystem I/O exception or permission denied on local cache directory.',
    resolutionSteps: 'Verify storage permissions in operating system app settings.',
  );

  // ---------------------------------------------------------------------------
  // MASTER REGISTRY
  // ---------------------------------------------------------------------------
  static const List<AppErrorItem> allErrors = [
    cameraNotFound,
    cameraInUse,
    cameraPermissionDenied,
    cameraStreamInterrupted,
    opticalUnrecognized,
    opticalExpired,
    opticalSessionClosed,
    opticalVerificationFailed,
    authCredentialsMismatch,
    authAccountSuspended,
    authSessionExpired,
    authPermissionDenied,
    networkOffline,
    networkTimeout,
    serverMaintenance,
    syncInterrupted,
    feeInvoiceQueryFailed,
    feePaymentFailed,
    feeChallanFailed,
    feeReceiptDownloadFailed,
    libQuotaExceeded,
    libBookUnavailable,
    libUploadFailed,
    libApprovalPending,
    acadGradingLocked,
    acadScheduleConflict,
    acadDisputeClosed,
    systemUnexpected,
    storageAccessRestricted,
  ];

  static AppErrorItem findByCode(String code) {
    return allErrors.firstWhere(
      (e) => e.code.toUpperCase() == code.toUpperCase(),
      orElse: () => systemUnexpected,
    );
  }

  /// Translates raw exceptions into friendly, non-tech-savvy AppErrorItems with unique codes.
  static AppErrorItem resolveException(Object? error, {AppErrorItem defaultError = systemUnexpected}) {
    if (error == null) return defaultError;
    final msg = error.toString().toLowerCase();

    if (msg.contains('socketexception') || msg.contains('connection refused') || msg.contains('network is unreachable')) {
      return networkOffline;
    }
    if (msg.contains('timeoutexception') || msg.contains('timed out')) {
      return networkTimeout;
    }
    if (msg.contains('502') || msg.contains('503') || msg.contains('504')) {
      return serverMaintenance;
    }
    if (msg.contains('unauthorized') || msg.contains('401') || msg.contains('authentication failed')) {
      return authCredentialsMismatch;
    }
    if (msg.contains('forbidden') || msg.contains('403')) {
      return authPermissionDenied;
    }
    if (msg.contains('device or resource busy') || msg.contains('busy')) {
      return cameraInUse;
    }
    if (msg.contains('video0') || msg.contains('camera')) {
      return cameraNotFound;
    }
    if (msg.contains('permission') || msg.contains('denied')) {
      return storageAccessRestricted;
    }

    return defaultError;
  }

  /// Translates MobileScanner hardware error codes into polite user-facing messages.
  static AppErrorItem resolveMobileScannerError(String? errorCode) {
    final code = (errorCode ?? '').toLowerCase();
    if (code.contains('permission') || code.contains('denied')) {
      return cameraPermissionDenied;
    }
    if (code.contains('notfound') || code.contains('no_camera')) {
      return cameraNotFound;
    }
    if (code.contains('already_in_use') || code.contains('busy')) {
      return cameraInUse;
    }
    return cameraStreamInterrupted;
  }
}
