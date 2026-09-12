# RCS scientific specification

This document separates the scientific definition of the Ribeiro Classification Score (RCS) from any programming language used to implement it. The scientific rules are defined by the manuscript and its supplementary files. The C implementation in this repository is the computational reference implementation of those rules; R, Cython, C++, OpenMP, and CUDA implementations are secondary implementations used for equivalence and benchmarking.

## Scientific precedence

The scientific definition is language-independent. In case of implementation disagreement, the manuscript and supplementary rules define the intended method, and the C reference implementation must be corrected to match them before other implementations are considered equivalent.

The governance-aware certification order is:

1. evaluate governance admissibility from SPREC codes, metadata, and telemetry/context evidence;
2. if governance admissibility fails, return Grade E through the governance-failure route before additive RCS scoring;
3. select the matrix-specific RCS axes;
4. resolve each observed SPREC-coded condition to its intra-axis severity;
5. compute the weighted biological-operational penalty;
6. compute the RCS and assign the deterministic grade and route.

The complete executable SPREC mapping and governance-evidence aggregation are maintained as explicit layers of the reference implementation. The low-level scoring core defined below receives severities only after those layers have resolved them.

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

If the governance gate fails, the final result is Grade E through the governance-failure route and additive `P_bio`/RCS scoring is not performed.

## Computational reference

The reference computational implementation is written in ISO C11 and exposed by:

```text
include/rcs_reference.h
src/rcs_reference.c
```

At this stage the low-level function `rcs_score_resolved()` implements the deterministic scoring core for already-resolved severities and an explicit governance decision. The higher-level reference API will add the complete SPREC severity-resolution and governance-aggregation layers without changing this mathematical core.

Other language implementations do not define the RCS. Their outputs must be shown equivalent to the C reference implementation before their benchmark timings are accepted.
