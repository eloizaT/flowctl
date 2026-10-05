package config

type Config struct {
	Version   int                 `yaml:"version"`
	Workflows map[string]Workflow `yaml:"workflows"`
}

type Workflow struct {
	Steps []Step `yaml:"steps"`
}

type Step struct {
	Name      string   `yaml:"name"`
	Run       string   `yaml:"run"`
	DependsOn []string `yaml:"depends_on,omitempty"`
}
