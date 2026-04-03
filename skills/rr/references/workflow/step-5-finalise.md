# Step 5 — Final Assessment

## Overview

Revise Assessment 2 based on the outcomes of the Step 4 discussion, producing the final assessment ready for Jira.

**Inputs:**
- `<key>_<date>_assessment_2.json`
- `<key>_<date>_discussion.json`

**Output:** `<key>_<date>_assessment_final.json` (Schema: assessment.schema.json)

---

## Incorporating Discussion Outcomes

For each resolved point in the discussion:

1. Update the relevant section of the assessment
2. Record the change in `changes_from_previous`
3. Add any new evidence sources to `evidences.sources_used` with `source_type: "user_provided"`

For each user challenge that was accepted or partially accepted:

1. Apply the agreed change
2. Record in `changes_from_previous`

For deferred points:

1. Retain current assessment position
2. Note in `evidences.caveats` that the point remains unresolved

---

## Changes Tracking

The final assessment must track changes from Assessment 2:

```json
{
  "changes_from_previous": {
    "summary": "Incorporated 2 resolved points and 1 user challenge from discussion.",
    "changes": [
      {
        "section": "existing_controls",
        "change_type": "corrected",
        "previous_value": "C003 effectiveness: Uncertain",
        "new_value": "C003 effectiveness: Effective",
        "description": "User confirmed documented IRP tested in October 2025",
        "triggered_by": "user_input"
      },
      {
        "section": "residual_risk",
        "change_type": "rating_changed",
        "previous_value": "Rating: Medium",
        "new_value": "Rating: Low",
        "description": "Upgraded following confirmation of control effectiveness",
        "triggered_by": "user_input"
      }
    ]
  }
}
```

---

## Metadata Updates

Update metadata to reflect final iteration:

```json
{
  "metadata": {
    "ticket_key": "RR-220",
    "assessment_date": "2026-03-29",
    "iteration": 3,
    "status": "final",
    "previous_iteration_ref": "rr-220_2026-03-29_assessment_2.json",
    "assessor": "Claude (Anthropic)"
  }
}
```

---

## Validation

Before presenting to user, verify:

1. All resolved discussion points are reflected in the assessment
2. All user challenges marked as `accepted_change` or `partially_accepted` are applied
3. Ratings conform to the matrix
4. All enum values are valid
5. Evidences section includes `user_provided` sources where applicable
6. Caveats note any deferred points

---

## User Confirmation

**Do not proceed to Step 6 without explicit user confirmation.**

Present the final assessment (rendered to markdown) and ask:

> "This is the final assessment ready for the Jira review ticket. Please confirm you're happy to proceed, or let me know if any changes are needed."

Wait for confirmation before proceeding.

---

## Output

**Save as:** `<key>_<date>_assessment_final.json`

Once confirmed, proceed to Step 6.
