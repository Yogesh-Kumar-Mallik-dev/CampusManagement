package model

import "time"

// DigiLockerAuthURLRequest initiates the OAuth 2.0 PKCE flow for a student
type DigiLockerAuthURLRequest struct {
	StudentID   string `json:"student_id"`
	RedirectURI string `json:"redirect_uri,omitempty"`
}

// DigiLockerAuthURLResponse returns the generated authorization URL and PKCE state
type DigiLockerAuthURLResponse struct {
	AuthURL      string `json:"auth_url"`
	State        string `json:"state"`
	CodeVerifier string `json:"code_verifier"`
	Environment  string `json:"environment"` // 'sandbox' or 'production'
}

// DigiLockerExchangeRequest exchanges the authorization code for verified credentials
type DigiLockerExchangeRequest struct {
	Code         string `json:"code"`
	State        string `json:"state"`
	CodeVerifier string `json:"code_verifier"`
	StudentID    string `json:"student_id"`
}

// DigiLockerTokenResponse represents the OAuth token response from DigiLocker / MeriPehchan
type DigiLockerTokenResponse struct {
	AccessToken  string `json:"access_token"`
	ExpiresIn    int    `json:"expires_in"`
	TokenType    string `json:"token_type"`
	Scope        string `json:"scope"`
	DigiLockerID string `json:"digilocker_id,omitempty"`
	Name         string `json:"name,omitempty"`
	DOB          string `json:"dob,omitempty"`
	Gender       string `json:"gender,omitempty"`
}

// DigiLockerIssuedFile represents an official credential document retrieved via DigiLocker API
type DigiLockerIssuedFile struct {
	URI         string `json:"uri"`
	Name        string `json:"name"`
	DocType     string `json:"doctype"`
	Description string `json:"description"`
	Issuer      string `json:"issuer"`
	Date        string `json:"date"`
}

// DigiLockerStatusResponse represents the active connection status for a student
type DigiLockerStatusResponse struct {
	StudentID       string             `json:"student_id"`
	IsConnected     bool               `json:"is_connected"`
	ABCID           string             `json:"abc_id,omitempty"`
	VerifiedAt      *time.Time         `json:"verified_at,omitempty"`
	DocumentsCount  int                `json:"documents_count"`
	Documents       []VerifiedDocument `json:"documents,omitempty"`
	EnvironmentMode string             `json:"environment_mode"`
}
