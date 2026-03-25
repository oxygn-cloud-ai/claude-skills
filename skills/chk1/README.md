# chk1 — Adversarial Implementation Audit

A Claude Code skill that performs fault-finding, risk-exposing, deviation-detecting audits of recently implemented changes.

## What it does

Assumes the implementation is defective unless proven otherwise. Audits:

1. Functional Correctness Verification
2. Bug Detection (syntax, types, race conditions, resource leaks, etc.)
3. Critical Risk Assessment (security, data integrity, performance)
4. Scope Compliance Verification
5. Unintended Changes Detection
6. Architectural Compliance Review
7. Omissions Analysis
8. Completeness Verification

## Installation

### Automatic (recommended)

```bash
./install.sh
```

### Manual

Copy the skill directory to your Claude Code skills folder:

```bash
mkdir -p ~/.claude/skills/chk1
cp SKILL.md ~/.claude/skills/chk1/SKILL.md
```

## Usage

In Claude Code:

```
/chk1                     # Audit the most recent implementation (auto-detects commits)
/chk1 <commit>..<commit>  # Audit a specific commit range
/chk1 <branch>            # Audit changes on a specific branch
/chk1 help                # Display usage guide
```

## Uninstall

```bash
rm -rf ~/.claude/skills/chk1
```
