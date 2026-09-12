# RCS scientific specification

This document separates the scientific definition of the Ribeiro Classification Score (RCS) from any programming language used to implement it. The scientific rules are defined by the manuscript and its supplementary files. The ISO C11 implementation in this repository is the computational reference implementation of those rules. R, Cython, C++, OpenMP, and CUDA implementations are secondary implementations used for equivalence testing, validation analysis, and benchmarking.

## Scientific precedence

The scientific definition is language-independent. In case of implementation disagreement, the manuscript and supplementary rules define the intended method. The C reference implementation must be corrected to match those rules before another implementation can be considered equivalent.

The scientific certification logic is:

1. validate the matrix and the raw SPREC 2.0 components;
2. require explicit governance evidence and aggregate the non-compensable governance decision;
3. stop additive scoring when governance is not admissible;
4. reject unresolved, unknown, other/non-standard, invalid, semantically incompatible, or otherwise `Not scored` SPREC conditions from additive scoring;
5. resolve each scoreable SPREC axis to its intra-axis severity;
6. compute the matrix-specific weighted biological-operational penalty;
7. compute the RCS and assign the deterministic grade and route.

No missing evidence is promoted to satisfied, and no `Not scored` condition is converted to severity zero.

## Metadata-governance admissibility

Supplementary File 2, Supplementary Methods S1 and Supplementary Table S1 define the non-compensable governance layer. The executable C implementation preserves fourteen evidence categories spanning MIABIS-derived metadata, ISO 20387-derived quality and traceability, ISBER-informed operational governance, and semantic/context validation.

Every evidence item must be supplied explicitly. The governance evaluator distinguishes `SATISFIED`, `FAILED`, `UNRESOLVED`, and `NOT_APPLICABLE`; the zero/default `UNSET` state is rejected. `NOT_APPLICABLE` is accepted for storage monitoring only when thermal control has explicitly been declared irrelevant.

The governance outcomes are `ADMISSIBLE`, `REVIEW_REQUIRED`, `RESTRICTED`, `QUARANTINED`, and `FAILED`. Only `ADMISSIBLE` permits additive RCS scoring. Review, restriction, quarantine, and failure remain non-compensable states.

For Supplementary Table S1 categories whose consequence is context-dependent, the implementation does not invent an institutional or technical disposition. The required upstream disposition is supplied explicitly to the governance layer.

The executable governance model is documented in [`GOVERNANCE_MODEL.md`](GOVERNANCE_MODEL.md).

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

Unknown, missing, invalid, unrecognized, semantically incompatible, locally unresolved, or insufficiently documented SPREC-coded conditions are not converted to severity zero. They are `Not scored` conditions and are routed through the non-compensable failure path rather than through additive penalty scoring.

## Deterministic classification

For governance-admissible profiles:

| RCS interval | Final grade | Route |
|---|---|---|
| `RCS >= 90` | Grade A | score-based certification |
| `80 <= RCS < 90` | Grade B | score-based certification |
| `65 <= RCS < 80` | Grade C | score-based certification |
| `50 <= RCS < 65` | Grade D | score-based certification |
| `RCS < 50` | Grade E | critical penalty-burden condition |

When governance is not admissible, or when a SPREC condition is not scoreable, no numerical `P_bio` or RCS is reported. The result follows the governance-failure Grade E route.

## Computational reference

The computational reference is written in ISO C11 and is split into explicit layers:

```text
include/rcs_reference.h        / src/rcs_reference.c
    deterministic weighted scoring core

include/rcs_sprec_reference.h  / src/rcs_sprec_reference.c
    executable SPREC 2.0 Tables S1/S2 controlled-vocabulary validation

include/rcs_sprec.h            / src/rcs_sprec.c
    executable SPREC 2.0 Table S3 severity resolution

include/rcs_governance.h       / src/rcs_governance.c
    executable Supplementary File 2 governance aggregation

include/rcs_certification.h    / src/rcs_certification.c
    complete reference certification API
```

The complete `rcs_certify()` path accepts the selected matrix, seven raw SPREC components, explicit conditional SPREC context, and explicit governance evidence. It validates all seven SPREC positions, evaluates governance, resolves the five score axes, and invokes the deterministic weighted scoring core only when the profile is scoreable and governance-admissible.

The SPREC reference and severity-resolution layers implement Supplementary File 1 and are documented in [`SPREC_MAPPING.md`](SPREC_MAPPING.md). Machine-readable mirrors of Supplementary Tables S1-S3 are retained under `reference/`.

The governance layer implements Supplementary File 2, Supplementary Methods S1 and Supplementary Table S1 and is documented in [`GOVERNANCE_MODEL.md`](GOVERNANCE_MODEL.md). Its machine-readable evidence model is retained as `reference/governance_evidence_model.csv`.

## Reference tests and secondary implementations

`make test` compiles and runs `tests/test_reference.c`. These deterministic tests exercise scoring boundaries, governance failure semantics, SPREC conditional resolution, explicit-governance requirements, complete fluid and solid certification, non-compensable `Not scored` behaviour, and the analytical sensitivity identities used by the validation package.

Other language implementations do not define the RCS. Benchmark expected outputs are generated by the C reference implementation. R, Cython, C++, OpenMP, and CUDA outputs must preserve record order, `P_bio`, RCS, final grade, and route within the configured numerical tolerance before their timings are accepted.

Scientific-validation experiments and their exact executable parameters are documented in [`VALIDATION_PROTOCOL.md`](VALIDATION_PROTOCOL.md). Performance methodology is documented separately in [`BENCHMARK_PROTOCOL.md`](BENCHMARK_PROTOCOL.md).
