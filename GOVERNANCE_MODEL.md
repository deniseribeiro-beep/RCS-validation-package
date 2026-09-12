# Executable metadata-governance admissibility model

This layer implements the metadata-governance admissibility structure described in **Supplementary File 2, Supplementary Methods S1 and Supplementary Table S1**. It does not convert governance evidence into additive RCS penalties. Its only role is to determine whether a biospecimen is admissible for SPREC-derived RCS scoring or requires failure, review, restriction, or quarantine before scoring.

## Evidence model

The implementation retains all fourteen evidence categories described in Supplementary Table S1:

- MIABIS-derived: sample-level metadata, donor/source linkage, collection context, event-level metadata, metadata completeness;
- ISO 20387-derived: quality management, traceability, nonconformity control, data reliability;
- ISBER-informed: biospecimen handling, storage monitoring, documentation and SOPs, deviation documentation;
- controlled terminology/context: semantic validity and context compatibility.

The machine-readable mirror is `reference/governance_evidence_model.csv`. The executable C API is declared in `include/rcs_governance.h` and implemented in `src/rcs_governance.c`.

## Explicit evidence states

Every evidence category must be supplied explicitly as one of:

- `SATISFIED`;
- `FAILED`;
- `UNRESOLVED`;
- `NOT_APPLICABLE`.

The zero/default C state is `UNSET`, which is rejected by the evaluator. Therefore, a missing field can never be interpreted as satisfied.

`NOT_APPLICABLE` is accepted only for storage monitoring when `thermal_control_relevant=false`, because Supplementary Table S1 states that storage monitoring is required when thermal control is relevant. For all other governance categories, `NOT_APPLICABLE` is rejected unless the scientific specification is later amended to define such applicability explicitly.

## Aggregation policies derived from Supplementary Table S1

Evidence described as **required** for identification, qualification, trajectory reconstruction, governance approval, or reliable downstream qualification is a hard admissibility requirement. A failed or unresolved required item blocks the governance gate.

Evidence described as **supporting** admissibility, auditability, reproducibility, or technical review is not silently promoted to a hard failure. A failed or unresolved supporting item produces `REVIEW_REQUIRED`, and additive RCS scoring remains blocked until that review is resolved.

For the three categories where Supplementary Table S1 explicitly permits more than one consequence, the caller must supply the disposition rather than the RCS inventing it:

- nonconformity control: critical nonconformities may require technical review or restriction;
- deviation documentation: critical deviations may require technical review or quarantine;
- semantic validity/context compatibility: invalid, unrecognized, or severely incompatible codes may require gate failure or technical review.

For these categories, a non-satisfied evidence state without an explicit disposition is rejected as incomplete input.

## Governance outcome and the binary gate

The evaluator can return the richer outcomes:

- `ADMISSIBLE`;
- `REVIEW_REQUIRED`;
- `RESTRICTED`;
- `QUARANTINED`;
- `FAILED`.

Only `ADMISSIBLE` maps to the binary governance gate value `PASS`. All other outcomes are non-admissible for additive RCS scoring until resolved by the upstream governance process.

This preserves Algorithm S1 of Supplementary File 2: governance admissibility is non-compensable and precedes SPREC-derived penalty computation.

## Traceability

The result includes independent bit masks for blocking, review, restriction, and quarantine conditions. Each bit corresponds to one of the fourteen Supplementary Table S1 evidence categories. This preserves the reason for a non-admissible decision without converting governance evidence into a numerical penalty.
