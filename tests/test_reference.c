#include "rcs_certification.h"

#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static void governance_all_satisfied(RCSGovernanceProfile *profile) {
    int i;
    rcs_governance_profile_init(profile);
    for (i = 0; i < RCS_GOV_EVIDENCE_COUNT; ++i) {
        profile->evidence[i].state = RCS_GOV_EVIDENCE_SATISFIED;
        profile->evidence[i].disposition = RCS_GOV_DISPOSITION_NONE;
    }
    profile->thermal_control_relevant = true;
}

static void test_score_boundaries(void) {
    RCSResolvedProfile profile;
    RCSResult result;
    const double severity[] = {0.10, 0.20, 0.35, 0.50, 0.51};
    const RCSGrade expected[] = {RCS_GRADE_A, RCS_GRADE_B, RCS_GRADE_C, RCS_GRADE_D, RCS_GRADE_E};
    int k, i;

    profile.matrix = RCS_MATRIX_FLUID;
    profile.governance = RCS_GOVERNANCE_PASS;
    for (k = 0; k < 5; ++k) {
        for (i = 0; i < 5; ++i) profile.severity[i] = severity[k];
        assert(rcs_score_resolved(&profile, &result) == RCS_STATUS_OK);
        assert(result.final_grade == expected[k]);
        assert(result.numeric_score_available);
    }

    profile.governance = RCS_GOVERNANCE_FAIL;
    for (i = 0; i < 5; ++i) profile.severity[i] = 0.0;
    assert(rcs_score_resolved(&profile, &result) == RCS_STATUS_OK);
    assert(!result.numeric_score_available);
    assert(isnan(result.p_bio));
    assert(isnan(result.rcs));
    assert(result.final_grade == RCS_GRADE_E);
    assert(result.route == RCS_ROUTE_GOVERNANCE_FAILURE);
}

static void test_sprec_resolution(void) {
    RCSSprecContext context;
    RCSSprecResolution result;
    memset(&context, 0, sizeof(context));

    context.second_centrifugation = RCS_SECOND_CENT_ROUTINE_PLASMA_OR_SERUM;
    assert(rcs_sprec_resolve(
        RCS_MATRIX_FLUID, RCS_SPREC_AXIS_P_CENT2, "N", &context, &result
    ) == RCS_SPREC_RESOLVED);
    assert(fabs(result.severity - 0.25) < 1e-12);

    context.second_centrifugation = RCS_SECOND_CENT_CONTEXT_UNSPECIFIED;
    assert(rcs_sprec_resolve(
        RCS_MATRIX_FLUID, RCS_SPREC_AXIS_P_CENT2, "N", &context, &result
    ) == RCS_SPREC_NOT_SCORED);
    assert(isnan(result.severity));

    memset(&context, 0, sizeof(context));
    context.storage_temperature = RCS_STORAGE_TEMPERATURE_NEG85_TO_NEG60;
    assert(rcs_sprec_resolve(
        RCS_MATRIX_FLUID, RCS_SPREC_AXIS_P_STORE, "Y", &context, &result
    ) == RCS_SPREC_RESOLVED);
    assert(fabs(result.severity - 0.25) < 1e-12);

    context.fixation_workflow = RCS_FIXATION_WORKFLOW_INCOMPATIBLE;
    assert(rcs_sprec_resolve(
        RCS_MATRIX_SOLID, RCS_SPREC_AXIS_P_FIX, "NBF", &context, &result
    ) == RCS_SPREC_RESOLVED);
    assert(fabs(result.severity - 1.0) < 1e-12);
}

static void test_governance(void) {
    RCSGovernanceProfile profile;
    RCSGovernanceResult result;

    governance_all_satisfied(&profile);
    assert(rcs_governance_evaluate(&profile, &result) == RCS_GOV_STATUS_OK);
    assert(result.admissible);
    assert(result.outcome == RCS_GOV_OUTCOME_ADMISSIBLE);

    profile.evidence[RCS_GOV_TRACEABILITY].state = RCS_GOV_EVIDENCE_FAILED;
    assert(rcs_governance_evaluate(&profile, &result) == RCS_GOV_STATUS_OK);
    assert(!result.admissible);
    assert(result.outcome == RCS_GOV_OUTCOME_FAILED);

    governance_all_satisfied(&profile);
    profile.evidence[RCS_GOV_QUALITY_MANAGEMENT].state = RCS_GOV_EVIDENCE_UNRESOLVED;
    profile.evidence[RCS_GOV_QUALITY_MANAGEMENT].disposition = RCS_GOV_DISPOSITION_TECHNICAL_REVIEW;
    assert(rcs_governance_evaluate(&profile, &result) == RCS_GOV_STATUS_OK);
    assert(!result.admissible);
    assert(result.outcome == RCS_GOV_OUTCOME_REVIEW_REQUIRED);

    rcs_governance_profile_init(&profile);
    assert(rcs_governance_evaluate(&profile, &result) == RCS_GOV_STATUS_MISSING_EXPLICIT_EVIDENCE);
}

static void test_complete_fluid_certification(void) {
    RCSCertificationInput input;
    RCSCertificationResult result;
    const char *codes[7] = {"BLD", "EDG", "A", "A", "A", "A", "C"};
    int i;

    rcs_certification_input_init(&input, RCS_MATRIX_FLUID);
    governance_all_satisfied(&input.governance);
    input.sprec_context.semantic_compatibility = RCS_SEMANTIC_COMPATIBLE;
    for (i = 0; i < 7; ++i) input.sprec[i] = codes[i];

    assert(rcs_certify(&input, &result) == RCS_CERT_STATUS_OK);
    assert(result.score_available);
    assert(fabs(result.score.p_bio) < 1e-12);
    assert(fabs(result.score.rcs - 100.0) < 1e-12);
    assert(result.score.final_grade == RCS_GRADE_A);
    assert(result.score.route == RCS_ROUTE_SCORE_BASED);
}

static void test_complete_solid_certification(void) {
    RCSCertificationInput input;
    RCSCertificationResult result;
    const char *codes[7] = {"TIS", "SRG", "A", "A", "SNP", "B", "C"};
    int i;

    rcs_certification_input_init(&input, RCS_MATRIX_SOLID);
    governance_all_satisfied(&input.governance);
    input.sprec_context.semantic_compatibility = RCS_SEMANTIC_COMPATIBLE;
    for (i = 0; i < 7; ++i) input.sprec[i] = codes[i];

    assert(rcs_certify(&input, &result) == RCS_CERT_STATUS_OK);
    assert(result.score_available);
    assert(fabs(result.score.rcs - 100.0) < 1e-12);
    assert(result.score.final_grade == RCS_GRADE_A);
}

static void test_not_scored_is_noncompensable(void) {
    RCSCertificationInput input;
    RCSCertificationResult result;
    const char *codes[7] = {"BLD", "EDG", "X", "A", "A", "A", "C"};
    int i;

    rcs_certification_input_init(&input, RCS_MATRIX_FLUID);
    governance_all_satisfied(&input.governance);
    input.sprec_context.semantic_compatibility = RCS_SEMANTIC_COMPATIBLE;
    for (i = 0; i < 7; ++i) input.sprec[i] = codes[i];

    assert(rcs_certify(&input, &result) == RCS_CERT_STATUS_SPREC_NOT_SCORABLE);
    assert(!result.score_available);
    assert(result.sprec_gate_failure);
    assert(result.score.final_grade == RCS_GRADE_E);
    assert(result.score.route == RCS_ROUTE_GOVERNANCE_FAILURE);
    assert(isnan(result.score.p_bio));
    assert(isnan(result.score.rcs));
}

static void test_complete_api_rejects_missing_governance(void) {
    RCSCertificationInput input;
    RCSCertificationResult result;
    const char *codes[7] = {"BLD", "EDG", "A", "A", "A", "A", "C"};
    int i;

    rcs_certification_input_init(&input, RCS_MATRIX_FLUID);
    for (i = 0; i < 7; ++i) input.sprec[i] = codes[i];
    assert(rcs_certify(&input, &result) == RCS_CERT_STATUS_GOVERNANCE_INPUT_ERROR);
    assert(result.governance_status == RCS_GOV_STATUS_MISSING_EXPLICIT_EVIDENCE);
}

int main(void) {
    test_score_boundaries();
    test_sprec_resolution();
    test_governance();
    test_complete_fluid_certification();
    test_complete_solid_certification();
    test_not_scored_is_noncompensable();
    test_complete_api_rejects_missing_governance();
    puts("C reference deterministic tests passed.");
    return 0;
}
