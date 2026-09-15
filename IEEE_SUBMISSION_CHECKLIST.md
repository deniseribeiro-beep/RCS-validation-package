# IEEE Access submission checklist

This checklist covers manuscript and artifact items that cannot all be enforced
inside the source repository. Complete it against the final files submitted to
the IEEE Author Portal.

## Repository and Zenodo readiness

The following repository-controlled items have been verified during the release-readiness review:

- [x] Public documentation and metadata are written in English.
- [x] `CITATION.cff` and `.zenodo.json` contain the four authors in manuscript order.
- [x] All four ORCID identifiers have valid check digits.
- [x] Zenodo metadata declare software version 1.0.0, English language, MIT license, open access, description, and keywords.
- [x] Source code, deterministic tests, reference material, retained tables, environment records, PDF figures, reviewer instructions, and checksums are present.
- [x] The release verifier validates metadata, retained quality gates, checksums, one-page PDFs, and embedded fonts.
- [ ] Confirm GitHub Validation CI passes on the final release-readiness pull-request head.
- [ ] Merge all release-readiness pull requests into `main`.
- [ ] Confirm Validation CI completed successfully on the exact resulting `main` commit before creating tag `v1.0.0`.
- [ ] Run the final release-candidate checks listed in `ZENODO_RELEASE.md`.
- [ ] Publish GitHub release `v1.0.0` and verify the resulting Zenodo record.
- [ ] Insert the minted Zenodo version DOI in the manuscript and IEEE supplementary-material entry.

The repository cannot verify manuscript-only items such as the final IEEE template, biographies, affiliations, corresponding-author designation, acknowledgments, reference list, English prose, or agreement between the editable manuscript and its PDF. These require inspection of the final submission files.

## Manuscript package

- [ ] Select `Methods` as the best-aligned manuscript type for this new computational method, unless the handling editor directs otherwise.
- [ ] Use the current mandatory IEEE Access double-column template.
- [ ] Submit both the editable Word/LaTeX source and a matching PDF.
- [ ] Keep each submitted manuscript file below 40 MB.
- [ ] Keep the main article preferably below 20 pages.
- [ ] Use the exact article title recorded in `ARTIFACT_EVALUATION.md`.
- [ ] Use the same author names and order in the source, PDF, portal, Zenodo,
      and `CITATION.cff`.
- [ ] Include a short biography for every author below the references.
- [ ] Ensure the corresponding author's ORCID is public and populated.
- [ ] Verify the names, affiliations, author order, and ORCIDs of all four authors in the source, PDF, IEEE Author Portal, `CITATION.cff`, and `.zenodo.json`.
- [ ] Define each acronym at first use, including RCS and SPREC.
- [ ] Select 3-10 accurate manuscript keywords.
- [ ] Verify every reference for accuracy and retraction status.
- [ ] Perform final technical-English and grammar review.
- [ ] Confirm the article is not under review elsewhere.

## Results and claims

- [ ] State that the C11 implementation is the computational reference.
- [ ] State that benchmark inputs are deterministic, synthetic, and pre-resolved.
- [ ] State that the benchmark measures the scoring/classification kernel rather
      than a complete biobank information-system workflow.
- [ ] Report compute and end-to-end timing regions separately.
- [ ] Do not report cross-language speedup.
- [ ] Compare CUDA acceleration only with C++ sequential.
- [ ] Report 4,200/4,200 calibrated compute measurements passing.
- [ ] Report 139/140 stable compute conditions and the 90% acceptance threshold.
- [ ] Disclose the unstable R/PSOCK compute condition rather than removing it.
- [ ] Describe end-to-end stability as diagnostic and disclose its one unstable
      C-reference condition.
- [ ] Ensure every numerical claim can be traced to a retained CSV table.

## Graphics and supplementary material

- [ ] Confirm Figures 2-7 are the PDFs from the immutable release.
- [ ] Confirm each PDF contains one page and embedded fonts.
- [ ] Ensure figures remain legible at their final manuscript dimensions.
- [ ] Upload applicable supplementary material with the initial submission so it
      can be peer reviewed.
- [ ] Include the GitHub release URL and Zenodo version DOI.

## Ethics and disclosure

- [ ] Confirm that no personal or patient data are present in the artifact.
- [ ] Disclose the exclusive use of synthetic data in Methods and Data
      Availability.
- [ ] Include the finalized AI-use disclosure in Acknowledgments, identify OpenAI ChatGPT and Codex, cite both systems, and identify the affected manuscript and supplementary-artifact sections.
- [ ] Include the Google Cloud Research Credits acknowledgment exactly as supplied by the program.
- [ ] Obtain approval from every author for authorship, order, and final files.

## Suggested Code and Data Availability statement

> The code, deterministic synthetic inputs, retained validation tables,
> benchmark summaries, environment records, and figure-generation scripts are
> available in the versioned RCS validation artifact at [ZENODO VERSION DOI].
> Development history is available at
> https://github.com/deniseribeiro-beep/RCS-validation-package. The archived
> artifact corresponds to release v1.0.0. No personal or patient data were used.

Replace `[ZENODO VERSION DOI]` only after Zenodo has minted the DOI.

## Suggested reproducibility statement

> The artifact provides a C11 computational reference implementation,
> deterministic tests, seeded synthetic validation, cross-implementation
> equivalence checks, retained publication outputs, and three levels of reviewer
> execution described in ARTIFACT_EVALUATION.md. Hardware-dependent timing is
> not expected to be bitwise reproducible; scoring outputs, grades, routes,
> schemas, equivalence tolerances, and declared quality gates are reproducible.

## AI-use disclosure

Use the following statement in the manuscript Acknowledgments section. Preserve
the scope of use and cite the two systems using the manuscript's IEEE reference
numbers in place of the citation keys shown here:

> During preparation of this article and its reproducibility artifact, the
> authors used OpenAI ChatGPT and Codex
> `\cite{openai_chatgpt,openai_codex}` solely to support grammatical review
> and limited textual corrections, LaTeX formatting troubleshooting,
> configuration of the Google Cloud execution environment, and assistance with
> software-testing agents and targeted corrections to validation and Gnuplot
> scripts. AI assistance affected language and LaTeX formatting throughout the
> manuscript and the supplementary artifact's environment-configuration
> instructions, automated tests, validation scripts, and Gnuplot scripts. The
> AI tools were not used to generate the synthetic data, execute or select the
> retained measurements, define the scientific method, interpret the results,
> or formulate the conclusions. All AI-assisted suggestions and code changes
> were reviewed, tested, and validated by the authors, who take full
> responsibility for the final content.

The affected manuscript sections must also cite the applicable AI system, as
required by the current IEEE Access policy. The final reference entries should
identify OpenAI as the organization, the system name, the online URL, and the
actual access date.

## Funding acknowledgment

Include this statement verbatim in the manuscript Acknowledgments or funding
information:

> This material is based upon work supported by the Google Cloud Research
> Credits program with the award number 529423026.
