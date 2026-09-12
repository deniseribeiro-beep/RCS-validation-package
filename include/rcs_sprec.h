#ifndef RCS_SPREC_H
#define RCS_SPREC_H

#include "rcs_reference.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    RCS_SPREC_AXIS_P_PRE = 0,
    RCS_SPREC_AXIS_P_CENT1 = 1,
    RCS_SPREC_AXIS_P_CENT2 = 2,
    RCS_SPREC_AXIS_P_POST = 3,
    RCS_SPREC_AXIS_P_STORE = 4,
    RCS_SPREC_AXIS_P_WARM = 5,
    RCS_SPREC_AXIS_P_COLD = 6,
    RCS_SPREC_AXIS_P_FIX = 7,
    RCS_SPREC_AXIS_P_FIX_TIME = 8
} RCSSprecAxis;

typedef enum {
    RCS_SPREC_RESOLVED = 0,
    RCS_SPREC_NOT_SCORED = 1,
    RCS_SPREC_INVALID_ARGUMENT = 2,
    RCS_SPREC_INVALID_MATRIX = 3,
    RCS_SPREC_INVALID_AXIS = 4,
    RCS_SPREC_INVALID_CONTEXT = 5
} RCSSprecResolutionStatus;

typedef enum {
    RCS_PRIMARY_CENT_CONTEXT_UNSPECIFIED = 0,
    RCS_PRIMARY_CENT_UNSEPARATED_WHOLE_BLOOD_DWB_OR_CELLULAR = 1,
    RCS_PRIMARY_CENT_SEPARATED_FLUID_REQUIRED = 2
} RCSPrimaryCentrifugationContext;

typedef enum {
    RCS_SECOND_CENT_CONTEXT_UNSPECIFIED = 0,
    RCS_SECOND_CENT_NOT_REQUIRED = 1,
    RCS_SECOND_CENT_ROUTINE_PLASMA_OR_SERUM = 2,
    RCS_SECOND_CENT_LOW_CELL_CONTAMINATION_REQUIRED = 3
} RCSSecondCentrifugationContext;

typedef enum {
    RCS_STORAGE_TEMPERATURE_UNSPECIFIED = 0,
    RCS_STORAGE_TEMPERATURE_NEG85_TO_NEG60 = 1,
    RCS_STORAGE_TEMPERATURE_NEG35_TO_NEG18 = 2
} RCSStorageTemperatureContext;

typedef enum {
    RCS_STORAGE_WORKFLOW_UNSPECIFIED = 0,
    RCS_STORAGE_WORKFLOW_ARCHIVAL_MORPHOLOGICAL_OR_VALIDATED_LOCAL = 1,
    RCS_STORAGE_WORKFLOW_NATIVE_VIABLE_OR_ULTRALOW_REQUIRED = 2
} RCSStorageWorkflowContext;

typedef enum {
    RCS_FIXATION_WORKFLOW_UNSPECIFIED = 0,
    RCS_FIXATION_WORKFLOW_COMPATIBLE = 1,
    RCS_FIXATION_WORKFLOW_INCOMPATIBLE = 2
} RCSFixationWorkflowContext;

typedef enum {
    RCS_SEMANTIC_COMPATIBILITY_UNSPECIFIED = 0,
    RCS_SEMANTIC_COMPATIBLE = 1,
    RCS_SEMANTIC_INCOMPATIBLE = 2
} RCSSemanticCompatibilityContext;

typedef struct {
    RCSPrimaryCentrifugationContext primary_centrifugation;
    RCSSecondCentrifugationContext second_centrifugation;
    RCSStorageTemperatureContext storage_temperature;
    RCSStorageWorkflowContext storage_workflow;
    RCSFixationWorkflowContext fixation_workflow;
    RCSSemanticCompatibilityContext semantic_compatibility;
} RCSSprecContext;

typedef struct {
    RCSSprecResolutionStatus status;
    double severity;
} RCSSprecResolution;

/*
 * Resolve one SPREC 2.0 coded condition to the intra-axis RCS severity s_i(x_i)
 * defined in Supplementary File 1, Table S3.
 *
 * Missing, unknown, other/non-standard, unrecognized, semantically incompatible,
 * locally unresolved, or insufficiently documented conditions return
 * RCS_SPREC_NOT_SCORED and a NaN severity. Conditional mappings require the
 * corresponding field in RCSSprecContext; unresolved conditional context is
 * also Not scored.
 */
RCSSprecResolutionStatus rcs_sprec_resolve(
    RCSMatrix matrix,
    RCSSprecAxis axis,
    const char *code,
    const RCSSprecContext *context,
    RCSSprecResolution *result
);

int rcs_sprec_axis_valid_for_matrix(RCSMatrix matrix, RCSSprecAxis axis);
const char *rcs_sprec_axis_name(RCSSprecAxis axis);
const char *rcs_sprec_resolution_status_name(RCSSprecResolutionStatus status);

#ifdef __cplusplus
}
#endif

#endif
