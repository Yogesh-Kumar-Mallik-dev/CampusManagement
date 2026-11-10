package service

import (
	"context"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"campus/backend/internal/model"
)

// PaymentService coordinates gateway orders, multi-provider verification, and fee reconciliation
type PaymentService struct {
	feeService FeeServiceInterface
	mu         sync.RWMutex
	orders     map[string]*model.PaymentOrder

	provider      string
	keyID         string
	keySecret     string
	webhookSecret string
	merchantName  string
	merchantVPA   string
	bankName      string
	bankIFSC      string
	bankBranch    string
}

// NewPaymentService constructs and initializes PaymentService from environment configurations
func NewPaymentService(feeService FeeServiceInterface) *PaymentService {
	provider := strings.ToLower(strings.TrimSpace(os.Getenv("PAYMENT_GATEWAY_PROVIDER")))
	if provider == "" {
		provider = model.GatewayProviderSandbox
	}

	keyID := strings.TrimSpace(os.Getenv("PAYMENT_GATEWAY_KEY_ID"))
	if keyID == "" {
		if provider == model.GatewayProviderRazorpay {
			keyID = "rzp_test_campus_mock_key"
		} else {
			keyID = "sandbox_inst_key_campus_9901"
		}
	}

	keySecret := strings.TrimSpace(os.Getenv("PAYMENT_GATEWAY_KEY_SECRET"))
	if keySecret == "" && provider == model.GatewayProviderSandbox {
		keySecret = "sandbox_secret_instituional_demo"
	}

	webhookSecret := strings.TrimSpace(os.Getenv("PAYMENT_GATEWAY_WEBHOOK_SECRET"))
	if webhookSecret == "" {
		webhookSecret = "whsec_campus_default_secret_99"
	}

	merchantName := strings.TrimSpace(os.Getenv("PAYMENT_MERCHANT_NAME"))
	if merchantName == "" {
		merchantName = "Babu Banarasi Das Institute of Technology & BBDIT College of Pharmacy"
	}

	merchantVPA := strings.TrimSpace(os.Getenv("PAYMENT_MERCHANT_VPA"))
	if merchantVPA == "" {
		merchantVPA = "bbditcollect@sbi"
	}

	bankName := strings.TrimSpace(os.Getenv("PAYMENT_BANK_NAME"))
	if bankName == "" {
		bankName = "State Bank of India (SBI)"
	}

	bankIFSC := strings.TrimSpace(os.Getenv("PAYMENT_BANK_IFSC"))
	if bankIFSC == "" {
		bankIFSC = "SBIN0001234"
	}

	bankBranch := strings.TrimSpace(os.Getenv("PAYMENT_BANK_BRANCH"))
	if bankBranch == "" {
		bankBranch = "Institutional Campus Main Branch"
	}

	svc := &PaymentService{
		feeService:    feeService,
		orders:        make(map[string]*model.PaymentOrder),
		provider:      provider,
		keyID:         keyID,
		keySecret:     keySecret,
		webhookSecret: webhookSecret,
		merchantName:  merchantName,
		merchantVPA:   merchantVPA,
		bankName:      bankName,
		bankIFSC:      bankIFSC,
		bankBranch:    bankBranch,
	}

	return svc
}

// GetPublicConfig returns checkout parameters for Flutter and web clients
func (s *PaymentService) GetPublicConfig(ctx context.Context) model.PaymentGatewayPublicConfig {
	s.mu.RLock()
	defer s.mu.RUnlock()

	env := "sandbox"
	if s.provider != model.GatewayProviderSandbox {
		env = "production"
	}

	return model.PaymentGatewayPublicConfig{
		Provider:     s.provider,
		KeyID:        s.keyID,
		MerchantName: s.merchantName,
		MerchantVPA:  s.merchantVPA,
		Environment:  env,
		SupportedMethods: []string{
			model.PaymentMethodUPI,
			model.PaymentMethodDebitCard,
			model.PaymentMethodCreditCard,
			model.PaymentMethodNetBanking,
			model.PaymentMethodChallan,
		},
		VirtualAccount: &model.VirtualAccount{
			BeneficiaryName: s.merchantName,
			BankName:        s.bankName,
			AccountNumber:   "CAMPUSCOLLECT01",
			IFSCCode:        s.bankIFSC,
			BranchName:      s.bankBranch,
			ReferenceVAN:    "CAMPUS-GENERIC-VAN",
		},
	}
}

// CreateOrder initiates a payment order for an invoice or fine
func (s *PaymentService) CreateOrder(ctx context.Context, req model.CreatePaymentOrderRequest) (*model.PaymentOrder, error) {
	if err := req.Validate(); err != nil {
		return nil, err
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now().UTC()
	var studentName string
	var title string

	// Validate entity exists
	if req.EntityType == "invoice" {
		inv, err := s.feeService.GetInvoiceByID(ctx, req.EntityID)
		if err != nil {
			return nil, fmt.Errorf("invoice not found: %w", err)
		}
		if req.Amount > inv.DueAmount {
			return nil, fmt.Errorf("order amount (%.2f) exceeds due balance (%.2f)", req.Amount, inv.DueAmount)
		}
		studentName = inv.StudentName
		title = inv.Title
	} else {
		fines, err := s.feeService.GetFines(ctx, req.StudentID, "")
		if err != nil {
			return nil, fmt.Errorf("error fetching fine: %w", err)
		}
		var found *model.FineRecord
		for _, f := range fines {
			if f.ID == req.EntityID {
				found = &f
				break
			}
		}
		if found == nil {
			return nil, fmt.Errorf("fine '%s' not found for student '%s'", req.EntityID, req.StudentID)
		}
		if found.Status == model.FineStatusPaid {
			return nil, errors.New("fine has already been settled")
		}
		studentName = found.StudentName
		title = "Institutional Fine Penalty: " + found.Category
	}

	// Generate secure identifiers
	randBytes := make([]byte, 8)
	_, _ = rand.Read(randBytes)
	orderID := fmt.Sprintf("order_campus_%d_%s", now.Unix(), hex.EncodeToString(randBytes[:4]))

	gatewayOrderID := orderID
	if s.provider == model.GatewayProviderRazorpay {
		gatewayOrderID = fmt.Sprintf("order_%s", hex.EncodeToString(randBytes))
	}

	// Build Virtual Account Number for NEFT/RTGS
	cleanStudent := strings.ReplaceAll(strings.ToUpper(req.StudentID), "-", "")
	if len(cleanStudent) > 8 {
		cleanStudent = cleanStudent[len(cleanStudent)-8:]
	}
	van := fmt.Sprintf("CAMPUS%s%d", cleanStudent, now.Unix()%10000)

	va := &model.VirtualAccount{
		BeneficiaryName: s.merchantName,
		BankName:        s.bankName,
		AccountNumber:   van,
		IFSCCode:        s.bankIFSC,
		BranchName:      s.bankBranch,
		ReferenceVAN:    van,
	}

	// Build standard UPI intent deep-link
	txnRef := fmt.Sprintf("CAMPUS-%d", now.UnixNano()%100000000)
	upiQuery := url.Values{}
	upiQuery.Set("pa", s.merchantVPA)
	upiQuery.Set("pn", s.merchantName)
	upiQuery.Set("am", fmt.Sprintf("%.2f", req.Amount))
	upiQuery.Set("tr", txnRef)
	upiQuery.Set("tn", fmt.Sprintf("Fee settlement for %s", title))
	upiQuery.Set("cu", "INR")
	upiLink := "upi://pay?" + upiQuery.Encode()

	order := &model.PaymentOrder{
		BaseSyncModel: model.BaseSyncModel{
			ID:        orderID,
			CreatedAt: now,
			UpdatedAt: now,
		},
		OrderID:         orderID,
		EntityType:      req.EntityType,
		EntityID:        req.EntityID,
		StudentID:       req.StudentID,
		StudentName:     studentName,
		Amount:          req.Amount,
		Currency:        "INR",
		Status:          model.OrderStatusCreated,
		GatewayProvider: s.provider,
		GatewayOrderID:  gatewayOrderID,
		GatewayKeyID:    s.keyID,
		UPILink:         upiLink,
		VirtualAccount:  va,
		Notes:           req.Notes,
		ExpiresAt:       now.Add(20 * time.Minute),
	}

	s.orders[order.OrderID] = order
	orderCopy := *order
	return &orderCopy, nil
}

// VerifyAndCapture verifies payment authorization and applies settlement to the student fee ledger
func (s *PaymentService) VerifyAndCapture(ctx context.Context, req model.VerifyPaymentRequest) (*model.FeePayment, *model.FeeReceipt, error) {
	s.mu.Lock()
	order, exists := s.orders[req.OrderID]
	if !exists {
		s.mu.Unlock()
		return nil, nil, fmt.Errorf("payment order '%s' not found", req.OrderID)
	}

	if order.Status == model.OrderStatusPaid {
		s.mu.Unlock()
		return nil, nil, errors.New("payment order has already been paid and settled")
	}

	// Cryptographic verification if using production Razorpay / Cashfree
	if s.provider == model.GatewayProviderRazorpay && s.keySecret != "" {
		if req.Signature == "" {
			s.mu.Unlock()
			return nil, nil, errors.New("gateway signature is required for razorpay verification")
		}
		expectedMessage := order.GatewayOrderID + "|" + req.PaymentID
		h := hmac.New(sha256.New, []byte(s.keySecret))
		h.Write([]byte(expectedMessage))
		expectedSig := hex.EncodeToString(h.Sum(nil))
		if !hmac.Equal([]byte(expectedSig), []byte(req.Signature)) {
			s.mu.Unlock()
			return nil, nil, errors.New("invalid razorpay payment signature")
		}
	}

	// Update order status
	order.Status = model.OrderStatusPaid
	order.UpdatedAt = time.Now().UTC()
	s.mu.Unlock()

	// Apply settlement to FeeService
	var payment *model.FeePayment
	var receipt *model.FeeReceipt
	var err error

	cleanMethod := strings.ToLower(strings.TrimSpace(req.PaymentMethod))
	if cleanMethod == "" {
		cleanMethod = model.PaymentMethodUPI
	}

	if order.EntityType == "invoice" {
		payment, receipt, err = s.feeService.PayInvoice(ctx, model.PayInvoiceRequest{
			InvoiceID:     order.EntityID,
			StudentID:     order.StudentID,
			Amount:        order.Amount,
			PaymentMethod: cleanMethod,
		})
	} else {
		payment, receipt, err = s.feeService.PayFine(ctx, model.PayFineRequest{
			FineID:        order.EntityID,
			StudentID:     order.StudentID,
			PaymentMethod: cleanMethod,
		})
	}

	if err != nil {
		return nil, nil, fmt.Errorf("ledger settlement failed: %w", err)
	}

	// Enrich payment and receipt with transaction references
	if req.TransactionRef != "" {
		payment.TransactionRef = req.TransactionRef
		receipt.TransactionRef = req.TransactionRef
	} else if req.PaymentID != "" {
		payment.TransactionRef = req.PaymentID
		receipt.TransactionRef = req.PaymentID
	}

	return payment, receipt, nil
}

// ProcessWebhook parses asynchronous gateway notification webhooks
func (s *PaymentService) ProcessWebhook(ctx context.Context, rawPayload []byte, signature string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.webhookSecret != "" && signature != "" {
		h := hmac.New(sha256.New, []byte(s.webhookSecret))
		h.Write(rawPayload)
		expectedSig := hex.EncodeToString(h.Sum(nil))
		if !hmac.Equal([]byte(expectedSig), []byte(signature)) {
			return errors.New("invalid webhook signature")
		}
	}

	var payload struct {
		Event   string `json:"event"`
		Payload struct {
			Payment struct {
				Entity struct {
					ID      string  `json:"id"`
					OrderID string  `json:"order_id"`
					Amount  float64 `json:"amount"`
					Status  string  `json:"status"`
					Method  string  `json:"method"`
				} `json:"entity"`
			} `json:"payment"`
		} `json:"payload"`
	}

	if err := json.Unmarshal(rawPayload, &payload); err != nil {
		return fmt.Errorf("malformed webhook JSON: %w", err)
	}

	orderID := payload.Payload.Payment.Entity.OrderID
	order, exists := s.orders[orderID]
	if !exists {
		return nil // Non-campus order ignored safely
	}

	if order.Status == model.OrderStatusPaid {
		return nil // Idempotent
	}

	order.Status = model.OrderStatusPaid
	order.UpdatedAt = time.Now().UTC()

	return nil
}
