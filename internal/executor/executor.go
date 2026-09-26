package executor

import (
	"fmt"
	"os"
	"os/exec"
)

func Execute(command string)error {
	cmd := exec.Command("sh", "-c", command)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("execute command %q: %w", command, err)
	}

	return nil
}
