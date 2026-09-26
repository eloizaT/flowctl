# flowctl

A Go CLI for defining and executing local engineering automation workflows from YAML.

This is a small personal project built to learn Go while exploring CLI development, workflow automation, process execution, configuration parsing, and testing.

## What it does

`flowctl` currently supports:

* Loading workflows from `flowctl.yaml`
* Validating workflow configuration
* Executing a named workflow
* Running workflow steps sequentially
* Stopping execution when a step fails
* Forwarding command output to the terminal

## Example configuration

Create a `flowctl.yaml` file in the directory where you run `flowctl`:

```yaml
version: 1

workflows:
  validate:
    steps:
      - name: format
        run: gofmt -w .

      - name: test
        run: go test ./...

      - name: build
        run: go build ./cmd/flowctl
```

An example configuration is also available at `examples/flowctl.yaml`.

## Usage

Build the CLI:

```bash
go build -o flowctl ./cmd/flowctl
```

Run a workflow:

```bash
./flowctl run validate
```

`flowctl` currently looks for a file named `flowctl.yaml` in the current working directory.

When running the example configuration, you can copy it to the repository root:

```bash
cp examples/flowctl.yaml flowctl.yaml
./flowctl run validate
```

Each step runs sequentially. If a command exits with a non-zero status, the workflow stops and `flowctl` exits with an error.

## Development

Format the Go source:

```bash
go fmt ./...
```

Run the test suite:

```bash
go test ./...
```

Build the CLI:

```bash
go build -o flowctl ./cmd/flowctl
```

## Current limitations

The current POC intentionally has a small scope:

* Linux/Unix shell execution through `sh`
* Sequential execution only
* No workflow dependencies
* No concurrent execution
* No retries or timeouts
* No structured execution reports

Additional functionality is tracked through GitHub Issues.
