package service

import (
	"flag"
	"os"
	"strings"
)

// ShouldSeedMockData returns true only when explicitly instructed via ENABLE_MOCK_SEEDING
// or when running within automated Go unit tests.
func ShouldSeedMockData() bool {
	if os.Getenv("ENABLE_MOCK_SEEDING") == "true" {
		return true
	}
	if flag.Lookup("test.v") != nil || strings.HasSuffix(os.Args[0], ".test") {
		return true
	}
	return false
}
