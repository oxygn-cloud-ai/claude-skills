# Quality Standards

Rules, constraints, and operational requirements for all assessments.

---

## Mandatory Requirements

1. **Grounded assertions.** Every assertion about Chocolate Finance's business must be grounded in confirmed facts (from business-context.md, the Jira register, web search, or user-provided information). Do not fabricate internal details.

2. **Verified regulatory citations.** Every regulatory reference must cite the correct instrument title and date. If uncertain, search the web to verify before including.

3. **Explicit uncertainty.** Where internal controls cannot be confirmed, state this explicitly. Do not infer effectiveness without evidence.

4. **Complete evidences section.** The Evidences section must be present in every assessment and must accurately represent the evidential basis.

5. **British English.** Use British English exclusively.

6. **Schema compliance.** All JSON outputs must validate against their respective schemas. Non-conforming values for enum fields must be rejected.

---

## Prohibited Actions

1. **Do not modify the parent Risk item's** description, status, priority, or any other field.

2. **Do not modify existing** Mitigation or Review child tickets.

3. **Do not assign tickets** unless instructed by the user.

4. **Do not fabricate** regulatory citations, enforcement actions, or penalties.

5. **Do not use a risk rating** that does not follow the matrix defined in the schema.

6. **Do not proceed past Step 4** without user confirmation of the final assessment.

---

## Risk Rating Matrix

| | **Low Impact** | **Medium Impact** | **High Impact** |
|---|---|---|---|
| **High Likelihood** | Medium | High | Critical |
| **Medium Likelihood** | Low | Medium | High |
| **Low Likelihood** | Low | Low | Medium |

Use this matrix consistently. Do not introduce alternative rating scales.

**Validation rule:** If `inherent_risk.rating` or `residual_risk.rating` does not match the matrix derivation from the stated likelihood and impact, the assessment is invalid.

---

## Batch Operations

When the user requests reviews of multiple risk items (e.g., 'review all Technology risks', 'review RR-220 through RR-240'):

1. Proceed sequentially — complete all steps for one risk before moving to the next
2. Step 4 (Discussion) applies per-item; the user may choose to abbreviate discussion on some items
3. If a batch exceeds **10 items**, confirm with the user before proceeding past the first 10

---

## User-Provided Scenarios

The user may provide a specific situation, business change, or incident rather than a ticket key. In this case:

1. Search the risk register for the parent Risk item(s) most relevant to the scenario
2. Present the matched risk item(s) to the user for confirmation
3. Proceed through all steps with the scenario woven into the Context section and adjusting likelihood and impact assessments accordingly

If no existing risk item adequately captures the scenario:
- Inform the user
- Ask whether they wish to create a new Risk item or assess against the closest existing match

---

## File Inventory

Each completed review produces the following JSON files:

| Step | Filename Pattern | Schema |
|------|------------------|--------|
| 1c | `<key>_export.json` | jira-export.schema.json |
| 1d | `<key>_<date>_assessment_1.json` | assessment.schema.json |
| 2 | `<key>_<date>_adversarial_review.json` | adversarial-review.schema.json |
| 3 | `<key>_<date>_assessment_2.json` | assessment.schema.json |
| 4 | `<key>_<date>_discussion.json` | discussion.schema.json |
| 5 | `<key>_<date>_assessment_final.json` | assessment.schema.json |
| 6 | `<key>_<date>_jira_ticket.json` | jira-ticket.schema.json |

**Filename format:**
- `<key>`: Ticket key in lowercase with hyphen (e.g., `rr-220`)
- `<date>`: ISO date format `yyyy-mm-dd` (e.g., `2026-03-29`)

**Example:** `rr-220_2026-03-29_assessment_1.json`

All files are saved to the output directory (`$RR_OUTPUT_DIR`, default: `~/rr-output/`).

---

## Markdown Rendering

Markdown is rendered on-demand from JSON for:
- User presentation (during workflow)
- Jira ticket description (Step 6)

### Rendering Rules

1. **Header section** renders as H2 with metadata table
2. **Context section** renders as narrative prose
3. **Regulatory framework** renders as numbered list with instrument details
4. **Risk assessments** render as definition lists (Likelihood: X, Impact: Y, Rating: Z)
5. **Controls** render as numbered list with effectiveness badges
6. **Recommendations** render as numbered action items with priority indicators
7. **Evidences** render as three subsections: Used, Unavailable, Caveats

### Rating Badges

| Rating | Badge |
|--------|-------|
| Critical | 🔴 Critical |
| High | 🟠 High |
| Medium | 🟡 Medium |
| Low | 🟢 Low |

---

## Evidence Standards

### Sources Used — Required Fields

| Field | Required |
|-------|----------|
| source_type | Yes |
| description | Yes |
| url | If applicable |
| retrieved_date | If web search |

### Valid Source Types

| Type | Description |
|------|-------------|
| `jira_register` | Information from the RR project |
| `web_search` | Information retrieved via web search |
| `user_provided` | Information provided by the user in discussion |
| `regulatory_publication` | Official regulatory document |
| `company_disclosure` | Public company information |
| `skill_context` | Information from business-context.md |

---

## Validation Checkpoints

Before proceeding to each step, validate:

| Checkpoint | Validation |
|------------|------------|
| Before Step 2 | Assessment 1 JSON validates against assessment.schema.json |
| Before Step 3 | Adversarial review JSON validates against adversarial-review.schema.json |
| Before Step 4 | Assessment 2 JSON validates against assessment.schema.json |
| Before Step 5 | Discussion JSON validates against discussion.schema.json |
| Before Step 6 | Final assessment JSON validates against assessment.schema.json |
| Before Jira create/update | Jira ticket JSON validates against jira-ticket.schema.json |

If validation fails, halt and report the validation error to the user.
