---
name: chk1
description: Adversarial Implementation Audit Mandate. Use when auditing recently implemented changes for bugs, risks, omissions, deviations, and unintended modifications. Fault-finding audit, not validation.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(git *)
argument-hint: [optional scope hint]
---

# Adversarial Implementation Audit Mandate

## Help

If $ARGUMENTS equals "help", "--help", or "-h", display the following usage guide instead of running the audit, then stop. Do not proceed with the audit.

```
chk1 — Adversarial Implementation Audit

USAGE
  /chk1                     Audit the most recent implementation (auto-detects commits)
  /chk1 <commit>..<commit>  Audit a specific commit range
  /chk1 <branch>            Audit changes on a specific branch
  /chk1 help                Display this usage guide

WHAT IT DOES
  Fault-finding, risk-exposing, deviation-detecting audit of recently
  implemented changes. Assumes the implementation is defective unless
  proven otherwise. This is not a validation exercise.

AUDIT SECTIONS
  1. Functional Correctness Verification
  2. Bug Detection (syntax, types, race conditions, resource leaks, etc.)
  3. Critical Risk Assessment (security, data integrity, performance)
  4. Scope Compliance Verification
  5. Unintended Changes Detection
  6. Architectural Compliance Review
  7. Omissions Analysis
  8. Completeness Verification

OUTPUT FORMAT
  - Files Changed
  - Per-File Analysis (with CORRECT / WARNING / BUG FOUND status)
  - Bugs Found (numbered, with file and line references)
  - Critical Risks (with severity and remediation)
  - Unintended Changes
  - Omissions
  - Architectural Deviations
  - Summary (blocked / permitted recommendation)
  - Remediation Plan

TOOLS USED
  Read-only access: Read, Grep, Glob, Bash(git *)
  No files are modified during the audit.

LOCATION
  ~/.claude/skills/chk1/SKILL.md
```

End of help output. Do not continue.

---

Conduct a comprehensive, adversarial audit of the changes most recently implemented.

This task is explicitly not a validation exercise. It is a fault-finding, risk-exposing, and deviation-detecting audit. You must assume the implementation is defective unless proven otherwise. Positive affirmation, reassurance, benefit-of-the-doubt reasoning, or deference to intent is prohibited.

You are required to identify errors, weaknesses, omissions, risks, and deviations. Absence of findings must only be concluded after explicit verification. Silence, ambiguity, or vague confirmation is unacceptable.

## Scope Constraint

Review all artefacts modified in the previous implementation, including but not limited to:

- Source code
- Files
- Database schema or data migrations
- Edge functions
- Configuration files
- Documentation
- Knowledgebase

Do not review, comment on, or modify anything outside this scope. Any detection of out-of-scope modification must be explicitly flagged as a violation.

Assume the implementation contains numerous issues including, but not limited to, bugs, omissions, defects, risks, unintended changes, architectural deviations, and incomplete work. Your responsibility is to surface all such issues.

Ignore CLAUDE.md.

## Determining Scope

Before beginning the audit, identify the changes to audit:

1. Run `git log --oneline -20` to identify recent commits
2. Identify the commit range covering the most recent implementation (all commits from the last implementation session)
3. Run `git diff <base>..<head> --stat` to list all modified files
4. Run `git diff <base>..<head>` to obtain the full diff
5. If an implementation plan exists (e.g., PLAN.md or similar), read it to establish the approved scope

If $ARGUMENTS is provided, use it to narrow or identify the scope (e.g., a commit range, branch name, or plan file path).

## 1. Functional Correctness Verification

For each individual change, explicitly verify and either confirm or refute the following:

- The code executes without runtime errors under all expected execution paths
- The implemented logic exactly matches the approved implementation plan
- All edge cases are handled, including null values, empty states, boundary conditions, and invalid inputs
- Error handling exists, is reachable, and is appropriate
- Data flows correctly between components, layers, and services without loss, mutation, or inconsistency

Failure to explicitly verify any item must be treated as a defect.

## 2. Bug Detection Requirements

Actively and exhaustively search for the following classes of defects:

- Syntax errors and typographical mistakes
- Undefined variables, unresolved references, or missing imports
- Incorrect data types or type mismatches
- Off-by-one errors in indexing, iteration, or pagination
- Race conditions, deadlocks, or incorrect async or await usage
- Resource leaks including memory, file handles, database connections, or listeners
- Hardcoded values that should be configurable or parameterised
- Missing null, undefined, or bounds checks

Assume bugs exist. Prove otherwise.

## 3. Critical Risk Assessment

Identify, classify, and escalate any of the following risks. Absence of findings requires explicit justification.

- Security vulnerabilities including XSS, injection, exposed secrets, authentication or authorisation bypasses
- Data integrity risks including lost updates, inconsistent state, partial writes, or non-atomic operations
- Performance risks including N+1 queries, unnecessary recomputation, blocking operations, or excessive resource usage
- Breaking changes to existing behaviour, APIs, contracts, or data
- Missing, insufficient, or bypassable user input validation
- Unhandled promise rejections, uncaught exceptions, or silent failures

Each identified risk must include severity and remediation guidance.

## 4. Scope Compliance Verification

Explicitly confirm or refute the following:

- No files outside the approved plan scope were modified
- No unintended deletions occurred
- No dependencies were added, removed, or version-altered without specification
- Existing automated tests still pass, if applicable
- No configuration, environment, or deployment changes were introduced unexpectedly

Any violation must be listed as an unintended change.

## 5. Unintended Changes Detection

Identify and enumerate:

- Any changes not specified in the implementation plan
- Any partial or complete implementation of out-of-scope features
- Any modifications to existing code outside the approved scope
- Any bug fixes, refactors, or improvements not explicitly authorised

If none are found, state "None detected" only after explicit verification.

## 6. Architectural Compliance Review

Explicitly verify that:

- No changes deviate from the approved application architecture
- No new patterns, layers, dependencies, or coupling were introduced
- No erosion of architectural boundaries occurred

Any deviation must be documented as a defect, regardless of perceived improvement.

## 7. Omissions Analysis

Identify all omissions, including:

- Missing phases, stages, or steps from the implementation plan
- Incomplete execution of any required task
- Skipped validations, migrations, or configuration updates

Omissions are treated as defects.

## 8. Completeness Verification

Explicitly confirm or refute:

- All steps in the implementation plan were fully completed
- No steps were left incomplete, partially completed, or deferred

Partial completion is not acceptable unless explicitly authorised.

## Output Format (Strict)

Produce a structured report using only the following sections and order:

### Files Changed
List every modified file explicitly.

### Per-File Analysis
For each file:
- Description of changes
- Verification status: CORRECT | WARNING | BUG FOUND
- Detailed issues identified
- Risk level: Low | Medium | High | Critical

### Bugs Found
Numbered list including file, line reference, and precise description.

### Critical Risks
Numbered list including severity classification and recommended remediation.

### Unintended Changes
List all detected unintended changes or explicitly state "None detected".

### Omissions
Complete list of all omissions.

### Architectural Deviations
Complete list of all architectural deviations.

### Summary
Overall assessment and explicit recommendation on whether progression is blocked or permitted.

### Remediation Plan
Prepare a detailed, step-by-step plan to address every issue identified.

Begin the audit immediately.
