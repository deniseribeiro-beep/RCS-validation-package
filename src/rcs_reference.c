#include "rcs_reference.h"

#include <math.h>
#include <stddef.h>

static const double FLUID_WEIGHTS[5] = {30.0, 15.0, 10.0, 20.0, 25.0};
static const double SOLID_WEIGHTS[5] = {25.0, 25.0, 15.0, 20.0, 15.0};

const double *rcs_reference_weights(RCSMatrix matrix) {
    switch (matrix) {
        case RCS_MATRIX_FLUID:
            return FLUID_WEIGHTS;
        case RCS_MATRIX_SOLID:
            return SOLID_WEIGHTS;
        default:
            return NULL;
    }
}

static RCSGrade grade_from_rcs(double rcs) {
    if (rcs >= 90.0) return RCS_GRADE_A;
    if (rcs >= 80.0) return RCS_GRADE_B;
    if (rcs >= 65.0) return RCS_GRADE_C;
    if (rcs >= 50.0) return RCS_GRADE_D;
    return RCS_GRADE_E;
}

RCSStatus rcs_score_resolved(const RCSResolvedProfile *profile, RCSResult *result) {
    const double *weights;
    double p_bio = 0.0;
    size_t i;

    if (profile == NULL || result == NULL) {
        return RCS_STATUS_INVALID_ARGUMENT;
    }

    weights = rcs_reference_weights(profile->matrix);
    if (weights == NULL) {
        return RCS_STATUS_INVALID_MATRIX;
    }

    if (profile->governance != RCS_GOVERNANCE_FAIL &&
        profile->governance != RCS_GOVERNANCE_PASS) {
        return RCS_STATUS_INVALID_GOVERNANCE;
    }

    /* Governance precedes additive scoring in the scientific specification. */
    if (profile->governance == RCS_GOVERNANCE_FAIL) {
        result->p_bio = NAN;
        result->rcs = NAN;
        result->numeric_score_available = false;
        result->final_grade = RCS_GRADE_E;
        result->route = RCS_ROUTE_GOVERNANCE_FAILURE;
        return RCS_STATUS_OK;
    }

    for (i = 0; i < 5; ++i) {
        const double severity = profile->severity[i];
        if (!isfinite(severity) || severity < 0.0 || severity > 1.0) {
            return RCS_STATUS_INVALID_SEVERITY;
        }
        p_bio += weights[i] * severity;
    }

    result->p_bio = p_bio;
    result->rcs = 100.0 - p_bio;
    result->numeric_score_available = true;
    result->final_grade = grade_from_rcs(result->rcs);
    result->route = result->rcs < 50.0
        ? RCS_ROUTE_CRITICAL_PENALTY
        : RCS_ROUTE_SCORE_BASED;

    return RCS_STATUS_OK;
}

const char *rcs_grade_name(RCSGrade grade) {
    switch (grade) {
        case RCS_GRADE_A: return "Grade A";
        case RCS_GRADE_B: return "Grade B";
        case RCS_GRADE_C: return "Grade C";
        case RCS_GRADE_D: return "Grade D";
        case RCS_GRADE_E: return "Grade E";
        default: return "Unknown grade";
    }
}

const char *rcs_route_name(RCSRoute route) {
    switch (route) {
        case RCS_ROUTE_SCORE_BASED: return "Score-based certification";
        case RCS_ROUTE_CRITICAL_PENALTY: return "Critical penalty-burden condition";
        case RCS_ROUTE_GOVERNANCE_FAILURE: return "Governance failure";
        default: return "Unknown route";
    }
}

const char *rcs_status_name(RCSStatus status) {
    switch (status) {
        case RCS_STATUS_OK: return "OK";
        case RCS_STATUS_INVALID_ARGUMENT: return "Invalid argument";
        case RCS_STATUS_INVALID_MATRIX: return "Invalid matrix";
        case RCS_STATUS_INVALID_GOVERNANCE: return "Invalid governance decision";
        case RCS_STATUS_INVALID_SEVERITY: return "Invalid resolved severity";
        default: return "Unknown status";
    }
}
