#ifndef RCS_REFERENCE_H
#define RCS_REFERENCE_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    RCS_MATRIX_FLUID = 0,
    RCS_MATRIX_SOLID = 1
} RCSMatrix;

typedef enum {
    RCS_GOVERNANCE_FAIL = 0,
    RCS_GOVERNANCE_PASS = 1
} RCSGovernanceDecision;

typedef enum {
    RCS_GRADE_A = 0,
    RCS_GRADE_B = 1,
    RCS_GRADE_C = 2,
    RCS_GRADE_D = 3,
    RCS_GRADE_E = 4
} RCSGrade;

typedef enum {
    RCS_ROUTE_SCORE_BASED = 0,
    RCS_ROUTE_CRITICAL_PENALTY = 1,
    RCS_ROUTE_GOVERNANCE_FAILURE = 2
} RCSRoute;

typedef enum {
    RCS_STATUS_OK = 0,
    RCS_STATUS_INVALID_ARGUMENT = 1,
    RCS_STATUS_INVALID_MATRIX = 2,
    RCS_STATUS_INVALID_GOVERNANCE = 3,
    RCS_STATUS_INVALID_SEVERITY = 4
} RCSStatus;

typedef struct {
    RCSMatrix matrix;
    RCSGovernanceDecision governance;
    double severity[5];
} RCSResolvedProfile;

typedef struct {
    double p_bio;
    double rcs;
    bool numeric_score_available;
    RCSGrade final_grade;
    RCSRoute route;
} RCSResult;

/*
 * Returns the five matrix-specific maximum weights in scientific axis order.
 * Fluid: P_pre, P_cent1, P_cent2, P_post, P_store.
 * Solid: P_warm, P_cold, P_fix, P_fixTime, P_store.
 * Returns NULL for an invalid matrix.
 */
const double *rcs_reference_weights(RCSMatrix matrix);

/*
 * Reference scoring core for a profile whose SPREC severities and governance
 * decision have already been resolved by the higher-level scientific layers.
 *
 * Governance is non-compensable and is evaluated first. If governance fails,
 * the result is Grade E through RCS_ROUTE_GOVERNANCE_FAILURE, p_bio and rcs
 * are NAN, and numeric_score_available is false.
 *
 * If governance passes, every severity must be finite and within [0,1].
 */
RCSStatus rcs_score_resolved(const RCSResolvedProfile *profile, RCSResult *result);

const char *rcs_grade_name(RCSGrade grade);
const char *rcs_route_name(RCSRoute route);
const char *rcs_status_name(RCSStatus status);

#ifdef __cplusplus
}
#endif

#endif
