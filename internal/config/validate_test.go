package config

import "testing"

func TestValidateValidConfig(t *testing.T) {
	cfg := Config{
		Workflows: map[string]Workflow{
			"test": {
				Steps: []Step{
					{
						Name: "hello",
						Run:  "echo hello",
					},
				},
			},
		},
	}

	err := Validate(cfg)

	if err != nil {
		t.Fatalf("Validate() returned unexpected error: %v", err)
	}
}

func TestValidateNoWorkflows(t *testing.T) {
	cfg := Config{
		Workflows: map[string]Workflow{},
	}

	err := Validate(cfg)

	if err == nil {
		t.Fatal("Validate() expected an error")
	}
}

func TestValidateWorkflowWithNoSteps(t *testing.T) {
	cfg := Config{
		Workflows: map[string]Workflow{
			"test": {
				Steps: []Step{},
			},
		},
	}

	err := Validate(cfg)

	if err == nil {
		t.Fatalf("Validate() did not return expected error: %v", err)
	}
}

func TestValidateStepWithNoRunCommand(t *testing.T) {
	cfg := Config{
		Workflows: map[string]Workflow{
			"test": {
				Steps: []Step{
					{
						Name: "hello",
						Run:  "",
					},
				},
			},
		},
	}

	err := Validate(cfg)

	if err == nil {
		t.Fatalf("Validate() returned unexpected error: %v", err)
	}
}
