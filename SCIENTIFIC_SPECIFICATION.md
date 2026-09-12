# RCS scientific specification

This document separates the scientific definition of the Ribeiro Classification Score (RCS) from any programming language used to implement it. The scientific rules are defined by the manuscript and its supplementary files. The C implementation in this repository is the computational reference implementation of those rules; R, Cython, C++, OpenMP, and CUDA implementations are secondary implementations used for equivalence and benchmarking.

## Scientific precedence

The scientific definition is language-independent. In case of implementation disagreement, the manuscript and supplementary rules define the intended method, and the C reference implementation must be corrected to match them before other implementations are considered equivalent.

The governance-aware certification order is:

1. evaluate governance admissibility from SPREC codes, metadata, and telemetry/context evidence;
2. if governance admissibility is not established, do not perform additive RCS scoring;
3. select the matrix-specific RCS axes;
4. resolve each observed SPREC-coded condition to its intra-axis severity;
5. compute the weighted biological-operational penalty;
6. compute the RCS and assign the deterministic grade and route.

The executable SPREC mapping and governance-evidence aggregation are maintained as explicit layers of the reference implementation. The low-level scoring core receives severities only after those layers have resolved them.

## Metadata-governance admissibility

Supplementary File 2, Supplementary Methods S1 and Supplementary Table S1 define the non-compensable governance layer. The executable implementation preserves fourteen evidence categories spanning MIABIS-derived metadata, ISO 20387-derived quality and traceability, ISBER-informed operational governance, and semantic/context validation.

Every evidence item must be supplied explicitly. Missing evidence is never interpreted as satisfied. The governance evaluator distinguishes satisfied, failed, unresolved, and explicitly not-applicable evidence. `NOT_APPLICABLE` is accepted for storage monitoring only when thermal control has explicitly been declared irrelevant, reflecting the Supplementary Table S1 statement that storage monitoring is required when thermal control is relevant.

The richer governance outcomes are `ADMISSIBLE`, `REVIEW_REQUIRED`, `RESTRICTED`, `QUARANTINED`, and `FAILED`. Only `ADMISSIBLE` maps to a passing binary governance gate and permits additive RCS scoring. Review, restriction, quarantine, and failure remain non-compensable states and block scoring until resolved.

For Supplementary Table S1 categories whose consequence is context-dependent, the implementation does not invent the institutional or technical disposition. Nonconformity control, deviation documentation, and semantic/context validity require an explicit upstream disposition when their evidence is not satisfied.

## Matrices, axes, and maximum weights

### Fluid biospecimens

| Axis | Maximum weight |
|---|---:|
| `P_pre` | 30 |
| `P_cent1` | 15 |
| `P_cent2` | 10 |
| `P_post` | 20 |
| `P_store` | 25 |

### Solid biospecimens

| Axis | Maximum weight |
|---|---:|
| `P_warm` | 25 |
| `P_cold` | 25 |
| `P_fix` | 15 |
| `P_fixTime` | 20 |
| `P_store` | 15 |

For either matrix, the weights sum to 100.

## Additive scoring rule

For a governance-admissible biospecimen of matrix `k`, each resolved intra-axis severity `s_i(x_i)` must be numerical and lie in the closed interval `[0,1]`.

```text
p_i^(k)   = W_i^(k) * s_i(x_i)
P_bio^(k) = sum_i p_i^(k)
RCS^(k)   = 100 - P_bio^(k)
```

Unknown, missing, invalid, unrecognized, semantically incompatible, locally unresolved, or insufficiently documented SPREC-coded conditions are not converted to severity zero. They are `Not scored` conditions and are handled by the non-compensable governance layer rather than by additive penalty scoring.

## Deterministic classification

For governance-admissible profiles:

| RCS interval | Final grade | Route |
|---|---|---|
| `RCS >= 90` | Grade A | score-based certification |
| `80 <= RCS < 90` | Grade B | score-based certification |
| `65 <= RCS < 80` | Grade C | score-based certification |
| `50 <= RCS < 65` | Grade D | score-based certification |
| `RCS < 50` | Grade E | critical penalty-burden condition |

If governance is not admissible, additive `P_bio`/RCS scoring is not performed. The complete high-level API will convert the governance result to the governance-failure Grade E route in accordance with Algorithm S1.

## Computational reference

The reference computational implementation is written in ISO C11. Its current layers are:

```text
include/rcs_reference.h        / src/rcs_reference.c        - deterministic weighted scoring core
include/rcs_sprec_reference.h  / src/rcs_sprec_reference.c  - executable SPREC 2.0 Tables S1/S2 vocabulary validation
include/rcs_sprec.h            / src/rcs_sprec.c            - executable SPREC 2.0 Table S3 severity resolution
include/rcs_governance.h       / src/rcs_governance.c       - executable Supplementary File 2 Table S1 governance aggregation
```

The SPREC reference and severity-resolution layers implement Supplementary File 1 and are documented in [`SPREC_MAPPING.md`](SPREC_MAPPING.md). Machine-readable mirrors of Supplementary Tables S1-S3 are retained under `reference/`.

The governance layer implements Supplementary File 2, Supplementary Methods S1 and Supplementary Table S1 and is documented in [`GOVERNANCE_MODEL.md`](GOVERNANCE_MODEL.md). Its machine-readable evidence model is retained as `reference/governance_evidence_model.csv`.

At this stage `rcs_score_resolved()` remains the low-level deterministic scoring function for already-resolved severities and a resolved governance decision. The next high-level C API layer will combine governance evaluation, SPREC validation/resolution, and weighted scoring without changing the scientific rules implemented by those layers.

Other language implementations do not define the RCS. Their outputs must be shown equivalent to the C reference implementation before their benchmark timings are accepted.
