#include "rcs_reference.h"

#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int parse_matrix(const char *text, RCSMatrix *matrix) {
    if (strcmp(text, "fluid") == 0) {
        *matrix = RCS_MATRIX_FLUID;
        return 1;
    }
    if (strcmp(text, "solid") == 0) {
        *matrix = RCS_MATRIX_SOLID;
        return 1;
    }
    return 0;
}

static int parse_governance(const char *text, RCSGovernanceDecision *decision) {
    if (strcmp(text, "pass") == 0) {
        *decision = RCS_GOVERNANCE_PASS;
        return 1;
    }
    if (strcmp(text, "fail") == 0) {
        *decision = RCS_GOVERNANCE_FAIL;
        return 1;
    }
    return 0;
}

static int parse_double(const char *text, double *value) {
    char *end = NULL;
    errno = 0;
    *value = strtod(text, &end);
    return errno == 0 && end != text && *end == '\0';
}

int main(int argc, char **argv) {
    RCSResolvedProfile profile;
    RCSResult result;
    RCSStatus status;
    int i;

    if (argc != 8) {
        fprintf(stderr,
                "Usage: %s <fluid|solid> <pass|fail> <s1> <s2> <s3> <s4> <s5>\n",
                argv[0]);
        return 2;
    }

    if (!parse_matrix(argv[1], &profile.matrix)) {
        fprintf(stderr, "Invalid matrix: %s\n", argv[1]);
        return 2;
    }
    if (!parse_governance(argv[2], &profile.governance)) {
        fprintf(stderr, "Invalid governance decision: %s\n", argv[2]);
        return 2;
    }
    for (i = 0; i < 5; ++i) {
        if (!parse_double(argv[i + 3], &profile.severity[i])) {
            fprintf(stderr, "Invalid severity: %s\n", argv[i + 3]);
            return 2;
        }
    }

    status = rcs_score_resolved(&profile, &result);
    if (status != RCS_STATUS_OK) {
        fprintf(stderr, "%s\n", rcs_status_name(status));
        return 1;
    }

    printf("matrix,governance,p_bio,rcs,final_grade,route\n");
    printf("%s,%s,",
           profile.matrix == RCS_MATRIX_FLUID ? "fluid" : "solid",
           profile.governance == RCS_GOVERNANCE_PASS ? "pass" : "fail");

    if (result.numeric_score_available) {
        printf("%.17g,%.17g,", result.p_bio, result.rcs);
    } else {
        printf("NA,NA,");
    }

    printf("%s,%s\n",
           rcs_grade_name(result.final_grade),
           rcs_route_name(result.route));

    return 0;
}
