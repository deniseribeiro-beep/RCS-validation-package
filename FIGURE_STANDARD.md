# IEEE Access figure standard for the RCS validation package

This file freezes the graphics conventions used by the project for the figures generated from the archived RCS validation and benchmark outputs.

## IEEE requirements adopted

The project follows the official IEEE Access / IEEE Author Center graphics guidance:

- vector output is preferred; PDF is the primary project figure format;
- one-column width is 3.5 in (88.9 mm) and two-column width is 7.16 in (182 mm);
- raster colour/grayscale graphics must exceed 300 dpi and black-and-white line art must exceed 600 dpi;
- Helvetica is used from the IEEE recommended font list, with text targeted at approximately 9–10 pt at final size;
- PDF fonts must be embedded by the output device;
- line graphs must remain interpretable in grayscale by combining colour with line type and point symbol;
- the IEEE Access manuscript is prepared in double-column format.

Official sources:

- https://ieeeaccess.ieee.org/authors/preparing-your-article/
- https://ieeeaccess.ieee.org/authors/submission-guidelines/
- https://journals.ieeeauthorcenter.ieee.org/create-your-ieee-journal-article/create-graphics-for-your-article/
- https://journals.ieeeauthorcenter.ieee.org/create-your-ieee-journal-article/create-graphics-for-your-article/resolution-and-size/
- https://journals.ieeeauthorcenter.ieee.org/create-your-ieee-journal-article/create-graphics-for-your-article/file-formatting/

## Project conventions

- Canonical file names are `Figure_1`, `Figure_2`, ... in article order.
- Primary output: vector PDF produced with Gnuplot `pdfcairo`.
- Auxiliary review output: PNG produced with `pngcairo` at a nominal 600 dpi at the same physical dimensions.
- Figures use a white background, restrained grid lines, Helvetica, no decorative effects, and no figure title inside the plotting area. The complete figure title and explanation belong in the manuscript caption.
- Colour is never the only discriminator. Numeric annotations, different line styles, and different point symbols are used where applicable.
- Figures read the canonical CSV tables under `outputs/tables/` directly. No persistent `figure_source` cache is generated.
- Speedup is always computed and plotted against the sequential implementation of the same language family. No cross-language speedup is plotted.
- The horizontal `1x` line marks no acceleration. No diagonal ideal-scaling line is used because the reported estimand is paired sequential-to-parallel speedup, not strong scaling from a parallel one-worker baseline.

## Figure mapping

| Figure | Scientific role | Canonical source |
|---|---|---|
| `Figure_1` | Conceptual computational workflow of the governance-aware RCS | Manuscript/model structure; no numeric table |
| `Figure_2` | Synthetic validation heatmap | `Table_Synthetic_Validation_Grade_Distribution.csv` |
| `Figure_3` | Combinatorial distribution of admissible RCS grades | `Table_Combinatorial_Grade_Distribution.csv` |
| `Figure_4` | Threshold-transition stability by isolated axis and perturbation scenario | `Table_Threshold_Transition_Detail.csv` |
| `Figure_5` | Updated R sequential scalability: compute and end-to-end elapsed time and per-profile cost | `Table_Benchmark_Runtime_Summary.csv` |
| `Figure_6` | Within-language parallel scaling at 5,000,000 profiles: R/PSOCK, Cython/OpenMP, and C++/OpenMP | `Table_Benchmark_Within_Language_Speedup_Summary.csv` |
| `Figure_7` | CUDA acceleration relative only to C++ sequential, separating compute and end-to-end timing | `Table_Benchmark_CUDA_Speedup_Summary.csv` |

`Figure_7` is added because the final validated benchmark contains a distinct CUDA result that cannot be represented correctly on the worker/thread x-axis used by `Figure_6`. The manuscript will therefore need to be updated after the figures are validated.

The corrected threshold detail is authoritative for `Figure_4`; in particular, fluid C-to-D contains no reached cases under the archived perturbation scenarios.
