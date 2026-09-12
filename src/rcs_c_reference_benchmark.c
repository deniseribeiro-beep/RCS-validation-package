#define _POSIX_C_SOURCE 200809L
#include "rcs_reference.h"

#include <errno.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    size_t n;
    uint8_t *matrix;
    uint8_t *governance;
    double *severity; /* column-major, 10 columns */
} Input;

typedef struct {
    double *p_bio;
    double *rcs;
    uint8_t *grade;
    uint8_t *route;
} Output;

typedef struct {
    const char *input;
    const char *output;
    const char *implementation;
    const char *mode;
    int warmups;
    int max_loops;
    double min_sec;
} Arguments;

static double now_seconds(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return NAN;
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static int parse_int(const char *s, int *out) {
    char *end = NULL;
    long v;
    errno = 0;
    v = strtol(s, &end, 10);
    if (errno || end == s || *end != '\0' || v < 0 || v > 2147483647L) return 0;
    *out = (int)v;
    return 1;
}

static int parse_double_value(const char *s, double *out) {
    char *end = NULL;
    errno = 0;
    *out = strtod(s, &end);
    return !errno && end != s && *end == '\0' && isfinite(*out);
}

static int parse_args(int argc, char **argv, Arguments *a) {
    int i;
    memset(a, 0, sizeof(*a));
    a->implementation = "c_reference";
    a->warmups = 2;
    a->max_loops = 1000000;
    a->min_sec = 0.25;
    for (i = 1; i < argc; i += 2) {
        const char *k;
        const char *v;
        if (i + 1 >= argc) return 0;
        k = argv[i]; v = argv[i + 1];
        if (strcmp(k, "--input") == 0) a->input = v;
        else if (strcmp(k, "--output") == 0) a->output = v;
        else if (strcmp(k, "--implementation") == 0) a->implementation = v;
        else if (strcmp(k, "--mode") == 0) a->mode = v;
        else if (strcmp(k, "--warmups") == 0) { if (!parse_int(v, &a->warmups)) return 0; }
        else if (strcmp(k, "--min-sec") == 0) { if (!parse_double_value(v, &a->min_sec)) return 0; }
        else if (strcmp(k, "--max-loops") == 0) { if (!parse_int(v, &a->max_loops)) return 0; }
        else if (strcmp(k, "--threads") == 0 || strcmp(k, "--workers") == 0) { int ignored; if (!parse_int(v, &ignored)) return 0; }
        else return 0;
    }
    return a->input && a->output && a->mode &&
           (strcmp(a->mode, "compute") == 0 || strcmp(a->mode, "e2e") == 0) &&
           a->warmups >= 0 && a->max_loops > 0 && a->min_sec > 0;
}

static void free_input(Input *x) {
    free(x->matrix); free(x->governance); free(x->severity);
    memset(x, 0, sizeof(*x));
}

static void free_output(Output *x) {
    free(x->p_bio); free(x->rcs); free(x->grade); free(x->route);
    memset(x, 0, sizeof(*x));
}

static int read_input(const char *path, Input *x) {
    FILE *f = fopen(path, "rb");
    char magic[8];
    double n_value;
    size_t n, j;
    if (!f) return 0;
    memset(x, 0, sizeof(*x));
    if (fread(magic, 1, 8, f) != 8 || memcmp(magic, "RCSBIN1\0", 8) != 0 ||
        fread(&n_value, sizeof(double), 1, f) != 1 || n_value < 0 || floor(n_value) != n_value) {
        fclose(f); return 0;
    }
    n = (size_t)n_value;
    x->n = n;
    x->matrix = (uint8_t *)malloc(n);
    x->governance = (uint8_t *)malloc(n);
    x->severity = (double *)malloc(n * 10u * sizeof(double));
    if ((!x->matrix && n) || (!x->governance && n) || (!x->severity && n)) { fclose(f); free_input(x); return 0; }
    if (fread(x->matrix, 1, n, f) != n || fread(x->governance, 1, n, f) != n) { fclose(f); free_input(x); return 0; }
    for (j = 0; j < 10u; ++j) {
        if (fread(x->severity + j * n, sizeof(double), n, f) != n) { fclose(f); free_input(x); return 0; }
    }
    fclose(f);
    return 1;
}

static int allocate_output(size_t n, Output *y) {
    memset(y, 0, sizeof(*y));
    y->p_bio = (double *)malloc(n * sizeof(double));
    y->rcs = (double *)malloc(n * sizeof(double));
    y->grade = (uint8_t *)malloc(n);
    y->route = (uint8_t *)malloc(n);
    if ((!y->p_bio && n) || (!y->rcs && n) || (!y->grade && n) || (!y->route && n)) { free_output(y); return 0; }
    return 1;
}

static int score_once(const Input *x, Output *y) {
    size_t i, j;
    for (i = 0; i < x->n; ++i) {
        RCSResolvedProfile p;
        RCSResult r;
        const size_t offset = x->matrix[i] == 0u ? 0u : 5u;
        if (x->matrix[i] > 1u || x->governance[i] > 1u) return 0;
        p.matrix = x->matrix[i] == 0u ? RCS_MATRIX_FLUID : RCS_MATRIX_SOLID;
        p.governance = x->governance[i] == 0u ? RCS_GOVERNANCE_FAIL : RCS_GOVERNANCE_PASS;
        for (j = 0; j < 5u; ++j) p.severity[j] = x->severity[(offset + j) * x->n + i];
        if (rcs_score_resolved(&p, &r) != RCS_STATUS_OK) return 0;
        y->p_bio[i] = r.p_bio;
        y->rcs[i] = r.rcs;
        y->grade[i] = (uint8_t)r.final_grade;
        y->route[i] = (uint8_t)r.route;
    }
    return 1;
}

static int write_output(const char *path, size_t n, const Output *y) {
    FILE *f = fopen(path, "wb");
    double n_value = (double)n;
    int ok;
    if (!f) return 0;
    ok = fwrite("RCSOUT1\0", 1, 8, f) == 8 &&
         fwrite(&n_value, sizeof(double), 1, f) == 1 &&
         fwrite(y->p_bio, sizeof(double), n, f) == n &&
         fwrite(y->rcs, sizeof(double), n, f) == n &&
         fwrite(y->grade, 1, n, f) == n &&
         fwrite(y->route, 1, n, f) == n;
    fclose(f);
    return ok;
}

int main(int argc, char **argv) {
    Arguments args;
    Input input;
    Output output;
    double read_sec, compute_sec, write_sec, start, block_sec = NAN;
    int loops = 1, attempts = 0, floor_passed = 0, i;

    if (!parse_args(argc, argv, &args)) {
        fprintf(stderr, "Invalid arguments.\n"); return 2;
    }
    start = now_seconds();
    if (!read_input(args.input, &input)) { fprintf(stderr, "Cannot read input.\n"); return 1; }
    read_sec = now_seconds() - start;
    if (!allocate_output(input.n, &output)) { free_input(&input); return 1; }

    if (strcmp(args.mode, "e2e") == 0) {
        start = now_seconds();
        if (!score_once(&input, &output)) { free_output(&output); free_input(&input); return 1; }
        compute_sec = now_seconds() - start;
        start = now_seconds();
        if (!write_output(args.output, input.n, &output)) { free_output(&output); free_input(&input); return 1; }
        write_sec = now_seconds() - start;
        printf("RCSPHASES,%.12g,0,%.12g,%.12g,%.12g\n", read_sec, compute_sec, write_sec, read_sec + compute_sec + write_sec);
        printf("RCSRESULT,%s,%zu,1,1,NA,NA,FALSE,0\n", args.implementation, input.n);
        free_output(&output); free_input(&input); return 0;
    }

    for (i = 0; i < args.warmups; ++i) if (!score_once(&input, &output)) { free_output(&output); free_input(&input); return 1; }
    while (1) {
        int k;
        ++attempts;
        start = now_seconds();
        for (k = 0; k < loops; ++k) if (!score_once(&input, &output)) { free_output(&output); free_input(&input); return 1; }
        block_sec = now_seconds() - start;
        if (isfinite(block_sec) && block_sec >= args.min_sec) { floor_passed = 1; break; }
        if (loops >= args.max_loops) break;
        {
            long long estimate = (long long)loops * 2LL;
            long long doubled = (long long)loops * 2LL;
            long long next;
            if (isfinite(block_sec) && block_sec > 0.0)
                estimate = (long long)ceil(1.10 * loops * args.min_sec / block_sec);
            next = estimate > doubled ? estimate : doubled;
            if (next <= loops) next = (long long)loops + 1LL;
            if (next > args.max_loops) next = args.max_loops;
            loops = (int)next;
        }
    }
    compute_sec = block_sec / loops;
    if (!write_output(args.output, input.n, &output)) { free_output(&output); free_input(&input); return 1; }
    printf("RCSRESULT,%s,%zu,1,%d,%.12g,%.12g,%s,%d\n",
           args.implementation, input.n, loops, compute_sec, block_sec,
           floor_passed ? "TRUE" : "FALSE", attempts);
    free_output(&output); free_input(&input); return 0;
}
