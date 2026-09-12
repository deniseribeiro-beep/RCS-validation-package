# Executable metadata-governance admissibility model

This layer implements the metadata-governance admissibility structure described in **Supplementary File 2, Supplementary Methods S1 and Supplementary Table S1**. It does not convert governance evidence into additive RCS penalties. Its role is to determine whether a biospecimen is admissible for SPREC-derived RCS scoring or requires failure, review, restriction, or quarantine before scoring.

The complete C certification API integrates this governance result with SPREC validation/resolution and weighted scoring. Governance evidence is never inferred from the numerical score.

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

`NOT_APPLICABLE` is accepted only for storage monitoring when `thermal_control_relevant=false`, because Supplementary Table S1 states that storage monitoring is required when thermal control is relevant. For all other governance categories, `NOT_APPLICABLE` is rejected unless the scientific specification is amended to define such applicability explicitly.

## Aggregation policies derived from Supplementary Table S1

Evidence described as **required** for identification, qualification, trajectory reconstruction, governance approval, or reliable downstream qualification is a hard admissibility requirement. A failed or unresolved required item blocks the governance gate.

Evidence described only as **supporting** admissibility, auditability, reproducibility, or technical review is not silently converted into a hard failure. When such evidence is not satisfied, the caller must explicitly route it to technical review; the RCS does not invent a stronger consequence that Supplementary Table S1 does not define.

For categories where Supplementary Table S1 names alternative consequences, the caller must supply the disposition rather than the RCS inventing it:

- nonconformity control: `TECHNICAL_REVIEW` or `RESTRICT`;
- deviation documentation: `TECHNICAL_REVIEW` or `QUARANTINE`;
- semantic validity/context compatibility: `TECHNICAL_REVIEW` or `GATE_FAILURE`.

For quality management, biospecimen handling, and documentation/SOP evidence, the only accepted unresolved/failed disposition is `TECHNICAL_REVIEW`, because Supplementary Table S1 does not define restriction, quarantine, or automatic gate failure for those categories. A non-satisfied evidence item that requires a disposition but omits it is rejected as incomplete input.

## Governance outcome and the binary gate

The evaluator can return the richer outcomes:

- `ADMISSIBLE`;
- `REVIEW_REQUIRED`;
- `RESTRICTED`;
- `QUARANTINED`;
- `FAILED`.

Only `ADMISSIBLE` maps to the binary governance gate value `PASS`. All other outcomes are non-admissible for additive RCS scoring until resolved by the upstream governance process.

In `rcs_certify()`, invalid or incomplete governance input is returned as an input error. A complete but non-admissible governance decision is returned as a scientific non-admissibility result: no numerical `P_bio` or RCS is produced, the final grade is E, and the route is governance failure.

This preserves the non-compensable order defined by the supplementary method: governance admissibility precedes additive penalty computation.

## Relationship with SPREC-derived failures

SPREC controlled-vocabulary validation and severity resolution are separate from the fourteen supplied governance evidence items. A governance profile cannot override a missing, unknown, other/non-standard, invalid, semantically incompatible, or unresolved SPREC condition.

When the SPREC layer returns a non-scoreable condition, the complete API sets the SPREC gate-failure flag and follows the same non-compensable Grade E governance-failure route without assigning a numerical severity of zero.

## Traceability

The governance result includes independent bit masks for blocking, review, restriction, and quarantine conditions. Each bit corresponds to one of the fourteen Supplementary Table S1 evidence categories. This preserves the reason for a non-admissible decision without converting governance evidence into a numerical penalty.
