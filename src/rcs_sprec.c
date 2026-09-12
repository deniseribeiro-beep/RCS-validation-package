#include "rcs_sprec.h"

#include <math.h>
#include <stddef.h>
#include <string.h>

static int code_is(const char *code, const char *candidate) {
    return code != NULL && candidate != NULL && strcmp(code, candidate) == 0;
}

static int code_in(const char *code, const char *const *values, size_t count) {
    size_t i;
    if (code == NULL) return 0;
    for (i = 0; i < count; ++i) {
        if (strcmp(code, values[i]) == 0) return 1;
    }
    return 0;
}

static RCSSprecResolutionStatus resolved(RCSSprecResolution *result, double severity) {
    result->status = RCS_SPREC_RESOLVED;
    result->severity = severity;
    return result->status;
}

static RCSSprecResolutionStatus not_scored(RCSSprecResolution *result) {
    result->status = RCS_SPREC_NOT_SCORED;
    result->severity = NAN;
    return result->status;
}

static RCSSprecResolutionStatus invalid_context(RCSSprecResolution *result) {
    result->status = RCS_SPREC_INVALID_CONTEXT;
    result->severity = NAN;
    return result->status;
}

int rcs_sprec_axis_valid_for_matrix(RCSMatrix matrix, RCSSprecAxis axis) {
    if (matrix == RCS_MATRIX_FLUID) {
        return axis == RCS_SPREC_AXIS_P_PRE ||
               axis == RCS_SPREC_AXIS_P_CENT1 ||
               axis == RCS_SPREC_AXIS_P_CENT2 ||
               axis == RCS_SPREC_AXIS_P_POST ||
               axis == RCS_SPREC_AXIS_P_STORE;
    }
    if (matrix == RCS_MATRIX_SOLID) {
        return axis == RCS_SPREC_AXIS_P_WARM ||
               axis == RCS_SPREC_AXIS_P_COLD ||
               axis == RCS_SPREC_AXIS_P_FIX ||
               axis == RCS_SPREC_AXIS_P_FIX_TIME ||
               axis == RCS_SPREC_AXIS_P_STORE;
    }
    return 0;
}

static int is_unknown_code(const char *code) {
    return code_is(code, "X") || code_is(code, "XXX");
}

static int is_other_code(const char *code) {
    return code_is(code, "Z") || code_is(code, "ZZZ");
}

static RCSSprecResolutionStatus resolve_p_pre(const char *code, RCSSprecResolution *result) {
    static const char *const sev0[] = {"A", "B"};
    static const char *const sev020[] = {"C", "D"};
    static const char *const sev040[] = {"E", "F"};
    static const char *const sev060[] = {"G", "H"};
    static const char *const sev080[] = {"I", "J"};
    static const char *const sev090[] = {"K", "L"};
    static const char *const sev100[] = {"M", "N"};
    if (code_in(code, sev0, 2)) return resolved(result, 0.00);
    if (code_in(code, sev020, 2)) return resolved(result, 0.20);
    if (code_in(code, sev040, 2)) return resolved(result, 0.40);
    if (code_in(code, sev060, 2)) return resolved(result, 0.60);
    if (code_in(code, sev080, 2)) return resolved(result, 0.80);
    if (code_in(code, sev090, 2)) return resolved(result, 0.90);
    if (code_in(code, sev100, 2)) return resolved(result, 1.00);
    if (code_is(code, "O")) return resolved(result, 0.25);
    return not_scored(result);
}

static RCSSprecResolutionStatus resolve_p_cent1(
    const char *code, const RCSSprecContext *context, RCSSprecResolution *result
) {
    static const char *const sev0[] = {"A", "B", "C", "D"};
    static const char *const sev033[] = {"E", "F"};
    static const char *const sev066[] = {"G", "H"};
    static const char *const sev100[] = {"I", "J"};
    if (code_in(code, sev0, 4)) return resolved(result, 0.00);
    if (code_in(code, sev033, 2)) return resolved(result, 0.33);
    if (code_in(code, sev066, 2)) return resolved(result, 0.66);
    if (code_in(code, sev100, 2)) return resolved(result, 1.00);
    if (code_is(code, "M")) return resolved(result, 0.50);
    if (!code_is(code, "N")) return not_scored(result);
    if (context == NULL || context->primary_centrifugation == RCS_PRIMARY_CENT_CONTEXT_UNSPECIFIED)
        return not_scored(result);
    switch (context->primary_centrifugation) {
        case RCS_PRIMARY_CENT_UNSEPARATED_WHOLE_BLOOD_DWB_OR_CELLULAR:
            return resolved(result, 0.00);
        case RCS_PRIMARY_CENT_SEPARATED_FLUID_REQUIRED:
            return resolved(result, 1.00);
        default:
            return invalid_context(result);
    }
}

static RCSSprecResolutionStatus resolve_p_cent2(
    const char *code, const RCSSprecContext *context, RCSSprecResolution *result
) {
    static const char *const sev0[] = {"A", "B", "C", "D"};
    static const char *const sev033[] = {"E", "F"};
    static const char *const sev066[] = {"G", "H"};
    static const char *const sev100[] = {"I", "J"};
    if (code_in(code, sev0, 4)) return resolved(result, 0.00);
    if (code_in(code, sev033, 2)) return resolved(result, 0.33);
    if (code_in(code, sev066, 2)) return resolved(result, 0.66);
    if (code_in(code, sev100, 2)) return resolved(result, 1.00);
    if (!code_is(code, "N")) return not_scored(result);
    if (context == NULL || context->second_centrifugation == RCS_SECOND_CENT_CONTEXT_UNSPECIFIED)
        return not_scored(result);
    switch (context->second_centrifugation) {
        case RCS_SECOND_CENT_NOT_REQUIRED:
            return resolved(result, 0.00);
        case RCS_SECOND_CENT_ROUTINE_PLASMA_OR_SERUM:
            return resolved(result, 0.25);
        case RCS_SECOND_CENT_LOW_CELL_CONTAMINATION_REQUIRED:
            return resolved(result, 1.00);
        default:
            return invalid_context(result);
    }
}

static RCSSprecResolutionStatus resolve_p_post(const char *code, RCSSprecResolution *result) {
    static const char *const sev0[] = {"A", "B"};
    static const char *const sev025[] = {"C", "D"};
    static const char *const sev050[] = {"E", "F"};
    static const char *const sev075[] = {"G", "H"};
    static const char *const sev100[] = {"I", "J"};
    if (code_in(code, sev0, 2)) return resolved(result, 0.00);
    if (code_in(code, sev025, 2)) return resolved(result, 0.25);
    if (code_in(code, sev050, 2)) return resolved(result, 0.50);
    if (code_in(code, sev075, 2)) return resolved(result, 0.75);
    if (code_in(code, sev100, 2)) return resolved(result, 1.00);
    if (code_is(code, "N")) return resolved(result, 0.00);
    return not_scored(result);
}

static RCSSprecResolutionStatus resolve_p_store(
    const char *code, const RCSSprecContext *context, RCSSprecResolution *result
) {
    static const char *const sev0[] = {"C", "F", "Q", "V", "W", "E", "I"};
    static const char *const sev025[] = {"A", "D", "G", "J", "L", "S", "N", "O"};
    static const char *const sev060[] = {"B", "H", "K", "M", "T"};
    if (code_in(code, sev0, 7)) return resolved(result, 0.00);
    if (code_in(code, sev025, 8)) return resolved(result, 0.25);
    if (code_in(code, sev060, 5)) return resolved(result, 0.60);
    if (code_is(code, "Y")) {
        if (context == NULL || context->storage_temperature == RCS_STORAGE_TEMPERATURE_UNSPECIFIED)
            return not_scored(result);
        switch (context->storage_temperature) {
            case RCS_STORAGE_TEMPERATURE_NEG85_TO_NEG60:
                return resolved(result, 0.25);
            case RCS_STORAGE_TEMPERATURE_NEG35_TO_NEG18:
                return resolved(result, 0.60);
            default:
                return invalid_context(result);
        }
    }
    if (code_is(code, "P") || code_is(code, "R")) {
        if (context == NULL || context->storage_workflow == RCS_STORAGE_WORKFLOW_UNSPECIFIED)
            return not_scored(result);
        switch (context->storage_workflow) {
            case RCS_STORAGE_WORKFLOW_ARCHIVAL_MORPHOLOGICAL_OR_VALIDATED_LOCAL:
                return resolved(result, 0.25);
            case RCS_STORAGE_WORKFLOW_NATIVE_VIABLE_OR_ULTRALOW_REQUIRED:
                return resolved(result, 1.00);
            default:
                return invalid_context(result);
        }
    }
    return not_scored(result);
}

static RCSSprecResolutionStatus resolve_p_warm_or_cold(const char *code, RCSSprecResolution *result) {
    if (code_is(code, "A")) return resolved(result, 0.00);
    if (code_is(code, "B")) return resolved(result, 0.20);
    if (code_is(code, "C")) return resolved(result, 0.40);
    if (code_is(code, "D")) return resolved(result, 0.60);
    if (code_is(code, "E")) return resolved(result, 0.80);
    if (code_is(code, "F")) return resolved(result, 1.00);
    if (code_is(code, "N")) return resolved(result, 0.00);
    return not_scored(result);
}

static RCSSprecResolutionStatus resolve_p_fix(
    const char *code, const RCSSprecContext *context, RCSSprecResolution *result
) {
    static const char *const sev0[] = {"SNP", "PXT", "RNL", "ALL", "HST"};
    static const char *const sev033[] = {"NBF", "OCT"};
    static const char *const sev066[] = {"FOR", "ALD", "ETH", "ACA", "NAA"};
    const int recognized = code_in(code, sev0, 5) || code_in(code, sev033, 2) || code_in(code, sev066, 5);

    /* Invalid or unrecognized controlled codes are Not scored even if an
       analytical-workflow incompatibility flag was supplied. */
    if (!recognized) return not_scored(result);

    if (context != NULL) {
        if (context->fixation_workflow == RCS_FIXATION_WORKFLOW_INCOMPATIBLE)
            return resolved(result, 1.00);
        if (context->fixation_workflow != RCS_FIXATION_WORKFLOW_UNSPECIFIED &&
            context->fixation_workflow != RCS_FIXATION_WORKFLOW_COMPATIBLE)
            return invalid_context(result);
    }
    if (code_in(code, sev0, 5)) return resolved(result, 0.00);
    if (code_in(code, sev033, 2)) return resolved(result, 0.33);
    return resolved(result, 0.66);
}

static RCSSprecResolutionStatus resolve_p_fix_time(const char *code, RCSSprecResolution *result) {
    if (code_is(code, "B")) return resolved(result, 0.00);
    if (code_is(code, "A")) return resolved(result, 0.50);
    if (code_is(code, "C")) return resolved(result, 0.20);
    if (code_is(code, "D")) return resolved(result, 0.40);
    if (code_is(code, "E")) return resolved(result, 0.60);
    if (code_is(code, "F")) return resolved(result, 0.80);
    if (code_is(code, "G")) return resolved(result, 1.00);
    if (code_is(code, "N")) return resolved(result, 0.00);
    return not_scored(result);
}

RCSSprecResolutionStatus rcs_sprec_resolve(
    RCSMatrix matrix,
    RCSSprecAxis axis,
    const char *code,
    const RCSSprecContext *context,
    RCSSprecResolution *result
) {
    if (result == NULL) return RCS_SPREC_INVALID_ARGUMENT;
    result->status = RCS_SPREC_INVALID_ARGUMENT;
    result->severity = NAN;

    if (matrix != RCS_MATRIX_FLUID && matrix != RCS_MATRIX_SOLID) {
        result->status = RCS_SPREC_INVALID_MATRIX;
        return result->status;
    }
    if (axis < RCS_SPREC_AXIS_P_PRE || axis > RCS_SPREC_AXIS_P_FIX_TIME) {
        result->status = RCS_SPREC_INVALID_AXIS;
        return result->status;
    }
    if (!rcs_sprec_axis_valid_for_matrix(matrix, axis)) {
        return not_scored(result);
    }

    /* Supplementary File 1: missing/unknown/other/non-standard conditions are Not scored. */
    if (code == NULL || code[0] == '\0' || is_unknown_code(code) || is_other_code(code)) {
        return not_scored(result);
    }

    /* A semantically incompatible value is non-additive and therefore Not scored.
       This is distinct from a recognized fixation method that is biologically
       incompatible with the intended analytical workflow, which Table S3 maps
       to severity 1.00 on P_fix. */
    if (context != NULL) {
        if (context->semantic_compatibility == RCS_SEMANTIC_INCOMPATIBLE)
            return not_scored(result);
        if (context->semantic_compatibility != RCS_SEMANTIC_COMPATIBILITY_UNSPECIFIED &&
            context->semantic_compatibility != RCS_SEMANTIC_COMPATIBLE)
            return invalid_context(result);
    }

    switch (axis) {
        case RCS_SPREC_AXIS_P_PRE:
            return resolve_p_pre(code, result);
        case RCS_SPREC_AXIS_P_CENT1:
            return resolve_p_cent1(code, context, result);
        case RCS_SPREC_AXIS_P_CENT2:
            return resolve_p_cent2(code, context, result);
        case RCS_SPREC_AXIS_P_POST:
            return resolve_p_post(code, result);
        case RCS_SPREC_AXIS_P_STORE:
            return resolve_p_store(code, context, result);
        case RCS_SPREC_AXIS_P_WARM:
        case RCS_SPREC_AXIS_P_COLD:
            return resolve_p_warm_or_cold(code, result);
        case RCS_SPREC_AXIS_P_FIX:
            return resolve_p_fix(code, context, result);
        case RCS_SPREC_AXIS_P_FIX_TIME:
            return resolve_p_fix_time(code, result);
        default:
            result->status = RCS_SPREC_INVALID_AXIS;
            return result->status;
    }
}

const char *rcs_sprec_axis_name(RCSSprecAxis axis) {
    switch (axis) {
        case RCS_SPREC_AXIS_P_PRE: return "P_pre";
        case RCS_SPREC_AXIS_P_CENT1: return "P_cent1";
        case RCS_SPREC_AXIS_P_CENT2: return "P_cent2";
        case RCS_SPREC_AXIS_P_POST: return "P_post";
        case RCS_SPREC_AXIS_P_STORE: return "P_store";
        case RCS_SPREC_AXIS_P_WARM: return "P_warm";
        case RCS_SPREC_AXIS_P_COLD: return "P_cold";
        case RCS_SPREC_AXIS_P_FIX: return "P_fix";
        case RCS_SPREC_AXIS_P_FIX_TIME: return "P_fixTime";
        default: return "Unknown axis";
    }
}

const char *rcs_sprec_resolution_status_name(RCSSprecResolutionStatus status) {
    switch (status) {
        case RCS_SPREC_RESOLVED: return "Resolved";
        case RCS_SPREC_NOT_SCORED: return "Not scored";
        case RCS_SPREC_INVALID_ARGUMENT: return "Invalid argument";
        case RCS_SPREC_INVALID_MATRIX: return "Invalid matrix";
        case RCS_SPREC_INVALID_AXIS: return "Invalid axis";
        case RCS_SPREC_INVALID_CONTEXT: return "Invalid conditional context";
        default: return "Unknown SPREC resolution status";
    }
}
