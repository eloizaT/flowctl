package main

import (
	"fmt"
	"os"

	"github.com/eloizaT/flowctl/internal/config"
	"github.com/eloizaT/flowctl/internal/executor"
)

func main() {
	if err := execute(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func execute(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("usage: flowctl run <workflow>")
	}

	switch args[0] {
	case "run":
		return run(args[1:])
	default:
		return fmt.Errorf("unknown command: %s", args[0])
	}
}

func run(args []string) error {
	if len(args) != 1 {
		return fmt.Errorf("usage: flowctl run <workflow>")
	}

	cfg, err := config.Load("flowctl.yaml")
	if err != nil {
		return err
	}

	if err := config.Validate(cfg); err != nil {
		return err
	}

	workflowName := args[0]

	workflow, ok := cfg.Workflows[workflowName]
	if !ok {
		return fmt.Errorf("workflow %q not found", workflowName)
	}

	fmt.Printf("Running workflow: %s\n", workflowName)

	for _, step := range workflow.Steps {
		fmt.Printf("→ %s\n", step.Name)

		if err := executor.Execute(step.Run); err != nil {
			return fmt.Errorf("step %q failed: %w", step.Name, err)
		}
	}

	return nil
}
