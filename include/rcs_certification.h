#ifndef RCS_CERTIFICATION_H
#define RCS_CERTIFICATION_H

#include "rcs_governance.h"
#include "rcs_reference.h"
#include "rcs_sprec.h"
#include "rcs_sprec_reference.h"

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RCS_SPREC_COMPONENT_COUNT 7
#define RCS_SCORE_AXIS_COUNT 5

typedef enum {
    RCS_CERT_STATUS_OK = 0,
    RCS_CERT_STATUS_INVALID_ARGUMENT = 1,
    RCS_CERT_STATUS_INVALID_MATRIX = 2,
    RCS_CERT_STATUS_GOVERNANCE_INPUT_ERROR = 3,
    RCS_CERT_STATUS_GOVERNANCE_NOT_ADMISSIBLE = 4,
    RCS_CERT_STATUS_SPREC_NOT_SCORABLE = 5,
    RCS_CERT_STATUS_SCORING_ERROR = 6
} RCSCertificationStatus;

typedef struct {
    RCSMatrix matrix;
    const char *sprec[RCS_SPREC_COMPONENT_COUNT];
    RCSSprecContext sprec_context;
    RCSGovernanceProfile governance;
} RCSCertificationInput;

typedef struct {
    RCSCertificationStatus status;
    RCSSprecCodeStatus sprec_reference_status[RCS_SPREC_COMPONENT_COUNT];
    RCSSprecResolution axis_resolution[RCS_SCORE_AXIS_COUNT];
    RCSGovernanceResult governance;
    RCSGovernanceStatus governance_status;
    RCSResult score;
    bool score_available;
    bool sprec_gate_failure;
    int first_unscorable_position;
    int first_unscorable_axis;
} RCSCertificationResult;

/*
 * Complete reference certification path:
 * raw SPREC 2.0 components + explicit context + explicit governance evidence
 * -> SPREC vocabulary validation -> governance aggregation -> severity resolution
 * -> weighted RCS scoring.
 *
 * Any non-standard/unresolved SPREC condition remains non-additive and routes
 * through the non-compensable governance-failure result. No missing evidence is
 * promoted to satisfied and no Not-scored condition is converted to severity 0.
 */
RCSCertificationStatus rcs_certify(
    const RCSCertificationInput *input,
    RCSCertificationResult *result
);

void rcs_certification_input_init(RCSCertificationInput *input, RCSMatrix matrix);
const char *rcs_certification_status_name(RCSCertificationStatus status);

#ifdef __cplusplus
}
#endif

#endif
