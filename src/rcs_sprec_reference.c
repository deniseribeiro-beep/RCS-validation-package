#include "rcs_sprec_reference.h"

#include <stddef.h>
#include <string.h>

static int ref_code_is(const char *code, const char *candidate) {
    return code != NULL && candidate != NULL && strcmp(code, candidate) == 0;
}

static int ref_code_in(const char *code, const char *const *values, size_t count) {
    size_t i;
    if (code == NULL) return 0;
    for (i = 0; i < count; ++i) {
        if (strcmp(code, values[i]) == 0) return 1;
    }
    return 0;
}

/* Supplementary Tables S1/S2: complete SPREC 2.0 reference vocabularies. */
static RCSSprecCodeStatus validate_fluid_reference_code(RCSSprecPosition position, const char *code) {
    static const char *const p1[] = {
        "ASC", "AMN", "BAL", "BLD", "BMA", "BMK", "BUC", "BUF", "BFF", "CEL", "CEN",
        "CLN", "CRD", "CSF", "DWB", "NAS", "PEL", "PEN", "PFL", "PL1", "PL2", "RBC",
        "SAL", "SEM", "SER", "SPT", "STL", "SYN", "TER", "U24", "URN", "URM", "URT"
    };
    static const char *const p2[] = {
        "ACD", "ADD", "CAT", "CPD", "CPT", "EDG", "HEP", "HIR", "LHG", "ORG", "PAX", "PED",
        "PET", "PI1", "PIX", "PPS", "PXD", "PXR", "SCI", "SED", "SHP", "SPO", "SST", "TEM", "TRC"
    };
    static const char *const p3[] = {
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O"
    };
    static const char *const p4[] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "M", "N"};
    static const char *const p5[] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "N"};
    static const char *const p6[] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "N"};
    static const char *const p7[] = {
        "A", "B", "V", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
        "P", "Q", "R", "S", "T", "W", "Y"
    };

    switch (position) {
        case RCS_SPREC_POSITION_1:
            if (ref_code_in(code, p1, sizeof(p1) / sizeof(p1[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "ZZZ")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_2:
            if (ref_code_in(code, p2, sizeof(p2) / sizeof(p2[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "XXX")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "ZZZ")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_3:
            if (ref_code_in(code, p3, sizeof(p3) / sizeof(p3[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "X")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "Z")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_4:
            if (ref_code_in(code, p4, sizeof(p4) / sizeof(p4[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "X")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "Z")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_5:
            if (ref_code_in(code, p5, sizeof(p5) / sizeof(p5[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "X")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "Z")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_6:
            if (ref_code_in(code, p6, sizeof(p6) / sizeof(p6[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "X")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "Z")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_7:
            if (ref_code_in(code, p7, sizeof(p7) / sizeof(p7[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "X")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "Z")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        default:
            return RCS_SPREC_CODE_INVALID_POSITION;
    }
}

static RCSSprecCodeStatus validate_solid_reference_code(RCSSprecPosition position, const char *code) {
    static const char *const p1[] = {"CEN", "CLN", "FNA", "HAR", "LCM", "PEN", "PLC", "TIS", "TCM"};
    static const char *const p2[] = {
        "A06", "A12", "A24", "A48", "A72", "BCM", "BPS", "BSL", "BTM", "FNA", "PUN", "SCM",
        "SRG", "SSL", "STM", "VAC", "SWB"
    };
    static const char *const p3[] = {"A", "B", "C", "D", "E", "F", "N"};
    static const char *const p4[] = {"A", "B", "C", "D", "E", "F", "N"};
    static const char *const p5[] = {
        "ACA", "ALD", "ALL", "ETH", "FOR", "HST", "SNP", "NAA", "NBF", "OCT", "PXT", "RNL"
    };
    static const char *const p6[] = {"A", "B", "C", "D", "E", "F", "G", "N"};
    static const char *const p7[] = {
        "A", "B", "V", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
        "P", "Q", "R", "S", "T", "W", "Y"
    };

    switch (position) {
        case RCS_SPREC_POSITION_1:
            if (ref_code_in(code, p1, sizeof(p1) / sizeof(p1[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "ZZZ")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_2:
            if (ref_code_in(code, p2, sizeof(p2) / sizeof(p2[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "ZZZ")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_3:
            if (ref_code_in(code, p3, sizeof(p3) / sizeof(p3[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "X")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "Z")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_4:
            if (ref_code_in(code, p4, sizeof(p4) / sizeof(p4[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "X")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "Z")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_5:
            if (ref_code_in(code, p5, sizeof(p5) / sizeof(p5[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "XXX")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "ZZZ")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_6:
            if (ref_code_in(code, p6, sizeof(p6) / sizeof(p6[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "X")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "Z")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        case RCS_SPREC_POSITION_7:
            if (ref_code_in(code, p7, sizeof(p7) / sizeof(p7[0]))) return RCS_SPREC_CODE_STANDARD;
            if (ref_code_is(code, "X")) return RCS_SPREC_CODE_UNKNOWN;
            if (ref_code_is(code, "Z")) return RCS_SPREC_CODE_OTHER;
            return RCS_SPREC_CODE_INVALID;
        default:
            return RCS_SPREC_CODE_INVALID_POSITION;
    }
}

RCSSprecCodeStatus rcs_sprec_validate_reference_code(
    RCSMatrix matrix, RCSSprecPosition position, const char *code
) {
    if (code == NULL || code[0] == '\0') return RCS_SPREC_CODE_INVALID_ARGUMENT;
    if (position < RCS_SPREC_POSITION_1 || position > RCS_SPREC_POSITION_7)
        return RCS_SPREC_CODE_INVALID_POSITION;
    if (matrix == RCS_MATRIX_FLUID) return validate_fluid_reference_code(position, code);
    if (matrix == RCS_MATRIX_SOLID) return validate_solid_reference_code(position, code);
    return RCS_SPREC_CODE_INVALID_MATRIX;
}

const char *rcs_sprec_position_name(RCSMatrix matrix, RCSSprecPosition position) {
    static const char *const fluid_names[7] = {
        "Type of sample",
        "Type of primary container",
        "Pre-centrifugation (delay between collection and processing)",
        "Centrifugation",
        "Second centrifugation",
        "Post-centrifugation delay",
        "Long-term storage"
    };
    static const char *const solid_names[7] = {
        "Type of sample",
        "Type of collection",
        "Warm ischemia time",
        "Cold ischemia time",
        "Fixation/stabil. type",
        "Fixation time",
        "Long-term storage"
    };
    if (position < RCS_SPREC_POSITION_1 || position > RCS_SPREC_POSITION_7) return "Unknown SPREC position";
    if (matrix == RCS_MATRIX_FLUID) return fluid_names[(int)position];
    if (matrix == RCS_MATRIX_SOLID) return solid_names[(int)position];
    return "Unknown SPREC matrix";
}

const char *rcs_sprec_code_status_name(RCSSprecCodeStatus status) {
    switch (status) {
        case RCS_SPREC_CODE_STANDARD: return "Standard";
        case RCS_SPREC_CODE_UNKNOWN: return "Unknown";
        case RCS_SPREC_CODE_OTHER: return "Other/non-standard";
        case RCS_SPREC_CODE_INVALID: return "Invalid/unrecognized";
        case RCS_SPREC_CODE_INVALID_ARGUMENT: return "Invalid argument";
        case RCS_SPREC_CODE_INVALID_MATRIX: return "Invalid matrix";
        case RCS_SPREC_CODE_INVALID_POSITION: return "Invalid SPREC position";
        default: return "Unknown code status";
    }
}
