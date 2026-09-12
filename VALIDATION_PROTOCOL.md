# RCS scientific validation protocol

This protocol defines the executable scientific-validation analyses used in the RCS reproducibility package. It complements `SCIENTIFIC_SPECIFICATION.md`: the scientific rules are language-independent, the ISO C11 implementation is the computational reference, and the R scripts are an analysis harness used for deterministic validation experiments and summary generation.

The validation protocol is intentionally separated from performance benchmarking. Benchmark methodology is defined in `BENCHMARK_PROTOCOL.md`.

## Deterministic seed

The default validation seed is:

```text
RCS_SEED = 20260504
```

It can be overridden with the `RCS_SEED` environment variable. Validation scripts source the shared configuration before generating stochastic inputs.

## Property-based logical checks

`scripts/03_property_checks.R` verifies the following properties:

- governance failure routes directly to Grade E;
- `RCS = 100 - P_bio` within numerical tolerance `1e-9`;
- `P_bio` remains in `[0,100]` for scoreable profiles;
- increasing one severity while holding the remaining axes fixed cannot reduce `P_bio` or increase the RCS;
- identical inputs produce identical outputs;
- the fluid and solid matrices contain distinct matrix-specific axes and each weight vector sums to 100;
- a `Not scored`/unresolved axis is never represented as zero severity and instead produces a non-compensable governance-failure route with no numerical `P_bio` or RCS.

The synthetic cohort used by these logical checks contains 50 profiles per scenario and matrix.

## Synthetic internal validation

`scripts/04_synthetic_validation.R` uses six predefined scenarios for each matrix. The default number of profiles is 500 per scenario and matrix (`N_PER_SCENARIO=500`), yielding 6,000 profiles in the default run.

The scenario targets used by the generator are:

| Scenario | Target `P_bio` | Jitter SD |
|---|---:|---:|
| `optimal` | 5 | 1.5 |
| `mild_suboptimal` | 15 | 2.0 |
| `moderate_suboptimal` | 27 | 3.0 |
| `severe_suboptimal` | 42 | 3.0 |
| `critical_penalty_burden` | 65 | 5.0 |
| `governance_failure` | 5 | 1.5 |

For each generated profile, the scenario-level penalty target is sampled from a normal distribution with the values above and truncated to `[0,90]`. Each matrix-specific axis severity is then generated as the sampled penalty divided by 100 plus independent normal jitter with standard deviation `0.015`, truncated to `[0,1]`.

The expected grades are A, B, C, D, E, and E respectively for the six scenarios. The governance-failure scenario is forced through the governance route rather than through additive penalty scoring.

The analysis reports the synthetic cohort, internal calibration index, grade distribution, governance-failure count, and critical-penalty count.

## Combinatorial validation

The admissible combinatorial experiment discretizes every matrix-specific severity axis into:

```text
{0, 0.25, 0.50, 0.75, 1.00}
```

There are five axes per matrix, therefore:

```text
5^5 = 3125 profiles per matrix
```

The combinatorial experiment is restricted to governance-admissible profiles by design. Governance failures are evaluated separately. No change to this discretization is made during validation.

The analysis reports the grade distribution and the distance of each scoreable profile from the nearest `P_bio` grade threshold at 10, 20, 35, or 50.

## One-axis analysis

For each fluid and solid axis, the selected axis is varied from `0` to `1` in increments of `0.05` while all other axes remain at zero. This experiment is used to expose the isolated contribution of each weighted axis across its full severity domain.

## Threshold-transition perturbation

Each axis weight is perturbed independently under five scenarios:

```text
-20%, -10%, nominal, +10%, +20%
```

After changing the selected weight, the complete matrix weight vector is renormalized so that:

```text
sum(W_i) = 100
```

For the renormalized selected weight, the analysis determines whether a severity in `[0,1]` can reach each penalty transition threshold:

```text
A to B: P_bio = 10
B to C: P_bio = 20
C to D: P_bio = 35
D to E: P_bio = 50
```

The detailed transition table is the source from which the summary table is deterministically derived.

## Governance sensitivity analysis

The R analysis harness evaluates isolated governance-failure categories independently from the combinatorial severity experiment. These analysis-side categories are metadata incompleteness, invalid terminology, traceability failure, monitoring failure, documentation failure, and semantic incompatibility.

This analysis harness does not replace the complete C governance model. The computational reference API aggregates the fourteen explicit evidence categories defined in `GOVERNANCE_MODEL.md` and requires explicit evidence before scoring.

## Weight perturbation sensitivity

For each matrix, `scripts/06_sensitivity_ablation.R` generates an admissible synthetic cohort using 100 profiles per scenario and retains the scoreable profiles for that matrix.

The weight-perturbation experiment performs 1,000 iterations per matrix. At each iteration, every baseline weight is multiplied by an independent factor drawn from:

```text
N(1, 0.10)
```

with a lower bound of `0.05` on the multiplicative factor. The perturbed weights are then renormalized to:

```text
sum(W_i) = 100
```

For each iteration, the analysis records the proportion of profiles whose final grade changes and the mean absolute RCS shift from the baseline weights.

## Analytical global sensitivity

For the additive penalty model:

```text
P_bio = sum_i W_i * s_i
```

the elementary effect of axis `i` for any finite step `Delta` that remains inside `[0,1]` is:

```text
[P_bio(s + Delta e_i) - P_bio(s)] / Delta = W_i
```

Because all RCS weights are positive, the analytical Morris `mu*` is exactly `W_i`.

For independent severity inputs with the same finite, non-zero variance, the first-order variance contribution of axis `i` is:

```text
W_i^2 / sum_j W_j^2
```

Under those assumptions, the additive model has no interaction variance. The implementation verifies the Morris identity with a deterministic finite difference using baseline severity `0.25` and `Delta=0.25`, verifies that first-order variance shares sum to one, and verifies zero interaction contribution. No Monte Carlo Morris or Sobol estimator is executed.

## Ablation analysis

The ablation experiment uses a synthetic cohort with 200 profiles per scenario and matrix and compares:

- the full governance-aware RCS;
- the same profiles without the governance override, using only the score-based grade;
- equal axis weights (`20` for each of the five axes) while preserving the governance override.

The resulting grade distributions are compared at the model level.

## Output scopes

Validation outputs are never written directly to retained publication results unless publication writing is explicitly enabled.

The default scopes are:

```text
local       -> outputs/local/
smoke       -> outputs/smoke/
publication -> results/publication/
```

Publication writes require:

```text
RCS_ALLOW_PUBLICATION_WRITE=TRUE
```

and the normal final-run configuration uses:

```text
RCS_RUN_SCOPE=publication
RCS_ALLOW_PUBLICATION_WRITE=TRUE
```

`RCS_OUTPUT_ROOT` may be supplied to redirect a run to another isolated directory, including CI temporary directories. The resolved override path is validated against the protected `results/publication/` tree before any output directory is created. Therefore an override that resolves to `results/publication/` or any descendant is rejected unless `RCS_ALLOW_PUBLICATION_WRITE=TRUE`, even when `RCS_RUN_SCOPE` is `local` or `smoke`.

The final GCP execution will be performed only after the repository code and validation protocol are frozen. Until that execution is completed and promoted, `results/publication/` must not be interpreted as containing final study results.
