package model

import (
	"testing"
	"time"
)

func TestLibraryModelsValidation(t *testing.T) {
	// 1. PhysicalBook
	b := &PhysicalBook{
		Title:           "",
		Author:          "Author",
		ISBN:            "123",
		TotalCopies:     5,
		AvailableCopies: 3,
	}
	if err := b.Validate(); err == nil {
		t.Fatal("expected error on empty title")
	}

	b.Title = "Algorithms"
	b.TotalCopies = 0
	if err := b.Validate(); err == nil {
		t.Fatal("expected error on zero total copies")
	}

	b.TotalCopies = 5
	b.AvailableCopies = 6
	if err := b.Validate(); err == nil {
		t.Fatal("expected error when available copies > total copies")
	}

	b.AvailableCopies = 4
	if err := b.Validate(); err != nil {
		t.Fatalf("unexpected validation error: %v", err)
	}

	// 2. BorrowRecord
	br := &BorrowRecord{
		BookID:    "",
		StudentID: "usr-1",
		DueDate:   time.Now().Add(14 * 24 * time.Hour),
	}
	if err := br.Validate(); err == nil {
		t.Fatal("expected error on empty book id")
	}

	br.BookID = "bk-1"
	br.StudentID = ""
	if err := br.Validate(); err == nil {
		t.Fatal("expected error on empty student id")
	}

	br.StudentID = "usr-1"
	br.DueDate = time.Time{}
	if err := br.Validate(); err == nil {
		t.Fatal("expected error on zero due date")
	}

	br.DueDate = time.Now().Add(7 * 24 * time.Hour)
	if err := br.Validate(); err != nil {
		t.Fatalf("unexpected borrow record error: %v", err)
	}

	// 3. EBook
	eb := &EBook{
		Title:  "",
		Author: "Author",
	}
	if err := eb.Validate(); err == nil {
		t.Fatal("expected error on empty ebook title")
	}

	eb.Title = "Cloud Computing"
	eb.Author = ""
	if err := eb.Validate(); err == nil {
		t.Fatal("expected error on empty ebook author")
	}

	eb.Author = "Dr. Author"
	if err := eb.Validate(); err != nil {
		t.Fatalf("unexpected ebook error: %v", err)
	}
}
