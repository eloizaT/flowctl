package main

import (
	"fmt"
	"os"

	"github.com/eloizaT/flowctl/internal/config"
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

	workflowName := args[0]

	fmt.Printf("Running workflow: %s\n", workflowName)

	_ = cfg

	return nil
}
