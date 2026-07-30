# RCS validation package revision report

## Scope reviewed

The R scripts were checked against:

- the main manuscript;
- Supplementary File 1 (SPREC reference and severity tables);
- Supplementary File 2 (methods);
- Supplementary File 3 (results, included in the manuscript source package).

## Material corrections

1. **Not-scored semantics**
   - Previous behaviour: missing axis severities were silently replaced by zero.
   - Revised behaviour: missing, invalid, incompatible, or unresolved axis
     severities fail governance/context admissibility and are never interpreted
     as optimal conditions.

2. **Property-based verification**
   - Previous behaviour: the not-scored property was hard-coded as passed.
   - Revised behaviour: an executable test submits an unresolved axis and
     requires governance failure, final Grade E, and missing numerical
     `P_bio/RCS`.

3. **Governance evidence**
   - Previous behaviour: most analyses supplied only a precomputed `G_gov`.
   - Revised behaviour: six explicit evidence fields are evaluated:
     metadata completeness, terminology validity, traceability, monitoring,
     documentation, and semantic compatibility. A conflicting supplied gate is
     rejected.

4. **Input validation**
   - Unknown matrix types are rejected.
   - Admissible profiles require complete matrix-specific severities in `[0,1]`.
   - The scoring routine remains idempotent.

5. **Reproducibility**
   - `RCS_SEED` is read from the execution environment.
   - The main runner verifies that it is launched from the repository root.
   - The parallel benchmark is explicitly enabled with
     `RUN_PARALLEL_BENCH=TRUE`.
   - The environment checker reports package versions, platform, cores, and
     Cairo support.

6. **Figure legibility**
   - Main figures now use 9.0-10.0 inch publication canvases rather than
     oversized 12.2-14.2 inch canvases that shrink typography when inserted
     into the manuscript.
   - Base typography was increased to 13-14 pt.
   - PNG export is 600 dpi and PDF export remains vector-based.

7. **Documentation**
   - The malformed repository README was replaced.
   - An article-to-code crosswalk and exact execution instructions were added.

## Required final execution

The revised scripts must be executed in the target R environment before the
article results are updated. Runtime and parallel-runtime values are
machine-specific. The current package environment used for this review did not
provide an R interpreter, so the revised pipeline was statically reviewed but
not executed here. Existing output files therefore remain the published
baseline until overwritten by the final R run.
