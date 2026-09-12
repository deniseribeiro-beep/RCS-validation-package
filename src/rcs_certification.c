#include "rcs_certification.h"

#include <math.h>
#include <string.h>

static const RCSSprecAxis FLUID_AXES[RCS_SCORE_AXIS_COUNT] = {
    RCS_SPREC_AXIS_P_PRE,
    RCS_SPREC_AXIS_P_CENT1,
    RCS_SPREC_AXIS_P_CENT2,
    RCS_SPREC_AXIS_P_POST,
    RCS_SPREC_AXIS_P_STORE
};

static const RCSSprecAxis SOLID_AXES[RCS_SCORE_AXIS_COUNT] = {
    RCS_SPREC_AXIS_P_WARM,
    RCS_SPREC_AXIS_P_COLD,
    RCS_SPREC_AXIS_P_FIX,
    RCS_SPREC_AXIS_P_FIX_TIME,
    RCS_SPREC_AXIS_P_STORE
};

static void initialize_result(RCSCertificationResult *result) {
    size_t i;
    memset(result, 0, sizeof(*result));
    result->status = RCS_CERT_STATUS_INVALID_ARGUMENT;
    result->governance_status = RCS_GOV_STATUS_INVALID_ARGUMENT;
    result->score.p_bio = NAN;
    result->score.rcs = NAN;
    result->score.numeric_score_available = false;
    result->score.final_grade = RCS_GRADE_E;
    result->score.route = RCS_ROUTE_GOVERNANCE_FAILURE;
    result->first_unscorable_position = -1;
    result->first_unscorable_axis = -1;
    for (i = 0; i < RCS_SCORE_AXIS_COUNT; ++i) {
        result->axis_resolution[i].status = RCS_SPREC_NOT_SCORED;
        result->axis_resolution[i].severity = NAN;
    }
}

static RCSStatus set_governance_failure_score(RCSMatrix matrix, RCSResult *score) {
    RCSResolvedProfile profile;
    size_t i;
    profile.matrix = matrix;
    profile.governance = RCS_GOVERNANCE_FAIL;
    for (i = 0; i < RCS_SCORE_AXIS_COUNT; ++i) profile.severity[i] = NAN;
    return rcs_score_resolved(&profile, score);
}

void rcs_certification_input_init(RCSCertificationInput *input, RCSMatrix matrix) {
    size_t i;
    if (input == NULL) return;
    memset(input, 0, sizeof(*input));
    input->matrix = matrix;
    for (i = 0; i < RCS_SPREC_COMPONENT_COUNT; ++i) input->sprec[i] = NULL;
    input->sprec_context.primary_centrifugation = RCS_PRIMARY_CENT_CONTEXT_UNSPECIFIED;
    input->sprec_context.second_centrifugation = RCS_SECOND_CENT_CONTEXT_UNSPECIFIED;
    input->sprec_context.storage_temperature = RCS_STORAGE_TEMPERATURE_UNSPECIFIED;
    input->sprec_context.storage_workflow = RCS_STORAGE_WORKFLOW_UNSPECIFIED;
    input->sprec_context.fixation_workflow = RCS_FIXATION_WORKFLOW_UNSPECIFIED;
    input->sprec_context.semantic_compatibility = RCS_SEMANTIC_COMPATIBILITY_UNSPECIFIED;
    rcs_governance_profile_init(&input->governance);
}

RCSCertificationStatus rcs_certify(
    const RCSCertificationInput *input,
    RCSCertificationResult *result
) {
    const RCSSprecAxis *axes;
    RCSResolvedProfile resolved;
    size_t i;
    int reference_not_scorable = 0;

    if (result == NULL) return RCS_CERT_STATUS_INVALID_ARGUMENT;
    initialize_result(result);
    if (input == NULL) return result->status;

    if (input->matrix != RCS_MATRIX_FLUID && input->matrix != RCS_MATRIX_SOLID) {
        result->status = RCS_CERT_STATUS_INVALID_MATRIX;
        return result->status;
    }

    axes = input->matrix == RCS_MATRIX_FLUID ? FLUID_AXES : SOLID_AXES;

    /* Validate all seven raw SPREC components against Supplementary Tables S1/S2.
       Positions 1 and 2 are not additive axes, but unresolved/invalid values are
       still relevant to semantic/contextual admissibility. */
    for (i = 0; i < RCS_SPREC_COMPONENT_COUNT; ++i) {
        RCSSprecCodeStatus code_status = rcs_sprec_validate_reference_code(
            input->matrix, (RCSSprecPosition)i, input->sprec[i]
        );
        result->sprec_reference_status[i] = code_status;
        if (code_status != RCS_SPREC_CODE_STANDARD) {
            reference_not_scorable = 1;
            if (result->first_unscorable_position < 0)
                result->first_unscorable_position = (int)i;
        }
    }

    /* Governance evidence is always explicit. An invalid/incomplete governance
       profile is an input error, not a scientific result. */
    result->governance_status = rcs_governance_evaluate(
        &input->governance, &result->governance
    );
    if (result->governance_status != RCS_GOV_STATUS_OK) {
        result->status = RCS_CERT_STATUS_GOVERNANCE_INPUT_ERROR;
        return result->status;
    }

    if (!result->governance.admissible) {
        if (set_governance_failure_score(input->matrix, &result->score) != RCS_STATUS_OK) {
            result->status = RCS_CERT_STATUS_SCORING_ERROR;
            return result->status;
        }
        result->status = RCS_CERT_STATUS_GOVERNANCE_NOT_ADMISSIBLE;
        return result->status;
    }

    /* A raw SPREC component that is unknown/other/invalid/missing cannot be
       silently accepted merely because the supplied governance profile says
       semantic evidence is satisfied. It is a derived non-compensable failure. */
    if (reference_not_scorable) {
        result->sprec_gate_failure = true;
        if (set_governance_failure_score(input->matrix, &result->score) != RCS_STATUS_OK) {
            result->status = RCS_CERT_STATUS_SCORING_ERROR;
            return result->status;
        }
        result->status = RCS_CERT_STATUS_SPREC_NOT_SCORABLE;
        return result->status;
    }

    resolved.matrix = input->matrix;
    resolved.governance = RCS_GOVERNANCE_PASS;

    for (i = 0; i < RCS_SCORE_AXIS_COUNT; ++i) {
        const size_t sprec_position = i + 2u; /* score axes are SPREC positions 3..7 */
        const RCSSprecResolutionStatus resolution_status = rcs_sprec_resolve(
            input->matrix,
            axes[i],
            input->sprec[sprec_position],
            &input->sprec_context,
            &result->axis_resolution[i]
        );

        if (resolution_status != RCS_SPREC_RESOLVED) {
            result->sprec_gate_failure = true;
            result->first_unscorable_axis = (int)i;
            if (set_governance_failure_score(input->matrix, &result->score) != RCS_STATUS_OK) {
                result->status = RCS_CERT_STATUS_SCORING_ERROR;
                return result->status;
            }
            result->status = RCS_CERT_STATUS_SPREC_NOT_SCORABLE;
            return result->status;
        }
        resolved.severity[i] = result->axis_resolution[i].severity;
    }

    if (rcs_score_resolved(&resolved, &result->score) != RCS_STATUS_OK) {
        result->status = RCS_CERT_STATUS_SCORING_ERROR;
        return result->status;
    }

    result->score_available = true;
    result->status = RCS_CERT_STATUS_OK;
    return result->status;
}

const char *rcs_certification_status_name(RCSCertificationStatus status) {
    switch (status) {
        case RCS_CERT_STATUS_OK: return "OK";
        case RCS_CERT_STATUS_INVALID_ARGUMENT: return "Invalid argument";
        case RCS_CERT_STATUS_INVALID_MATRIX: return "Invalid matrix";
        case RCS_CERT_STATUS_GOVERNANCE_INPUT_ERROR: return "Invalid or incomplete governance input";
        case RCS_CERT_STATUS_GOVERNANCE_NOT_ADMISSIBLE: return "Governance not admissible";
        case RCS_CERT_STATUS_SPREC_NOT_SCORABLE: return "SPREC condition not scorable";
        case RCS_CERT_STATUS_SCORING_ERROR: return "Scoring error";
        default: return "Unknown certification status";
    }
}
