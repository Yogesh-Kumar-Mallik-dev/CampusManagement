# Institutional Payment Gateway Integration & Setup Guide

This document details the configuration, deployment, and rapid setup procedures for the Institutional Fee & Payment Gateway subsystem. The system is engineered to operate out-of-the-box in **Sandbox Simulation Mode** and can be flipped to live production gateways (**Razorpay**, **Cashfree**, or **PayU**) at a moment's notice simply by setting environment variables without code modification.

---

## 1. Architecture Overview

The payment engine employs a decoupled, multi-provider architecture:

```
[Flutter Client] 
   │
   ├─► 1. Request Public Config & Order (POST /api/v1/payments/order)
   │
[Go Backend Service]
   │
   ├─► Sandbox Simulator (Default)  ──► Auto-generates Dynamic UPI QR & VAN
   ├─► Razorpay Provider            ──► Order creation & HMAC-SHA256 verification
   ├─► Cashfree Provider            ──► Seamless PG checkout & Webhook capture
   └─► PayU Provider                ──► Salted hash verification
   │
   ├─► 2. Settle & Record (POST /api/v1/payments/verify or Webhook)
   │
[Institutional Fee Ledger]
   └─► Updates FeeInvoiceModel / FineRecordModel, reduces due balance, issues FeeReceipt
```

---

## 2. Instant Setup: Switching to Live Gateway in 60 Seconds

To switch from the default Sandbox Simulator to a live institutional merchant account, configure the following environment variables in your server environment (or systemd service / container environment):

### Option A: Live Razorpay Integration
```bash
export PAYMENT_GATEWAY_PROVIDER="razorpay"
export PAYMENT_GATEWAY_KEY_ID="rzp_live_xxxxxxxxxxxxxxxx"
export PAYMENT_GATEWAY_KEY_SECRET="your_razorpay_key_secret_here"
export PAYMENT_GATEWAY_WEBHOOK_SECRET="your_configured_webhook_secret"
export PAYMENT_MERCHANT_NAME="Kashi Institute of Technology Fee Collection"
export PAYMENT_MERCHANT_VPA="kitcampus@sbi"
export PAYMENT_BANK_NAME="State Bank of India (SBI)"
export PAYMENT_BANK_IFSC="SBIN0001234"
export PAYMENT_BANK_BRANCH="Campus Institutional Branch"
```

### Option B: Live Cashfree Integration
```bash
export PAYMENT_GATEWAY_PROVIDER="cashfree"
export PAYMENT_GATEWAY_KEY_ID="your_cashfree_app_id"
export PAYMENT_GATEWAY_KEY_SECRET="your_cashfree_secret_key"
export PAYMENT_GATEWAY_WEBHOOK_SECRET="your_cashfree_webhook_secret"
export PAYMENT_MERCHANT_NAME="Campus Academic & Collection Accounts"
export PAYMENT_MERCHANT_VPA="campustech@icici"
```

### Option C: Developer & Local Sandbox Mode (Default)
When no environment variables are set, the application automatically runs in `sandbox` mode:
```bash
PAYMENT_GATEWAY_PROVIDER="sandbox"
PAYMENT_GATEWAY_KEY_ID="sandbox_inst_key_campus_9901"
```
In sandbox mode:
- All four payment channels (UPI, Cards, NetBanking, Challan) operate with realistic test simulations.
- UPI generates dynamic QR codes with live countdown timers.
- Cards trigger authentic 3D Secure bank OTP modals (pre-filled test code: `123456`).
- Challan generates unique Virtual Account Numbers (VAN) for student NEFT/RTGS remittance.

---

## 3. Environment Variables Reference

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| `PAYMENT_GATEWAY_PROVIDER` | `sandbox` | Active payment provider: `sandbox`, `razorpay`, `cashfree`, or `payu`. |
| `PAYMENT_GATEWAY_KEY_ID` | `sandbox_inst_key_campus_9901` | Public API key / Client ID passed to frontend checkout clients. |
| `PAYMENT_GATEWAY_KEY_SECRET` | Auto-generated sandbox key | Private secret key used on backend to verify HMAC-SHA256 signatures. |
| `PAYMENT_GATEWAY_WEBHOOK_SECRET` | `whsec_campus_default_secret_99` | Secret for asynchronous server-to-server webhook authentication. |
| `PAYMENT_MERCHANT_NAME` | `Campus Academic & Technology Institute` | Legal entity name displayed on receipts, cards, and UPI apps. |
| `PAYMENT_MERCHANT_VPA` | `campuscollect@sbi` | Institutional UPI Virtual Payment Address (VPA) for remittances. |
| `PAYMENT_BANK_NAME` | `State Bank of India (SBI)` | Campus collection banker for institutional challans and RTGS. |
| `PAYMENT_BANK_IFSC` | `SBIN0001234` | IFSC Code for the institutional collection branch. |
| `PAYMENT_BANK_BRANCH` | `Institutional Campus Main Branch` | Physical bank branch details for challan slips. |

---

## 4. Multi-Channel Payment Capabilities

1. **Unified Payments Interface (UPI / QR)**:
   - Dynamic QR code generated with exact order amount and 15-minute countdown timer.
   - Compatible with Google Pay, PhonePe, Paytm, BHIM, and CRED.
   - UPI ID / VPA verification input with instant payment request trigger.

2. **Debit & Credit Cards (RuPay, Visa, MasterCard)**:
   - Interactive card preview with brand detector badge.
   - Form fields: 16-digit card number, Cardholder Name, Expiry (MM/YY), and 3-digit CVV.
   - 3D Secure / Bank OTP dialog (`dialog-3d-secure-otp`) with 256-bit institutional encryption banner.

3. **Net Banking**:
   - Quick-select tiles for major Indian banks: State Bank of India, HDFC Bank, ICICI Bank, Axis Bank, Punjab National Bank, Bank of Baroda.
   - Searchable selection for all scheduled commercial banks.

4. **Institutional Bank Challan / NEFT / RTGS**:
   - Unique Virtual Account Number (VAN) generated per student and fee transaction (e.g., `CAMPUS<STUDENT_ID_TAIL><TIMESTAMP_HASH>`).
   - One-click copy for Account Number and IFSC Code.
   - Offline Bank Reference / UTR Number submission (`input-utr-number`, `btn-submit-utr`) for manual ledger clearance.

---

## 5. Webhook Listener & Asynchronous Verification

Webhooks are routed to `POST /api/v1/payments/webhook`:
- In Razorpay mode, requests validate the `X-Razorpay-Signature` header via HMAC-SHA256:
  `HMAC_SHA256(raw_body, PAYMENT_GATEWAY_WEBHOOK_SECRET) == signature`
- When verified, the payment order is marked `paid`, dues are decremented, and the invoice status is updated to `partial` or `paid`.
- Webhook handling is strictly idempotent; duplicate webhooks do not issue duplicate credits.

---

## 6. Testing & Verification

Execute the test suites to verify payment gateway and UI compliance:

```bash
# Run backend tests
cd backend && go test -v ./internal/service ./internal/handler -run "TestPayment"

# Run client tests
cd client && flutter test test/widget_test.dart --name "Payment"

# Run full project checks
./scripts/check.sh
./scripts/test.sh
./scripts/build.sh
```
