# Step 4 — Discussion

## Overview

Interactive discussion with the user to resolve remaining uncertainties in Assessment 2.

**Input:** `<key>_<date>_assessment_2.json`
**Output:** `<key>_<date>_discussion.json` (Schema: discussion.schema.json)

---

## Critical Instruction

**The tool initiates this discussion.** Do not wait passively for user input. After presenting Assessment 2, immediately identify and begin asking about unresolved points.

---

## Identifying Unresolved Points

Scan Assessment 2 for:

| Point Type | How to Identify |
|------------|-----------------|
| `internal_fact_unknown` | Facts about firm's internal operations that couldn't be confirmed (e.g., whether a function is in-house or outsourced, whether a policy exists, who holds a role, reporting lines) |
| `control_effectiveness_uncertain` | Controls with `effectiveness: "Uncertain"` or `requires_verification: true` |
| `data_quality_issue` | Missing or misclassified tickets in the risk register |
| `judgment_based_rating` | Ratings where the user's knowledge of internal environment may shift the assessment |
| `regulatory_verification_needed` | Regulatory references the user may know to be outdated or inapplicable |

---

## Discussion Protocol

### One Question at a Time

1. Present the single most important unresolved question first
2. Wait for the user's response
3. Process the response (including any necessary web searches or follow-up analysis)
4. Ask any follow-up questions before moving to the next original question
5. Update the discussion log after each exchange

### User-Initiated Input

The user may also:
- Raise their own challenges
- Provide unsolicited information
- Disagree with ratings
- Request changes

Address these before returning to the question sequence.

---

## Discussion JSON Structure

Initialise at start of Step 4:

```json
{
  "metadata": {
    "ticket_key": "RR-220",
    "discussion_date": "2026-03-29",
    "source_assessment": "rr-220_2026-03-29_assessment_2.json",
    "started_at": "14:45:00",
    "completed_at": null
  },
  "unresolved_points": [
    {
      "id": "UP001",
      "point_type": "control_effectiveness_uncertain",
      "section": "existing_controls",
      "description": "Control C003 (incident response procedure) effectiveness cannot be confirmed from available information.",
      "question_posed": "Does Chocolate Finance have a documented incident response procedure, and has it been tested in the past 12 months?",
      "status": "pending",
      "resolution": null,
      "assessment_impact": null
    }
  ],
  "exchanges": [],
  "user_challenges": [],
  "status": {
    "total_unresolved": 3,
    "resolved_count": 0,
    "pending_count": 3,
    "deferred_count": 0,
    "user_challenges_count": 0,
    "discussion_complete": false,
    "completion_reason": null
  }
}
```

---

## Recording Exchanges

After each exchange, add to the `exchanges` array:

```json
{
  "id": "EX001",
  "timestamp": "14:46:00",
  "exchange_type": "question_to_user",
  "related_point_id": "UP001",
  "content": "Does Chocolate Finance have a documented incident response procedure, and has it been tested in the past 12 months?",
  "speaker": "claude",
  "triggers_web_search": false,
  "web_search_result_summary": null,
  "assessment_change_triggered": null
}
```

When the user responds:

```json
{
  "id": "EX002",
  "timestamp": "14:48:00",
  "exchange_type": "user_response",
  "related_point_id": "UP001",
  "content": "Yes, we have an IRP documented in Confluence. It was last tested in October 2025 during a tabletop exercise.",
  "speaker": "user",
  "triggers_web_search": false,
  "web_search_result_summary": null,
  "assessment_change_triggered": {
    "section": "existing_controls",
    "change_type": "Control C003 effectiveness upgraded from Uncertain to Effective",
    "description": "User confirmed documented IRP with test in October 2025"
  }
}
```

---

## Handling User Challenges

If the user disagrees with something:

```json
{
  "id": "UC001",
  "challenge": "I don't think the residual risk should be Medium. We have strong controls.",
  "related_section": "residual_risk",
  "response": "The Medium rating reflects that while controls exist, their effectiveness for two controls (C002, C004) could not be independently verified. If you can confirm these controls are operating effectively, the rating could be reduced to Low.",
  "outcome": "partially_accepted",
  "assessment_change": "Residual risk rationale updated to note user's confidence in control effectiveness"
}
```

---

## Completion Conditions

The discussion continues until:

1. **All points resolved** — Every unresolved point has `status: "resolved"` or `status: "deferred"`
2. **User requests progression** — User explicitly says to proceed to Step 5
3. **Deferred to risk owner** — Points require input from someone not in the conversation

Update the status:

```json
{
  "status": {
    "total_unresolved": 3,
    "resolved_count": 2,
    "pending_count": 0,
    "deferred_count": 1,
    "user_challenges_count": 1,
    "discussion_complete": true,
    "completion_reason": "user_requested_progression"
  }
}
```

---

## Output

**Save as:** `<key>_<date>_discussion.json`

Update the file after each exchange. When complete, proceed to Step 5.
