package model

import (
	"errors"
	"strings"
	"time"
)

// Payment gateway providers
const (
	GatewayProviderSandbox  = "sandbox"
	GatewayProviderRazorpay = "razorpay"
	GatewayProviderCashfree = "cashfree"
	GatewayProviderPayU     = "payu"
)

// Payment order statuses
const (
	OrderStatusCreated    = "created"
	OrderStatusProcessing = "processing"
	OrderStatusPaid       = "paid"
	OrderStatusFailed     = "failed"
	OrderStatusExpired    = "expired"
)

// VirtualAccount holds institutional NEFT/RTGS collection credentials
type VirtualAccount struct {
	BeneficiaryName string `json:"beneficiary_name"`
	BankName        string `json:"bank_name"`
	AccountNumber   string `json:"account_number"`
	IFSCCode        string `json:"ifsc_code"`
	BranchName      string `json:"branch_name"`
	ReferenceVAN    string `json:"reference_van"`
}

// PaymentOrder represents a checkout session created for an institutional invoice or fine
type PaymentOrder struct {
	BaseSyncModel
	OrderID         string          `json:"order_id"`
	EntityType      string          `json:"entity_type"` // invoice, fine
	EntityID        string          `json:"entity_id"`
	StudentID       string          `json:"student_id"`
	StudentName     string          `json:"student_name"`
	Amount          float64         `json:"amount"`
	Currency        string          `json:"currency"`
	Status          string          `json:"status"`
	GatewayProvider string          `json:"gateway_provider"`
	GatewayOrderID  string          `json:"gateway_order_id"`
	GatewayKeyID    string          `json:"gateway_key_id"`
	UPILink         string          `json:"upi_link"`
	VirtualAccount  *VirtualAccount `json:"virtual_account,omitempty"`
	Notes           string          `json:"notes,omitempty"`
	ExpiresAt       time.Time       `json:"expires_at"`
}

// CreatePaymentOrderRequest encapsulates order creation parameters
type CreatePaymentOrderRequest struct {
	EntityType string  `json:"entity_type"` // invoice, fine
	EntityID   string  `json:"entity_id"`
	StudentID  string  `json:"student_id"`
	Amount     float64 `json:"amount"`
	Notes      string  `json:"notes,omitempty"`
}

// VerifyPaymentRequest encapsulates gateway signature or settlement verification
type VerifyPaymentRequest struct {
	OrderID        string  `json:"order_id"`
	PaymentID      string  `json:"payment_id"`
	PaymentMethod  string  `json:"payment_method"` // upi, card, netbanking, challan
	TransactionRef string  `json:"transaction_ref,omitempty"`
	Signature      string  `json:"signature,omitempty"`
	UTRNumber      string  `json:"utr_number,omitempty"`
	BankName       string  `json:"bank_name,omitempty"`
	UPIVPA         string  `json:"upi_vpa,omitempty"`
	CardLast4      string  `json:"card_last4,omitempty"`
}

// VerifyPaymentResponse returns verification outcome and tamper-evident receipt
type VerifyPaymentResponse struct {
	Success        bool        `json:"success"`
	Payment        *FeePayment `json:"payment,omitempty"`
	Receipt        *FeeReceipt `json:"receipt,omitempty"`
	Message        string      `json:"message"`
	TransactionRef string      `json:"transaction_ref,omitempty"`
}

// PaymentGatewayPublicConfig returns client-facing checkout configuration
type PaymentGatewayPublicConfig struct {
	Provider         string          `json:"provider"`
	KeyID            string          `json:"key_id"`
	MerchantName     string          `json:"merchant_name"`
	MerchantVPA      string          `json:"merchant_vpa"`
	Environment      string          `json:"environment"`
	SupportedMethods []string        `json:"supported_methods"`
	VirtualAccount   *VirtualAccount `json:"virtual_account"`
}

// Validate checks request validity
func (req *CreatePaymentOrderRequest) Validate() error {
	cleanType := strings.ToLower(strings.TrimSpace(req.EntityType))
	if cleanType != "invoice" && cleanType != "fine" {
		return errors.New("entity_type must be 'invoice' or 'fine'")
	}
	if strings.TrimSpace(req.EntityID) == "" {
		return errors.New("entity_id is required")
	}
	if strings.TrimSpace(req.StudentID) == "" {
		return errors.New("student_id is required")
	}
	if req.Amount <= 0 {
		return errors.New("amount must be greater than zero")
	}
	return nil
}
