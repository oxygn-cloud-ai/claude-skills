# Step 3 — Rectified Assessment

## Overview

Revise Assessment 1 to address every finding from the Adversarial Review.

**Inputs:**
- `<key>_<date>_assessment_1.json`
- `<key>_<date>_adversarial_review.json`

**Output:** `<key>_<date>_assessment_2.json` (Schema: assessment.schema.json)

---

## Resolution Process

For each challenge in the adversarial review, either:

### Option A: Correct the Assessment
- Modify the relevant section
- Add or strengthen evidence
- Update ratings if warranted
- Record the change in `changes_from_previous`

### Option B: Retain with Justification
- Explain why the original position is retained despite the challenge
- Provide additional reasoning
- Record in `changes_from_previous` with `change_type: "retained_with_justification"`

---

## Changes Tracking

Assessment 2 must include the `changes_from_previous` object:

```json
{
  "changes_from_previous": {
    "summary": "Addressed 7 challenges from adversarial review: 5 corrected, 2 retained with justification.",
    "changes": [
      {
        "section": "inherent_risk",
        "change_type": "corrected",
        "previous_value": "Likelihood: Medium (based on industry trends)",
        "new_value": "Likelihood: Medium (based on Chocolate Finance's rapid growth phase and the miles programme incident demonstrating communication risk)",
        "description": "Added firm-specific justification for Medium likelihood",
        "triggered_by": "adversarial_review"
      },
      {
        "section": "existing_controls",
        "change_type": "corrected",
        "previous_value": "C003 effectiveness: Effective",
        "new_value": "C003 effectiveness: Uncertain, requires_verification: true",
        "description": "Changed to Uncertain as effectiveness cannot be confirmed from available information",
        "triggered_by": "adversarial_review"
      },
      {
        "section": "regulatory_framework",
        "change_type": "retained_with_justification",
        "previous_value": "Guidelines on Outsourcing cited as tangentially relevant",
        "new_value": "Guidelines on Outsourcing retained",
        "description": "Retained because the risk involves third-party service providers, making outsourcing guidelines directly relevant even if not the primary framework",
        "triggered_by": "adversarial_review"
      }
    ]
  }
}
```

---

## Change Types (Enum)

| Type | When to Use |
|------|-------------|
| `corrected` | Original was wrong; now fixed |
| `expanded` | Original was incomplete; now has more detail |
| `removed` | Original content was inappropriate; now deleted |
| `rating_changed` | Likelihood, impact, or overall rating changed |
| `retained_with_justification` | Original retained; justification added |

---

## Metadata Updates

Update the metadata to reflect iteration 2:

```json
{
  "metadata": {
    "ticket_key": "RR-220",
    "assessment_date": "2026-03-29",
    "iteration": 2,
    "status": "rectified",
    "previous_iteration_ref": "rr-220_2026-03-29_assessment_1.json",
    "assessor": "Claude (Anthropic)"
  }
}
```

---

## Validation

Before proceeding to Step 4, verify:

1. Every challenge from the adversarial review is addressed in `changes_from_previous`
2. All corrections are reflected in the relevant sections
3. New evidence sources are added to `evidences.sources_used`
4. Ratings still conform to the matrix
5. All enum values remain valid

---

## Output

**Save as:** `<key>_<date>_assessment_2.json`

Present to user with:
1. Summary of changes made
2. Full rectified assessment (rendered to markdown)

Then proceed immediately to Step 4 (Discussion).
