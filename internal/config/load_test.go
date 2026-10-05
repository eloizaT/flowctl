package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadWithDependencies(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "flowctl.yaml")
	err := os.WriteFile(path, []byte(`
workflows:
 validate:
  steps:
  - name: build
    run: go build ./cmd/flowctl
    depends_on:
     - test
     - lint`), 0644)

	if err != nil {
		t.Fatalf("WriteFile() returned unexpected error: %v", err)
	}

	result, err := Load(path)

	if err != nil {
		t.Fatalf("Load() returned unexpected error: %v", err)
	}

	workflow, ok := result.Workflows["validate"]
	if !ok {
		t.Fatal(`expected workflow "validate"`)
	}

	if len(workflow.Steps) != 1 {
		t.Fatalf("expected length 1, got %d", len(workflow.Steps))
	}

	dependencies := workflow.Steps[0].DependsOn

	if len(dependencies) != 2 {
		t.Fatalf("expected 2 dependencies, got %d", len(dependencies))
	}

	if dependencies[0] != "test" {
		t.Errorf(`expected first dependency "test", got %q`, dependencies[0])
	}

	if dependencies[1] != "lint" {
		t.Errorf(`expected second dependency "lint", got %q`, dependencies[1])
	}
}

func TestLoadWithoutDependencies(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "flowctl.yaml")

	err := os.WriteFile(path, []byte(`
workflows:
  validate:
    steps:
      - name: test
        run: go test ./...
`), 0644)
	if err != nil {
		t.Fatalf("WriteFile() returned unexpected error: %v", err)
	}

	result, err := Load(path)
	if err != nil {
		t.Fatalf("Load() returned unexpected error: %v", err)
	}

	workflow, ok := result.Workflows["validate"]
	if !ok {
		t.Fatal(`expected workflow "validate"`)
	}

	if len(workflow.Steps) != 1 {
		t.Fatalf("expected 1 step, got %d", len(workflow.Steps))
	}

	dependencies := workflow.Steps[0].DependsOn

	if len(dependencies) != 0 {
		t.Errorf("expected no dependencies, got %v", dependencies)
	}
}
