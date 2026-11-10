# CampusManagement Client (`campus_client`)

Multiplatform client for the CampusManagement Operating System built with **Flutter 3.x** and **Material 3**.

---

## Supported Platforms

- **Desktop**: Linux (GTK 3), macOS, Windows
- **Mobile**: Android, iOS
- **Web**: Progressive Web Application (PWA / CanvasKit / HTML renderer)

---

## Core Client Architecture

- **UI / Design System**:
  - Institutional Wine Red (`#7A1C30`) and GitHub Green (`#238636`) palette.
  - Smooth animated 60fps/120fps theme transitions between light and dark modes.
  - High-definition SVG icons via vector rasterization (`AppSvgIcon`).
  - Desktop-grade dropdowns (`AppDropdown<T>`) strictly opening underneath trigger anchors.
  - Standardized lighter placeholder/hint text styling (`AppColors.lightTextPlaceholder` & `AppColors.darkTextPlaceholder`).
  - Small screen responsiveness verified down to 360x640 with zero horizontal overflow.
- **State & Service Layer**:
  - Decoupled `ICampusFacade` domain orchestrator with dependency injection (`CampusDI`).
  - Resilient offline caching and request outbox (`OfflineStorageService`).
  - Online REST integration via `ApiService`.
- **Integrated Subsystems**:
  - **Optical Attendance**: Rapidly rolling QR podium broadcaster and student viewfinder scanner.
  - **Academic Timetable**: 9 AM to 5 PM consecutive block scheduling with conflict detection.
  - **Hostel & Dining Mess**: Room fixture management and weekly meal timetable with compulsory feedback.
  - **Institutional Fee Portal**: Invoices ledger, Razorpay/UPI mock gateway, and pure Dart PDF 1.4 invoice downloads.
  - **Institutional Fine Portal**: Penalty tracking, fine settlement, appeal submission, and administrator waivers.
  - **Institutional Library Subsystem**: Physical catalog with quota decrement, digital infinite e-books reader, and Library In-Charge Approvals counter for checkouts, renewals, and returns.
  - **Institutional Dispute System**: Contextual dispute modals for fees, fines, and exam marks leveraging complaints infrastructure.

---

## Running and Testing

From the repository root using relative lifecycle scripts:

```bash
# 1. Install dependencies
./script.sh deps

# 2. Run static analysis (zero warnings policy)
./script.sh check

# 3. Run client automated tests
./script.sh test

# 4. Launch Flutter client
./script.sh app run          # Linux Desktop
./script.sh app web          # Web (Chrome)

# 5. Compile production release bundles
./script.sh build
```

Technical architecture details and API references are documented in [`../docs/`](../docs/README.md).
