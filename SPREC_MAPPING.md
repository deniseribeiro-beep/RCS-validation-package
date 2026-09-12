# Executable SPREC 2.0 to RCS severity mapping

This layer implements the SPREC-to-RCS severity rules supplied in **Supplementary File 1. SPREC Reference and Severity Tables**. It does not redefine SPREC and it does not infer a severity when the supplementary mapping does not provide enough information.

## Repository artifacts

- `reference/sprec2_fluid_reference.csv` mirrors Supplementary Table S1 (SPREC 2.0 descriptors for fluid samples).
- `reference/sprec2_solid_reference.csv` mirrors Supplementary Table S2 (SPREC 2.0 descriptors for solid samples).
- `reference/rcs_sprec_severity_mapping.csv` is the machine-readable mirror of Supplementary Table S3.
- `include/rcs_sprec.h` defines the C resolution API and the explicit contexts required by conditional Table S3 rules.
- `src/rcs_sprec.c` is the executable C implementation of those rules.

SPREC 2.0 is the fixed SPREC baseline represented by this mapping. No SPREC 3.0 or 4.0 code is silently interpreted as SPREC 2.0.

## Matrix-specific RCS axes

Fluid biospecimens use `P_pre`, `P_cent1`, `P_cent2`, `P_post`, and `P_store`.

Solid biospecimens use `P_warm`, `P_cold`, `P_fix`, `P_fixTime`, and `P_store`.

A code presented on an axis that does not belong to the selected matrix is `Not scored` because Supplementary Table S3 treats matrix/axis semantic incompatibility as a non-additive condition.

## Conditional mappings represented explicitly

The conditional entries in Supplementary Table S3 are not guessed from the SPREC code alone. The caller must supply the documented context when the code requires it.

### Primary centrifugation, code N

- unseparated whole blood, dried blood, or a cellular matrix not requiring plasma or serum separation -> severity `0.00`;
- plasma, serum, cell-free plasma, platelet-poor plasma, or another separated fluid fraction required -> severity `1.00`;
- unresolved intended workflow -> `Not scored`.

### Second centrifugation, code N

- workflow does not require platelet-poor, cell-free, or highly clarified plasma -> severity `0.00`;
- routine plasma or serum analysis where a second centrifugation is not mandatory but would reduce residual cellular or platelet contamination -> severity `0.25`;
- platelet-poor plasma, cell-free plasma, plasma DNA, miRNA, extracellular vesicle, or another low-cell-contamination workflow required -> severity `1.00`;
- unresolved intended workflow -> `Not scored`.

### Long-term storage, code Y

- documented storage at -85 to -60 °C -> severity `0.25`;
- documented storage at -35 to -18 °C -> severity `0.60`;
- unresolved or undocumented storage temperature -> `Not scored`.

### Long-term storage, codes P/R

For fluid biospecimens:

- compatible with the intended archival, morphological, dried-matrix, or validated local workflow -> severity `0.25`;
- native molecular integrity, viable cells, cryopreserved fluid matrix, or ultra-low-temperature preservation required -> severity `1.00`;
- downstream workflow undocumented or local compatibility not validated -> `Not scored`.

For solid biospecimens:

- compatible with the intended archival, morphological, dried-matrix, FFPE-compatible, or validated local workflow -> severity `0.25`;
- snap-frozen tissue, viable cells, native protein/RNA preservation, or ultra-low-temperature storage required -> severity `1.00`;
- downstream workflow undocumented or local compatibility not validated -> `Not scored`.

### Fixation/stabilization type

The base mapping is `0.00` for `SNP/PXT/RNL/ALL/HST`, `0.33` for `NBF/OCT`, and `0.66` for `FOR/ALD/ETH/ACA/NAA`. A recognized fixation or stabilization method that is incompatible with the intended analytical workflow is assigned severity `1.00`, as specified in Supplementary Table S3.

This analytical-workflow incompatibility is distinct from an invalid, unrecognized, or semantically incompatible controlled value. The latter is `Not scored`.

## Non-additive `Not scored` semantics

The C resolver returns `RCS_SPREC_NOT_SCORED` with a non-numeric severity for:

- missing values;
- `X/XXX` unknown values;
- invalid or unrecognized controlled codes;
- `Z/ZZZ` other or non-standard values for which this standard mapping has no validated local severity rule;
- matrix/axis semantic incompatibility;
- an explicitly indicated semantic incompatibility with recorded specimen context;
- unresolved context for a conditional Table S3 rule.

`Not scored` never means severity zero. The complete reference API will route such conditions through the non-compensable governance layer before additive RCS scoring.
