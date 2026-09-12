#include "rcs_governance.h"

#include <stddef.h>
#include <string.h>

typedef enum {
    POLICY_REQUIRED = 0,
    POLICY_SUPPORTING_REVIEW = 1,
    POLICY_EXPLICIT_DISPOSITION = 2,
    POLICY_CONDITIONAL_REQUIRED = 3
} GovernancePolicy;

static const GovernancePolicy GOVERNANCE_POLICY[RCS_GOV_EVIDENCE_COUNT] = {
    POLICY_REQUIRED,             /* sample-level metadata */
    POLICY_REQUIRED,             /* donor/source linkage */
    POLICY_REQUIRED,             /* collection context */
    POLICY_REQUIRED,             /* event-level metadata */
    POLICY_REQUIRED,             /* metadata completeness */
    POLICY_SUPPORTING_REVIEW,    /* quality management */
    POLICY_REQUIRED,             /* traceability */
    POLICY_EXPLICIT_DISPOSITION, /* nonconformity control */
    POLICY_REQUIRED,             /* data reliability */
    POLICY_SUPPORTING_REVIEW,    /* biospecimen handling */
    POLICY_CONDITIONAL_REQUIRED, /* storage monitoring */
    POLICY_SUPPORTING_REVIEW,    /* documentation and SOPs */
    POLICY_EXPLICIT_DISPOSITION, /* deviation documentation */
    POLICY_EXPLICIT_DISPOSITION  /* semantic validity/context compatibility */
};

static uint32_t bit_for(size_t index) {
    return ((uint32_t)1u) << index;
}

static int state_valid(RCSGovernanceEvidenceState state) {
    return state >= RCS_GOV_EVIDENCE_UNSET && state <= RCS_GOV_EVIDENCE_NOT_APPLICABLE;
}

static int disposition_valid(RCSGovernanceDisposition disposition) {
    return disposition >= RCS_GOV_DISPOSITION_NONE && disposition <= RCS_GOV_DISPOSITION_GATE_FAILURE;
}

void rcs_governance_profile_init(RCSGovernanceProfile *profile) {
    size_t i;
    if (profile == NULL) return;
    memset(profile, 0, sizeof(*profile));
    for (i = 0; i < RCS_GOV_EVIDENCE_COUNT; ++i) {
        profile->evidence[i].state = RCS_GOV_EVIDENCE_UNSET;
        profile->evidence[i].disposition = RCS_GOV_DISPOSITION_NONE;
    }
    profile->thermal_control_relevant = false;
}

static void apply_disposition(
    RCSGovernanceResult *result,
    size_t index,
    RCSGovernanceDisposition disposition
) {
    const uint32_t bit = bit_for(index);
    switch (disposition) {
        case RCS_GOV_DISPOSITION_TECHNICAL_REVIEW:
            result->technical_review_required = true;
            result->review_mask |= bit;
            result->blocking_mask |= bit;
            break;
        case RCS_GOV_DISPOSITION_RESTRICT:
            result->restriction_required = true;
            result->restriction_mask |= bit;
            result->blocking_mask |= bit;
            break;
        case RCS_GOV_DISPOSITION_QUARANTINE:
            result->quarantine_required = true;
            result->quarantine_mask |= bit;
            result->blocking_mask |= bit;
            break;
        case RCS_GOV_DISPOSITION_GATE_FAILURE:
            result->gate_failure = true;
            result->blocking_mask |= bit;
            break;
        case RCS_GOV_DISPOSITION_NONE:
        default:
            break;
    }
}

static void apply_required_failure(RCSGovernanceResult *result, size_t index) {
    result->gate_failure = true;
    result->blocking_mask |= bit_for(index);
}

static void apply_supporting_review(RCSGovernanceResult *result, size_t index) {
    result->technical_review_required = true;
    result->review_mask |= bit_for(index);
    result->blocking_mask |= bit_for(index);
}

RCSGovernanceStatus rcs_governance_evaluate(
    const RCSGovernanceProfile *profile,
    RCSGovernanceResult *result
) {
    size_t i;

    if (profile == NULL || result == NULL) return RCS_GOV_STATUS_INVALID_ARGUMENT;
    memset(result, 0, sizeof(*result));
    result->outcome = RCS_GOV_OUTCOME_FAILED;

    for (i = 0; i < RCS_GOV_EVIDENCE_COUNT; ++i) {
        const RCSGovernanceEvidence evidence = profile->evidence[i];
        const GovernancePolicy policy = GOVERNANCE_POLICY[i];

        if (!state_valid(evidence.state)) return RCS_GOV_STATUS_INVALID_EVIDENCE_STATE;
        if (!disposition_valid(evidence.disposition)) return RCS_GOV_STATUS_INVALID_DISPOSITION;
        if (evidence.state == RCS_GOV_EVIDENCE_UNSET)
            return RCS_GOV_STATUS_MISSING_EXPLICIT_EVIDENCE;

        if (evidence.state == RCS_GOV_EVIDENCE_SATISFIED) result->satisfied_count++;
        else if (evidence.state == RCS_GOV_EVIDENCE_FAILED) result->failed_count++;
        else if (evidence.state == RCS_GOV_EVIDENCE_UNRESOLVED) result->unresolved_count++;
        else if (evidence.state == RCS_GOV_EVIDENCE_NOT_APPLICABLE) result->not_applicable_count++;

        if (evidence.state == RCS_GOV_EVIDENCE_NOT_APPLICABLE) {
            if (i == RCS_GOV_STORAGE_MONITORING && !profile->thermal_control_relevant) {
                if (evidence.disposition != RCS_GOV_DISPOSITION_NONE)
                    return RCS_GOV_STATUS_INVALID_DISPOSITION;
                continue;
            }
            return RCS_GOV_STATUS_INVALID_NOT_APPLICABLE;
        }

        if (evidence.state == RCS_GOV_EVIDENCE_SATISFIED) {
            if (evidence.disposition != RCS_GOV_DISPOSITION_NONE)
                return RCS_GOV_STATUS_INVALID_DISPOSITION;
            continue;
        }

        switch (policy) {
            case POLICY_REQUIRED:
                if (evidence.disposition != RCS_GOV_DISPOSITION_NONE &&
                    evidence.disposition != RCS_GOV_DISPOSITION_GATE_FAILURE)
                    return RCS_GOV_STATUS_INVALID_DISPOSITION;
                apply_required_failure(result, i);
                break;

            case POLICY_CONDITIONAL_REQUIRED:
                if (!profile->thermal_control_relevant) {
                    return RCS_GOV_STATUS_INVALID_NOT_APPLICABLE;
                }
                if (evidence.disposition != RCS_GOV_DISPOSITION_NONE &&
                    evidence.disposition != RCS_GOV_DISPOSITION_GATE_FAILURE)
                    return RCS_GOV_STATUS_INVALID_DISPOSITION;
                apply_required_failure(result, i);
                break;

            case POLICY_SUPPORTING_REVIEW:
                if (evidence.disposition != RCS_GOV_DISPOSITION_NONE &&
                    evidence.disposition != RCS_GOV_DISPOSITION_TECHNICAL_REVIEW)
                    return RCS_GOV_STATUS_INVALID_DISPOSITION;
                apply_supporting_review(result, i);
                break;

            case POLICY_EXPLICIT_DISPOSITION:
                if (evidence.disposition == RCS_GOV_DISPOSITION_NONE)
                    return RCS_GOV_STATUS_DISPOSITION_REQUIRED;
                apply_disposition(result, i, evidence.disposition);
                break;

            default:
                return RCS_GOV_STATUS_INVALID_ARGUMENT;
        }
    }

    result->admissible = !result->gate_failure &&
                         !result->technical_review_required &&
                         !result->restriction_required &&
                         !result->quarantine_required;

    if (result->gate_failure) result->outcome = RCS_GOV_OUTCOME_FAILED;
    else if (result->quarantine_required) result->outcome = RCS_GOV_OUTCOME_QUARANTINED;
    else if (result->restriction_required) result->outcome = RCS_GOV_OUTCOME_RESTRICTED;
    else if (result->technical_review_required) result->outcome = RCS_GOV_OUTCOME_REVIEW_REQUIRED;
    else result->outcome = RCS_GOV_OUTCOME_ADMISSIBLE;

    return RCS_GOV_STATUS_OK;
}

RCSGovernanceDecision rcs_governance_binary_decision(const RCSGovernanceResult *result) {
    if (result != NULL && result->admissible) return RCS_GOVERNANCE_PASS;
    return RCS_GOVERNANCE_FAIL;
}

const char *rcs_governance_category_name(RCSGovernanceEvidenceCategory category) {
    static const char *const names[RCS_GOV_EVIDENCE_COUNT] = {
        "Sample-level metadata",
        "Donor or source linkage",
        "Collection context",
        "Event-level metadata",
        "Metadata completeness",
        "Quality management",
        "Traceability",
        "Nonconformity control",
        "Data reliability",
        "Biospecimen handling",
        "Storage monitoring",
        "Documentation and SOPs",
        "Deviation documentation",
        "Semantic validity and context compatibility"
    };
    if (category < 0 || category >= RCS_GOV_EVIDENCE_COUNT) return "Unknown governance category";
    return names[category];
}

const char *rcs_governance_evidence_state_name(RCSGovernanceEvidenceState state) {
    switch (state) {
        case RCS_GOV_EVIDENCE_UNSET: return "UNSET";
        case RCS_GOV_EVIDENCE_SATISFIED: return "SATISFIED";
        case RCS_GOV_EVIDENCE_FAILED: return "FAILED";
        case RCS_GOV_EVIDENCE_UNRESOLVED: return "UNRESOLVED";
        case RCS_GOV_EVIDENCE_NOT_APPLICABLE: return "NOT_APPLICABLE";
        default: return "UNKNOWN";
    }
}

const char *rcs_governance_disposition_name(RCSGovernanceDisposition disposition) {
    switch (disposition) {
        case RCS_GOV_DISPOSITION_NONE: return "NONE";
        case RCS_GOV_DISPOSITION_TECHNICAL_REVIEW: return "TECHNICAL_REVIEW";
        case RCS_GOV_DISPOSITION_RESTRICT: return "RESTRICT";
        case RCS_GOV_DISPOSITION_QUARANTINE: return "QUARANTINE";
        case RCS_GOV_DISPOSITION_GATE_FAILURE: return "GATE_FAILURE";
        default: return "UNKNOWN";
    }
}

const char *rcs_governance_outcome_name(RCSGovernanceOutcome outcome) {
    switch (outcome) {
        case RCS_GOV_OUTCOME_ADMISSIBLE: return "ADMISSIBLE";
        case RCS_GOV_OUTCOME_REVIEW_REQUIRED: return "REVIEW_REQUIRED";
        case RCS_GOV_OUTCOME_RESTRICTED: return "RESTRICTED";
        case RCS_GOV_OUTCOME_QUARANTINED: return "QUARANTINED";
        case RCS_GOV_OUTCOME_FAILED: return "FAILED";
        default: return "UNKNOWN";
    }
}

const char *rcs_governance_status_name(RCSGovernanceStatus status) {
    switch (status) {
        case RCS_GOV_STATUS_OK: return "OK";
        case RCS_GOV_STATUS_INVALID_ARGUMENT: return "Invalid argument";
        case RCS_GOV_STATUS_MISSING_EXPLICIT_EVIDENCE: return "Missing explicit governance evidence";
        case RCS_GOV_STATUS_INVALID_EVIDENCE_STATE: return "Invalid governance evidence state";
        case RCS_GOV_STATUS_INVALID_DISPOSITION: return "Invalid governance disposition";
        case RCS_GOV_STATUS_INVALID_NOT_APPLICABLE: return "Invalid Not Applicable governance state";
        case RCS_GOV_STATUS_DISPOSITION_REQUIRED: return "Explicit governance disposition required";
        default: return "Unknown governance status";
    }
}
