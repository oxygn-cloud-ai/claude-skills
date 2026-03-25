---
name: my-skill
description: Brief description of what this skill does.
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash(*)
argument-hint: [optional arguments]
---

# My Skill Name

## Help

If $ARGUMENTS equals "help", "--help", or "-h", display the following usage guide instead of running the skill, then stop.

```
my-skill — Short description

USAGE
  /my-skill                Run with defaults
  /my-skill <arg>          Run with a specific argument
  /my-skill help           Display this usage guide

WHAT IT DOES
  Describe what the skill does in 2-3 sentences.

TOOLS USED
  List the tools this skill uses.
```

End of help output. Do not continue.

---

## Instructions

Describe the skill's behavior, methodology, and output format here.
