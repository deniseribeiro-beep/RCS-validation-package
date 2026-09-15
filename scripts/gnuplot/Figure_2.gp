reset

FIGURE_NAME = "Figure_2"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 4.10

# Shared style configures the pdfcairo terminal and opens the output PDF as:
#   OUTPUT_DIR/FIGURE_NAME.pdf
# OUTPUT_DIR is supplied by the generation wrapper or defaults in the style file.
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Synthetic_Validation_Grade_Distribution.csv", TABLES_DIR)

# Keep only left and bottom borders to reduce visual heaviness.
set border 3 linewidth 1.0 linecolor rgb "#6E6E6E"

scenario_id(s) = s eq "optimal" ? 1 : \
                 s eq "mild_suboptimal" ? 2 : \
                 s eq "moderate_suboptimal" ? 3 : \
                 s eq "severe_suboptimal" ? 4 : \
                 s eq "critical_penalty_burden" ? 5 : \
                 s eq "governance_failure" ? 6 : 1/0

grade_id(s) = s eq "Grade A" ? 1 : \
              s eq "Grade B" ? 2 : \
              s eq "Grade C" ? 3 : \
              s eq "Grade D" ? 4 : \
              s eq "Grade E" ? 5 : 1/0

unset key
unset grid

set xrange [0.5:6.5]
set yrange [5.5:0.5]

set xtics ( \
    "Optimal" 1, \
    "Mild\nsuboptimal" 2, \
    "Moderate\nsuboptimal" 3, \
    "Severe\nsuboptimal" 4, \
    "Critical\npenalty" 5, \
    "Governance\nfailure" 6 \
) font "Sans,9"

set ytics ( \
    "Grade A" 1, \
    "Grade B" 2, \
    "Grade C" 3, \
    "Grade D" 4, \
    "Grade E" 5 \
) font "Sans,10"

# Proportion palette.
# Use lighter blue tones to avoid a gray-heavy appearance while preserving
# the visual distinction between low and high proportions.
set palette defined ( \
    0.00 "#EEF4FF", \
    0.02 "#E8F1FF", \
    0.25 "#D7E6FC", \
    0.50 "#AFCBFA", \
    0.75 "#7FAAF4", \
    1.00 "#4B86E8" \
)

set cbrange [0:1]

set cbtics ( \
    "0" 0, \
    "25" 0.25, \
    "50" 0.50, \
    "75" 0.75, \
    "100" 1 \
) font "Sans,9"

# Fill matrix cells without borders.
set style fill solid 1.0 noborder

# ---------------------------------------------------------------------------
# Background cells
# ---------------------------------------------------------------------------
# Draw one very light-blue rectangle for every scenario/grade combination.
# These objects sit behind the data and ensure that cells without an observed
# proportion do not blend into the page background.
#
# Rectangle half-width/half-height = 0.48 leaves the same narrow visual gap
# between cells already present in the reference figure.

do for [yy=1:5] {
    do for [xx=1:6] {
        object_id = (yy - 1) * 6 + xx
        set object object_id rectangle \
            from first (xx - 0.48),(yy - 0.48) \
            to first (xx + 0.48),(yy + 0.48) \
            behind \
            fillcolor rgb "#EEF4FF" \
            fillstyle solid 1.0 \
            noborder
    }
}

set label 900 "Synthetic validation scenario" \
    at screen 0.50,0.055 center font "Sans,11"

set label 902 "Cells without a numeric label indicate 0% proportion." \
    at screen 0.50,0.028 center font "Sans,9" tc rgb "#555555"

set multiplot layout 1,2 rowsfirst \
    margins 0.10,0.90,0.20,0.91 \
    spacing 0.065,0.0


# ---------------------------------------------------------------------------
# Fluid matrix
# ---------------------------------------------------------------------------

set ylabel "Assigned RCS grade" offset 0.6,0 font "Sans,11"
unset colorbox

set label 100 "Fluid biospecimens" \
    at graph 0.5,1.065 center font "Sans,11"

plot \
    DATA every ::1 using ( \
        (stringcolumn("matrix") eq "fluid") \
        ? scenario_id(stringcolumn("scenario")) \
        : 1/0 \
    ):( \
        grade_id(stringcolumn("final_grade")) \
    ):(0.48):(0.48):(column("proportion")) \
        with boxxyerror \
        linecolor palette \
        fillstyle solid 1.0 \
        noborder \
        notitle, \
    DATA every ::1 using ( \
        (stringcolumn("matrix") eq "fluid") \
        ? scenario_id(stringcolumn("scenario")) \
        : 1/0 \
    ):( \
        grade_id(stringcolumn("final_grade")) \
    ):( \
        column("proportion") <= 0.55 \
        ? sprintf("%.1f",100.0*column("proportion")) \
        : "" \
    ) \
        with labels \
        center \
        font "Sans,9" \
        textcolor rgb "#202020" \
        notitle, \
    DATA every ::1 using ( \
        (stringcolumn("matrix") eq "fluid") \
        ? scenario_id(stringcolumn("scenario")) \
        : 1/0 \
    ):( \
        grade_id(stringcolumn("final_grade")) \
    ):( \
        column("proportion") > 0.55 \
        ? sprintf("%.1f",100.0*column("proportion")) \
        : "" \
    ) \
        with labels \
        center \
        font "Sans,9" \
        textcolor rgb "#FFFFFF" \
        notitle

unset label 100


# ---------------------------------------------------------------------------
# Solid matrix
# ---------------------------------------------------------------------------

unset ylabel
unset ytics

set label 101 "Solid biospecimens" \
    at graph 0.5,1.065 center font "Sans,11"

set colorbox vertical \
    user origin screen 0.925,0.27 \
    size screen 0.020,0.52

set cblabel "Proportion (%)" offset 1.0,0 font "Sans,10"

plot \
    DATA every ::1 using ( \
        (stringcolumn("matrix") eq "solid") \
        ? scenario_id(stringcolumn("scenario")) \
        : 1/0 \
    ):( \
        grade_id(stringcolumn("final_grade")) \
    ):(0.48):(0.48):(column("proportion")) \
        with boxxyerror \
        linecolor palette \
        fillstyle solid 1.0 \
        noborder \
        notitle, \
    DATA every ::1 using ( \
        (stringcolumn("matrix") eq "solid") \
        ? scenario_id(stringcolumn("scenario")) \
        : 1/0 \
    ):( \
        grade_id(stringcolumn("final_grade")) \
    ):( \
        column("proportion") <= 0.55 \
        ? sprintf("%.1f",100.0*column("proportion")) \
        : "" \
    ) \
        with labels \
        center \
        font "Sans,9" \
        textcolor rgb "#202020" \
        notitle, \
    DATA every ::1 using ( \
        (stringcolumn("matrix") eq "solid") \
        ? scenario_id(stringcolumn("scenario")) \
        : 1/0 \
    ):( \
        grade_id(stringcolumn("final_grade")) \
    ):( \
        column("proportion") > 0.55 \
        ? sprintf("%.1f",100.0*column("proportion")) \
        : "" \
    ) \
        with labels \
        center \
        font "Sans,9" \
        textcolor rgb "#FFFFFF" \
        notitle

unset label 101

unset multiplot
unset label 900
unset label 902

# The shared style file opened OUTPUT_DIR/FIGURE_NAME.pdf with `set output`.
# Explicitly close that PDF here so all buffered drawing commands are finalized.
unset output