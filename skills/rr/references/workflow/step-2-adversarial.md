# Step 2 — Adversarial Review

## Overview

Perform an adversarial review of Assessment 1. Assume the assessment is wrong, unsupported, speculative, unbounded, does not reflect current regulations, and has other issues.

**Input:** `<key>_<date>_assessment_1.json`
**Output:** `<key>_<date>_adversarial_review.json` (Schema: adversarial-review.schema.json)

---

## Adversarial Criteria

Challenge each section against these criteria:

### 1. Factual Accuracy
- Are all assertions about Chocolate Finance verifiable from confirmed sources?
- Flag any claim that relies on inference or assumption
- Cross-check against business-context.md

### 2. Regulatory Precision
- Is every cited instrument current, correctly titled, and directly relevant?
- **Search the web** to verify any instrument whose status may have changed
- Flag any instrument that is tangentially rather than directly relevant

### 3. Evidential Basis for Ratings
- Are the likelihood and impact ratings supported by specific, grounded justifications?
- Or do they rest on generic statements?
- Would a different assessor, given the same evidence, reach the same rating?

### 4. Control Assessment Rigour
- Are controls assessed based on evidence, or are effectiveness ratings assumed?
- Is the distinction between confirmed and inferred controls clear?
- Does each control with `requires_verification: true` explicitly state this?

### 5. Scope Discipline
- Does the assessment stay within the boundaries of the specific risk?
- Or does it drift into adjacent risk domains?
- Is the role of audit correctly distinguished from risk management and compliance?

### 6. Actionability of Mitigations
- Could a risk owner act on each recommended mitigation without further interpretation?
- Are recommendations grounded in cited regulatory obligations?

### 7. Completeness of Evidences
- Does the Evidences section honestly disclose what was not available?
- Are caveats comprehensive?

### 8. Logical Coherence
- Do the ratings flow consistently through the inherent-to-residual progression?
- Does the residual assessment logically follow from the stated controls?
- If inherent is High and residual is Low, are the controls sufficient to justify this?

---

## Regulatory Verification Process

For every instrument cited in Assessment 1:

1. **Search the web** for the instrument name + "MAS" or "SFC"
2. Verify:
   - Correct title
   - Current status (active, superseded, under consultation)
   - Version/revision date
3. Record verification in the `regulatory_verification` array

```json
{
  "instrument_name": "Guidelines on Business Continuity Management",
  "cited_status": "active",
  "verified_status": "active",
  "verification_date": "2026-03-29",
  "verification_source": "MAS website",
  "discrepancy": false,
  "notes": null
}
```

---

## Challenge Recording

For each issue found, create a challenge entry:

```json
{
  "id": "CH001",
  "section": "inherent_risk",
  "challenge_type": "rating_not_justified",
  "original_claim": "Likelihood is assessed as Medium based on industry trends.",
  "challenge": "The justification relies on generic 'industry trends' without specific evidence applicable to Chocolate Finance's context.",
  "evidence_for_challenge": null,
  "resolution_required": "evidence_required",
  "suggested_resolution": "Cite specific factors from Chocolate Finance's operating environment that support the Medium likelihood rating.",
  "severity": "major"
}
```

### Challenge Types (Enum)

| Type | Description |
|------|-------------|
| `unsupported_claim` | Assertion without evidence |
| `speculative_assertion` | Guess presented as fact |
| `outdated_reference` | Regulatory instrument superseded or amended |
| `missing_evidence` | Required evidence not cited |
| `unbounded_scope` | Scope drift into adjacent risks |
| `rating_not_justified` | Rating lacks specific justification |
| `control_assumed` | Control effectiveness assumed without evidence |
| `regulatory_imprecision` | Wrong title, date, or irrelevant citation |
| `logical_inconsistency` | Ratings don't follow logically |

### Severity Levels

| Severity | Criteria |
|----------|----------|
| `critical` | Invalidates the assessment; must be fixed |
| `major` | Significantly weakens the assessment |
| `minor` | Should be fixed but doesn't undermine conclusions |

---

## Output Structure

Create JSON conforming to `adversarial-review.schema.json`:

```json
{
  "metadata": {
    "ticket_key": "RR-220",
    "review_date": "2026-03-29",
    "source_assessment": "rr-220_2026-03-29_assessment_1.json",
    "source_iteration": 1,
    "reviewer": "Claude (Anthropic) — Adversarial Mode"
  },
  "challenges": [...],
  "regulatory_verification": [...],
  "criteria_assessment": {
    "factual_accuracy": { "passed": false, "issues_found": 2, "notes": "..." },
    ...
  },
  "summary": {
    "total_challenges": 7,
    "critical_count": 1,
    "major_count": 4,
    "minor_count": 2,
    "criteria_passed": 5,
    "criteria_failed": 3,
    "overall_assessment": "requires_major_revision",
    "key_issues": [
      "Inherent risk rating lacks firm-specific justification",
      "Two regulatory instruments require status verification",
      "Control C003 effectiveness assumed without evidence"
    ]
  }
}
```

**Save as:** `<key>_<date>_adversarial_review.json`

---

## Present to User

Render the adversarial review to markdown showing:
1. Summary statistics
2. Key issues to address
3. Full challenge list by severity
4. Regulatory verification results

Proceed immediately to Step 3 (Rectified Assessment).
