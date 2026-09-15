# Zenodo publication procedure

## Before creating the DOI

1. Merge the release-readiness pull request into `main`.
2. Confirm all GitHub Actions checks are green on the merge commit.
3. Confirm `git status --short` is empty in a clean clone.
4. Run `bash scripts/verify_release_artifact.sh`.
5. Confirm the manuscript title and author order match `CITATION.cff`,
   `.zenodo.json`, `README.md`, and `ARTIFACT_EVALUATION.md`.
6. Add verified ORCID identifiers and affiliations to the Zenodo deposit. Do not
   guess or infer these identifiers.

## Create the archived release

1. Connect the GitHub repository to Zenodo.
2. Enable archiving for `RCS-validation-package`.
3. Create the annotated tag `v1.0.0` on the reviewed `main` commit.
4. Create the GitHub release `v1.0.0` from that tag.
5. Allow Zenodo to archive the release and mint the version DOI.
6. Record both the version DOI and Zenodo concept DOI.

## After Zenodo mints the DOI

1. Add the version DOI to `CITATION.cff` under `doi`.
2. Add the DOI badge and citation to `README.md`.
3. Add the Zenodo identifier to `.zenodo.json` only if required for the next
   release; do not retroactively alter the archived `v1.0.0` tag.
4. Cite the version DOI in the manuscript's Data and Code Availability section.
5. Upload the repository URL and DOI with the supplementary/reproducibility
   material in the IEEE submission system.

## Suggested GitHub release text

> Immutable v1.0.0 reproducibility artifact for *A Governance-Aware Rule-Based
> Computational Method for Biospecimen Qualification in Biobank Information
> Systems*. This release contains the C11 computational reference, deterministic
> synthetic validation, C-reference equivalence checks, retained CPU/GPU
> benchmark results, environment records, and PDF publication figures. See
> `ARTIFACT_EVALUATION.md` for reviewer instructions and `SHA256SUMS` for file
> integrity.

Do not publish another release under the same version after the DOI is minted.
Corrections require a new semantic version and a new version DOI.
