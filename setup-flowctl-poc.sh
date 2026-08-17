#!/usr/bin/env bash
set -euo pipefail

# flowctl POC GitHub bootstrap
#
# Creates:
#   - labels
#   - milestone: "POC — Sequential Workflow Execution"
#   - GitHub Project: "flowctl POC"
#   - project field: "POC Status" with Backlog/Ready/In Progress/Review/Done
#   - 9 issues for the POC implementation plan
#   - adds each issue to the project
#
# Requirements:
#   - GitHub CLI (gh)
#   - authenticated GitHub CLI session
#   - project scope: gh auth refresh -s project
#
# Usage:
#   ./setup-flowctl-poc.sh
#   ./setup-flowctl-poc.sh --repo OWNER/REPO
#   ./setup-flowctl-poc.sh --repo OWNER/REPO --project-owner OWNER
#
# By default, the repository is inferred from the current git directory and
# the project owner is inferred from OWNER/REPO.

MILESTONE_TITLE="POC — Sequential Workflow Execution"
PROJECT_TITLE="flowctl POC"
PROJECT_FIELD="POC Status"
PROJECT_OPTIONS="Backlog,Ready,In Progress,Review,Done"

REPO=""
PROJECT_OWNER=""

usage() {
  cat <<'EOF'
Usage:
  setup-flowctl-poc.sh [--repo OWNER/REPO] [--project-owner OWNER]

Options:
  --repo OWNER/REPO       Target GitHub repository.
                          Defaults to the current repository.
  --project-owner OWNER   User or organization that owns the GitHub Project.
                          Defaults to the repository owner.
  -h, --help              Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --project-owner)
      PROJECT_OWNER="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

command -v gh >/dev/null 2>&1 || {
  echo "Error: GitHub CLI (gh) is required." >&2
  exit 1
}

gh auth status >/dev/null 2>&1 || {
  echo "Error: GitHub CLI is not authenticated. Run: gh auth login" >&2
  exit 1
}

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
fi

if [[ "$REPO" != */* ]]; then
  echo "Error: --repo must be in OWNER/REPO format." >&2
  exit 1
fi

REPO_OWNER="${REPO%%/*}"
if [[ -z "$PROJECT_OWNER" ]]; then
  PROJECT_OWNER="$REPO_OWNER"
fi

echo "Repository:    $REPO"
echo "Project owner: $PROJECT_OWNER"
echo

# Verify repository access.
gh repo view "$REPO" >/dev/null

echo "Creating/updating labels..."

create_label() {
  local name="$1"
  local color="$2"
  local description="$3"
  gh label create "$name" \
    --repo "$REPO" \
    --color "$color" \
    --description "$description" \
    --force >/dev/null
}

create_label "type: feature" "1D76DB" "New POC functionality"
create_label "type: test" "0E8A16" "Tests and verification"
create_label "type: docs" "5319E7" "Documentation"
create_label "type: chore" "D4C5F9" "Project setup and maintenance"

create_label "area: cli" "C5DEF5" "CLI entry point and command handling"
create_label "area: config" "BFDADC" "Configuration loading and validation"
create_label "area: executor" "F9D0C4" "Process execution"
create_label "area: workflow" "FEF2C0" "Workflow orchestration"

create_label "priority: high" "B60205" "Required for the POC"
create_label "priority: medium" "FBCA04" "Important but not blocking the core proof"

echo "Labels ready."

# Milestones are created through the GitHub REST API.
echo "Ensuring milestone exists..."
MILESTONE_NUMBER="$(
  gh api "repos/$REPO/milestones?state=all&per_page=100" \
    --jq ".[] | select(.title == \"$MILESTONE_TITLE\") | .number" \
    | head -n 1
)"

if [[ -z "$MILESTONE_NUMBER" ]]; then
  MILESTONE_NUMBER="$(
    gh api --method POST "repos/$REPO/milestones" \
      -f title="$MILESTONE_TITLE" \
      -f description="Proof of concept: load a YAML workflow and execute its steps sequentially from the flowctl Go CLI." \
      --jq '.number'
  )"
  echo "Created milestone #$MILESTONE_NUMBER."
else
  echo "Milestone already exists (#$MILESTONE_NUMBER)."
fi

echo
echo "Ensuring GitHub Project exists..."

# gh project requires the project OAuth scope. If this command fails, refresh:
#   gh auth refresh -s project
PROJECT_NUMBER="$(
  gh project list --owner "$PROJECT_OWNER" --format json \
    --jq ".projects[] | select(.title == \"$PROJECT_TITLE\") | .number" \
    2>/dev/null | head -n 1 || true
)"

if [[ -z "$PROJECT_NUMBER" ]]; then
  PROJECT_NUMBER="$(
    gh project create \
      --owner "$PROJECT_OWNER" \
      --title "$PROJECT_TITLE" \
      --format json \
      --jq '.number'
  )"
  echo "Created project #$PROJECT_NUMBER."
else
  echo "Project already exists (#$PROJECT_NUMBER)."
fi

echo "Ensuring project status field exists..."
FIELD_EXISTS="$(
  gh project field-list "$PROJECT_NUMBER" \
    --owner "$PROJECT_OWNER" \
    --format json \
    --jq ".fields[] | select(.name == \"$PROJECT_FIELD\") | .name" \
    2>/dev/null | head -n 1 || true
)"

if [[ -z "$FIELD_EXISTS" ]]; then
  gh project field-create "$PROJECT_NUMBER" \
    --owner "$PROJECT_OWNER" \
    --name "$PROJECT_FIELD" \
    --data-type SINGLE_SELECT \
    --single-select-options "$PROJECT_OPTIONS" >/dev/null
  echo "Created '$PROJECT_FIELD' field."
else
  echo "'$PROJECT_FIELD' field already exists."
fi

create_issue() {
  local title="$1"
  local labels="$2"
  local body="$3"

  # Avoid duplicate issues if the script is re-run.
  local existing_url
  existing_url="$(
    gh issue list \
      --repo "$REPO" \
      --state all \
      --limit 200 \
      --json title,url \
      --jq ".[] | select(.title == \"$title\") | .url" \
      | head -n 1
  )"

  if [[ -n "$existing_url" ]]; then
    echo "Exists:  $title"
    echo "$existing_url"
    return 0
  fi

  local args=()
  IFS=',' read -ra label_array <<< "$labels"
  for label in "${label_array[@]}"; do
    args+=(--label "$label")
  done

  local issue_url
  issue_url="$(
    gh issue create \
      --repo "$REPO" \
      --title "$title" \
      --milestone "$MILESTONE_TITLE" \
      "${args[@]}" \
      --body "$body"
  )"

  gh project item-add "$PROJECT_NUMBER" \
    --owner "$PROJECT_OWNER" \
    --url "$issue_url" >/dev/null

  echo "Created: $title"
  echo "$issue_url"
}

echo
echo "Creating POC issues..."

create_issue \
  "Initialize the Go CLI project" \
  "type: chore,area: cli,priority: high" \
'## Goal

Create the minimum project structure needed to build and run `flowctl`.

## Tasks

- [ ] Initialize the Go module.
- [ ] Create `cmd/flowctl/main.go`.
- [ ] Add a basic CLI entry point.
- [ ] Support `flowctl run <workflow>`.
- [ ] Print usage when arguments are invalid.
- [ ] Add `.gitignore`.
- [ ] Confirm the binary builds.

## Acceptance criteria

- `go build ./cmd/flowctl` succeeds.
- `flowctl run validate` reaches a placeholder `run` implementation.

## Estimate

1–1.5 hours.'

create_issue \
  "Define the POC workflow configuration model" \
  "type: feature,area: config,priority: high" \
'## Goal

Represent the POC YAML configuration with simple Go structs.

## POC schema

```yaml
version: 1

workflows:
  validate:
    steps:
      - name: unit-tests
        run: go test ./...
```

The model only needs:

- configuration version
- named workflows
- workflow steps
- step name
- command to run

## Explicitly out of scope

Do not add:

- `depends_on`
- `timeout`
- `retry`
- environment variables
- working directories
- conditions
- variables

Avoid interfaces or abstractions unless there is a concrete need.

## Acceptance criteria

- The model represents the POC YAML cleanly.
- YAML tags are present.
- No unnecessary abstractions are introduced.

## Estimate

30–45 minutes.'

create_issue \
  "Load and parse flowctl.yaml" \
  "type: feature,area: config,priority: high" \
'## Goal

Load `./flowctl.yaml` from the current working directory and parse it into the POC configuration model.

## Tasks

- [ ] Locate `./flowctl.yaml`.
- [ ] Read the file.
- [ ] Parse YAML into Go structs.
- [ ] Return useful errors for a missing file.
- [ ] Return useful errors for an unreadable file.
- [ ] Return useful errors for malformed YAML.
- [ ] Add a focused YAML library dependency.

## Acceptance criteria

- Valid YAML loads successfully.
- Malformed YAML exits non-zero and clearly reports a configuration parsing problem.

## Estimate

1–2 hours.'

create_issue \
  "Resolve a workflow by name" \
  "type: feature,area: workflow,priority: high" \
'## Goal

Resolve the workflow requested by `flowctl run <workflow>`.

## Tasks

- [ ] Read the workflow name from CLI arguments.
- [ ] Find the workflow in `Config.Workflows`.
- [ ] Return a useful error when the workflow does not exist.
- [ ] Keep dependency resolution out of this POC.

## Acceptance criteria

- Existing workflows resolve successfully.
- Unknown workflows exit non-zero.
- No dependency graph or dependency resolution exists.

## Estimate

30–45 minutes.'

create_issue \
  "Execute a single shell command" \
  "type: feature,area: executor,priority: high" \
'## Goal

Prove that Go can execute a configured shell command and propagate its result.

This is the central technical spike of the POC.

## Tasks

- [ ] Start a configured command.
- [ ] Connect stdout to the terminal.
- [ ] Connect stderr to the terminal.
- [ ] Wait for command completion.
- [ ] Detect a non-zero exit status.
- [ ] Return an execution error on failure.
- [ ] Document the shell/platform assumption used by the POC.

For the POC, commands may execute through the system shell. Do not build a cross-platform shell abstraction yet.

## Acceptance criteria

- `echo hello` succeeds and prints output.
- A command that exits with status `1` fails.
- stdout is visible.
- stderr is visible.
- Command failure is surfaced to the caller.

## Estimate

1.5–2.5 hours.'

create_issue \
  "Execute workflow steps sequentially" \
  "type: feature,area: workflow,area: executor,priority: high" \
'## Goal

Connect workflow loading and command execution into the actual proof of concept.

## Tasks

- [ ] Iterate through workflow steps in configuration order.
- [ ] Print the step name before execution.
- [ ] Execute each configured command.
- [ ] Stop immediately when a step fails.
- [ ] Do not execute later steps after a failure.
- [ ] Return the workflow result to `main`.
- [ ] Exit `0` on workflow success.
- [ ] Exit non-zero on workflow failure.

Do not spend significant time on polished terminal formatting.

## Acceptance criteria

Given:

```yaml
steps:
  - name: first
    run: echo first
  - name: second
    run: echo second
```

`first` runs before `second`.

Given:

```yaml
steps:
  - name: succeeds
    run: echo works
  - name: fails
    run: exit 1
  - name: should-not-run
    run: echo SHOULD_NOT_APPEAR
```

the third step never executes and `flowctl` exits non-zero.

## Estimate

1.5–2 hours.'

create_issue \
  "Add minimal configuration validation" \
  "type: feature,area: config,priority: medium" \
'## Goal

Catch configuration mistakes that would make POC execution ambiguous or confusing.

## Validate only

- [ ] `version` is supported.
- [ ] At least one workflow exists.
- [ ] The requested workflow has at least one step.
- [ ] Every step has a name.
- [ ] Every step has a command.

Do not create a general validation framework.

## Acceptance criteria

A workflow containing an empty step name or command fails validation before process execution begins.

## Estimate

1 hour.'

create_issue \
  "Add POC tests" \
  "type: test,priority: high" \
'## Goal

Demonstrate that the core design is testable before expanding the project.

## Config tests

- [ ] Valid YAML parses.
- [ ] Malformed YAML fails.
- [ ] Unknown workflow fails.
- [ ] Invalid step fails validation.

## Executor/workflow tests

- [ ] Successful command succeeds.
- [ ] Failed command returns failure.
- [ ] Multiple steps execute sequentially.
- [ ] Workflow stops after the first failed step.

Prefer small test helpers over building an elaborate mock framework.

## Acceptance criteria

`go test ./...` passes.

## Estimate

1.5–2.5 hours.'

create_issue \
  "Add an example workflow and POC README" \
  "type: docs,priority: medium" \
'## Goal

Make the POC reproducible by someone cloning the repository.

## Add

- [ ] `README.md`
- [ ] `examples/flowctl.yaml`

## README contents

- What `flowctl` is
- POC scope
- Requirements
- Build instructions
- Example YAML
- How to run it
- Known limitations
- Next steps

Include a clear statement that this is a proof of concept supporting sequential workflow execution only.

## Explicitly out of scope

- dependency resolution
- parallel execution
- cancellation
- timeouts
- retries
- structured reporting

## Acceptance criteria

Someone can clone the repository, follow the README, build `flowctl`, and execute an example workflow.

## Estimate

1 hour.'

echo
echo "POC bootstrap complete."
echo
echo "Milestone: $MILESTONE_TITLE"
echo "Project:   $PROJECT_TITLE (#$PROJECT_NUMBER)"
echo
echo "Next:"
echo "  1. Open the project:"
echo "     gh project view \"$PROJECT_NUMBER\" --owner \"$PROJECT_OWNER\" --web"
echo
echo "  2. In the GitHub Project UI, group a Board view by '$PROJECT_FIELD'."
echo "     The field contains: Backlog, Ready, In Progress, Review, Done."
echo
echo "  3. Start with: Initialize the Go CLI project"
