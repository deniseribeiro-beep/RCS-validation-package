# Zenodo publication procedure

This procedure assumes the official GitHub-Zenodo integration. With this
integration, Zenodo creates the version DOI only after GitHub publishes the
release. Consequently, the immutable `v1.0.0` source archive cannot contain its
own DOI. This is expected and does not make the archived record incomplete: the
Zenodo landing page and citation exports contain the DOI.

## Release candidate checklist

Complete every item before creating the tag:

- [ ] Merge all release-readiness pull requests into `main`.
- [ ] Record the exact resulting merge commit SHA from `main`.
- [ ] Confirm that Validation CI triggered by the push to `main` completed successfully for that exact merge commit.
- [ ] Confirm the repository is public and enabled in the Zenodo GitHub integration.
- [ ] Confirm `CITATION.cff` and `.zenodo.json` contain the same four authors, in the manuscript order, with verified ORCIDs.
- [ ] Confirm the title, version `1.0.0`, MIT license, English language, description, keywords, and open-access status in `.zenodo.json`.
- [ ] Confirm `LICENSE`, `README.md`, `CHANGELOG.md`, `ARTIFACT_EVALUATION.md`, `SHA256SUMS`, source code, tests, retained tables, environment records, and Figures 2-7 are present.
- [ ] Confirm all public-facing documentation, metadata, code comments, table headers, and figure labels are in English.
- [ ] In a clean clone checked out at that exact validated `main` commit, run `bash scripts/verify_release_artifact.sh`.
- [ ] Confirm the manuscript title, author order, affiliations, and ORCIDs match the repository metadata and the IEEE Author Portal.
- [ ] Confirm no patient, participant, personal, secret, credential, transient workspace, or untracked benchmark file is included.

Do not add a guessed, placeholder, or pre-reserved DOI to `.zenodo.json`.
The `doi` field is not required when Zenodo is expected to mint the DOI.

## Create the immutable release

1. Merge all release-readiness pull requests into `main`.
2. Wait for Validation CI to complete successfully on the exact resulting `main` commit.
3. Record and verify that commit SHA.
4. From a clean clone of that exact commit, run `bash scripts/verify_release_artifact.sh`.
5. Create the tag `v1.0.0` from that exact validated commit.
6. Create the GitHub release `v1.0.0` from the tag.
7. Use the release notes provided below and publish the GitHub release.
8. Wait for Zenodo to archive the release.
9. Open the Zenodo record and verify its files and metadata before using the DOI.
10. Record both identifiers:
   - the **version DOI**, which identifies only `v1.0.0`;
   - the **concept DOI**, which resolves to the latest Zenodo version.

## DOI handling after archiving

1. Use the **version DOI** in the manuscript's Code and Data Availability statement and in the IEEE supplementary-material record.
2. Add the Zenodo DOI badge, version DOI, and concept DOI to the moving `main` branch.
3. Add the version DOI to `CITATION.cff` on the moving `main` branch.
4. Do not rewrite, move, delete, or recreate the archived `v1.0.0` tag.
5. Do not create `v1.0.1` merely to place the DOI inside a source archive. Create a later release only for a real metadata, documentation, code, or artifact correction.
6. For a later release, update its version metadata and allow Zenodo to mint a new version DOI under the same concept DOI.

## Suggested GitHub release title

`RCS validation package v1.0.0`

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
