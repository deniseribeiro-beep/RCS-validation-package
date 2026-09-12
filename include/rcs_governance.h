#ifndef RCS_GOVERNANCE_H
#define RCS_GOVERNANCE_H

#include "rcs_reference.h"

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    RCS_GOV_EVIDENCE_UNSET = 0,
    RCS_GOV_EVIDENCE_SATISFIED = 1,
    RCS_GOV_EVIDENCE_FAILED = 2,
    RCS_GOV_EVIDENCE_UNRESOLVED = 3,
    RCS_GOV_EVIDENCE_NOT_APPLICABLE = 4
} RCSGovernanceEvidenceState;

typedef enum {
    RCS_GOV_DISPOSITION_NONE = 0,
    RCS_GOV_DISPOSITION_TECHNICAL_REVIEW = 1,
    RCS_GOV_DISPOSITION_RESTRICT = 2,
    RCS_GOV_DISPOSITION_QUARANTINE = 3,
    RCS_GOV_DISPOSITION_GATE_FAILURE = 4
} RCSGovernanceDisposition;

typedef enum {
    RCS_GOV_SAMPLE_LEVEL_METADATA = 0,
    RCS_GOV_DONOR_SOURCE_LINKAGE = 1,
    RCS_GOV_COLLECTION_CONTEXT = 2,
    RCS_GOV_EVENT_LEVEL_METADATA = 3,
    RCS_GOV_METADATA_COMPLETENESS = 4,
    RCS_GOV_QUALITY_MANAGEMENT = 5,
    RCS_GOV_TRACEABILITY = 6,
    RCS_GOV_NONCONFORMITY_CONTROL = 7,
    RCS_GOV_DATA_RELIABILITY = 8,
    RCS_GOV_BIOSPECIMEN_HANDLING = 9,
    RCS_GOV_STORAGE_MONITORING = 10,
    RCS_GOV_DOCUMENTATION_SOPS = 11,
    RCS_GOV_DEVIATION_DOCUMENTATION = 12,
    RCS_GOV_SEMANTIC_CONTEXT_VALIDITY = 13,
    RCS_GOV_EVIDENCE_COUNT = 14
} RCSGovernanceEvidenceCategory;

typedef struct {
    RCSGovernanceEvidenceState state;
    RCSGovernanceDisposition disposition;
} RCSGovernanceEvidence;

typedef struct {
    RCSGovernanceEvidence evidence[RCS_GOV_EVIDENCE_COUNT];
    bool thermal_control_relevant;
} RCSGovernanceProfile;

typedef enum {
    RCS_GOV_OUTCOME_ADMISSIBLE = 0,
    RCS_GOV_OUTCOME_REVIEW_REQUIRED = 1,
    RCS_GOV_OUTCOME_RESTRICTED = 2,
    RCS_GOV_OUTCOME_QUARANTINED = 3,
    RCS_GOV_OUTCOME_FAILED = 4
} RCSGovernanceOutcome;

typedef enum {
    RCS_GOV_STATUS_OK = 0,
    RCS_GOV_STATUS_INVALID_ARGUMENT = 1,
    RCS_GOV_STATUS_MISSING_EXPLICIT_EVIDENCE = 2,
    RCS_GOV_STATUS_INVALID_EVIDENCE_STATE = 3,
    RCS_GOV_STATUS_INVALID_DISPOSITION = 4,
    RCS_GOV_STATUS_INVALID_NOT_APPLICABLE = 5,
    RCS_GOV_STATUS_DISPOSITION_REQUIRED = 6
} RCSGovernanceStatus;

typedef struct {
    RCSGovernanceOutcome outcome;
    bool admissible;
    bool gate_failure;
    bool technical_review_required;
    bool restriction_required;
    bool quarantine_required;
    uint32_t blocking_mask;
    uint32_t review_mask;
    uint32_t restriction_mask;
    uint32_t quarantine_mask;
    unsigned int satisfied_count;
    unsigned int failed_count;
    unsigned int unresolved_count;
    unsigned int not_applicable_count;
} RCSGovernanceResult;

/* Initialize all evidence to UNSET. Callers must then set every evidence item
 * explicitly; no missing field is ever interpreted as satisfied. */
void rcs_governance_profile_init(RCSGovernanceProfile *profile);

/* Evaluate the Supplementary File 2, Table S1 metadata-governance layer.
 * Only RCS_GOV_OUTCOME_ADMISSIBLE maps to a passing binary governance gate.
 * Review, restriction, quarantine, and failure outcomes are non-admissible for
 * additive RCS scoring until resolved by the upstream governance process. */
RCSGovernanceStatus rcs_governance_evaluate(
    const RCSGovernanceProfile *profile,
    RCSGovernanceResult *result
);

RCSGovernanceDecision rcs_governance_binary_decision(const RCSGovernanceResult *result);

const char *rcs_governance_category_name(RCSGovernanceEvidenceCategory category);
const char *rcs_governance_evidence_state_name(RCSGovernanceEvidenceState state);
const char *rcs_governance_disposition_name(RCSGovernanceDisposition disposition);
const char *rcs_governance_outcome_name(RCSGovernanceOutcome outcome);
const char *rcs_governance_status_name(RCSGovernanceStatus status);

#ifdef __cplusplus
}
#endif

#endif
