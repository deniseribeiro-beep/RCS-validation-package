#ifndef RCS_SPREC_REFERENCE_H
#define RCS_SPREC_REFERENCE_H

#include "rcs_reference.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    RCS_SPREC_POSITION_1 = 0,
    RCS_SPREC_POSITION_2 = 1,
    RCS_SPREC_POSITION_3 = 2,
    RCS_SPREC_POSITION_4 = 3,
    RCS_SPREC_POSITION_5 = 4,
    RCS_SPREC_POSITION_6 = 5,
    RCS_SPREC_POSITION_7 = 6
} RCSSprecPosition;

typedef enum {
    RCS_SPREC_CODE_STANDARD = 0,
    RCS_SPREC_CODE_UNKNOWN = 1,
    RCS_SPREC_CODE_OTHER = 2,
    RCS_SPREC_CODE_INVALID = 3,
    RCS_SPREC_CODE_INVALID_ARGUMENT = 4,
    RCS_SPREC_CODE_INVALID_MATRIX = 5,
    RCS_SPREC_CODE_INVALID_POSITION = 6
} RCSSprecCodeStatus;

/*
 * Validate one raw SPREC 2.0 component against Supplementary Tables S1/S2.
 * This covers all seven SPREC positions, including the two reference positions
 * that do not contribute directly to additive RCS scoring.
 */
RCSSprecCodeStatus rcs_sprec_validate_reference_code(
    RCSMatrix matrix,
    RCSSprecPosition position,
    const char *code
);

const char *rcs_sprec_position_name(RCSMatrix matrix, RCSSprecPosition position);
const char *rcs_sprec_code_status_name(RCSSprecCodeStatus status);

#ifdef __cplusplus
}
#endif

#endif
