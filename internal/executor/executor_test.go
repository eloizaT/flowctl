package executor

import "testing"

func TestExecuteSuccess(t *testing.T) {
	err := Execute("echo hello")

	if err != nil {
		t.Fatalf("Execute() returned unexpected error: %v", err)
	}
}

func TestExecuteFailure(t *testing.T) {
	err := Execute("exit 1")

	if err == nil {
		t.Fatal("Execute() expected an error")
	}
}
