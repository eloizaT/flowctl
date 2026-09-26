package config

import "fmt"

func Validate(cfg Config) error {
	if len(cfg.Workflows) == 0 {
		return fmt.Errorf("config must contain at least one workflow")
	}

	for workflowName, workflow := range cfg.Workflows {
		if len(workflow.Steps) == 0 {
			return fmt.Errorf("workflow %q must contain at least one step", workflowName)
		}

		for _, step := range workflow.Steps {
			if step.Run == "" {
				return fmt.Errorf("step %q in workflow %q must have a run command", step.Name, workflowName)
			}
		}
	}

	return nil
}
