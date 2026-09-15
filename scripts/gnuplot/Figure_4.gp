reset

FIGURE_NAME = "Figure_4"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 4.55

# Shared style configures the pdfcairo terminal and opens the output PDF as:
#   OUTPUT_DIR/FIGURE_NAME.pdf
# OUTPUT_DIR is supplied by the generation wrapper or defaults in the style file.
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Threshold_Transition_Detail.csv", TABLES_DIR)

# The source CSV contains a header and is accessed below by column name.
set datafile columnheaders

# Light panel borders, matching the visual treatment adopted for Figure 2.
set border 3 linewidth 1.0 linecolor rgb "#6E6E6E"

array TRANS_KEY[4]
TRANS_KEY[1] = "A to B"
TRANS_KEY[2] = "B to C"
TRANS_KEY[3] = "C to D"
TRANS_KEY[4] = "D to E"

array FLUID_AXIS[5]
FLUID_AXIS[1] = "P_pre"
FLUID_AXIS[2] = "P_cent1"
FLUID_AXIS[3] = "P_cent2"
FLUID_AXIS[4] = "P_post"
FLUID_AXIS[5] = "P_store"

array SOLID_AXIS[5]
SOLID_AXIS[1] = "P_warm"
SOLID_AXIS[2] = "P_cold"
SOLID_AXIS[3] = "P_fix"
SOLID_AXIS[4] = "P_fixTime"
SOLID_AXIS[5] = "P_store"


# ---------------------------------------------------------------------------
# Build compact 4 × 5 matrices
# ---------------------------------------------------------------------------

set print $FLUID
do for [i=1:5] {
    do for [j=1:4] {
        stats DATA every ::1 using ( \
            (stringcolumn("matrix") eq "fluid" && \
             stringcolumn("axis") eq FLUID_AXIS[i] && \
             stringcolumn("threshold_transition") eq TRANS_KEY[j] && \
             stringcolumn("reached") eq "TRUE") \
            ? 1 : 0 \
        ) nooutput

        reached_n = STATS_sum
        print sprintf("%d,%d,%.0f", j, i, reached_n)
    }
}
set print

set print $SOLID
do for [i=1:5] {
    do for [j=1:4] {
        stats DATA every ::1 using ( \
            (stringcolumn("matrix") eq "solid" && \
             stringcolumn("axis") eq SOLID_AXIS[i] && \
             stringcolumn("threshold_transition") eq TRANS_KEY[j] && \
             stringcolumn("reached") eq "TRUE") \
            ? 1 : 0 \
        ) nooutput

        reached_n = STATS_sum
        print sprintf("%d,%d,%.0f", j, i, reached_n)
    }
}
set print

# $FLUID and $SOLID do not have headers. If this remains enabled, the first row
# is discarded and the upper-left cell disappears.
unset datafile columnheaders


unset key
unset grid

set xrange [0.5:4.5]
set yrange [5.5:0.5]

set xtics ( \
    "A→B" 1, \
    "B→C" 2, \
    "C→D" 3, \
    "D→E" 4 \
) font "Sans,10" textcolor rgb "#303030"

# ---------------------------------------------------------------------------
# Palette — same light-blue visual language used in Figure 2
# ---------------------------------------------------------------------------

set palette maxcolors 6 defined ( \
    0 "#EEF4FF", \
    1 "#E2ECFF", \
    2 "#CFE0FC", \
    3 "#B5CDF9", \
    4 "#89B1F3", \
    5 "#4B86E8" \
)

set cbrange [0:5]

set cbtics ( \
    "0" 0, \
    "1" 1, \
    "2" 2, \
    "3" 3, \
    "4" 4, \
    "5" 5 \
) font "Sans,10" textcolor rgb "#303030"

set style fill solid 1.0 noborder

# ---------------------------------------------------------------------------
# Shared labels
# ---------------------------------------------------------------------------

set label 1000 "RCS grade-transition threshold" \
    at screen 0.50,0.110 center font "Sans,14"

set label 901 "Weight settings reaching threshold (0–5 of 5)" \
    at screen 0.50,0.070 center font "Sans,12"

set label 902 \
    "Cells labeled 0/5 indicate that none of the five weight settings reached the threshold." \
    at screen 0.50,0.025 center font "Sans,10" tc rgb "#555555"

# Keep the two matrices large while reserving space at the right for the
# vertical color scale, following the Figure 2 layout.
set multiplot layout 1,2 rowsfirst \
    margins 0.14,0.89,0.23,0.91 \
    spacing 0.105,0.0


# ---------------------------------------------------------------------------
# Fluid biospecimens
# ---------------------------------------------------------------------------

set ytics ( \
    "Pre-centrif. delay" 1, \
    "Primary centrif." 2, \
    "Second centrif." 3, \
    "Post-centrif. delay" 4, \
    "Storage" 5 \
) font "Sans,10" textcolor rgb "#303030"

set label 100 "Fluid biospecimens" \
    at graph 0.5,1.065 center font "Sans,11"

unset colorbox

plot \
    $FLUID using 1:2:(0.48):(0.48):3 \
        with boxxyerror \
        linecolor palette \
        fillstyle solid 1.0 \
        noborder \
        notitle, \
    $FLUID using 1:2:($3 < 4 ? sprintf("%d/5",int($3)) : "") \
        with labels \
        center \
        font "Sans,10" \
        tc rgb "#202020" \
        notitle, \
    $FLUID using 1:2:($3 >= 4 ? sprintf("%d/5",int($3)) : "") \
        with labels \
        center \
        font "Sans,10" \
        tc rgb "#FFFFFF" \
        notitle

unset label 100


# ---------------------------------------------------------------------------
# Solid biospecimens
# ---------------------------------------------------------------------------

set ytics ( \
    "Warm ischemia" 1, \
    "Cold ischemia" 2, \
    "Fixation / stabil." 3, \
    "Fixation time" 4, \
    "Storage" 5 \
) font "Sans,10" textcolor rgb "#303030"

set label 101 "Solid biospecimens" \
    at graph 0.5,1.065 center font "Sans,11"

# Vertical scale on the right, following Figure 2.
set colorbox vertical \
    user origin screen 0.915,0.29 \
    size screen 0.020,0.50

plot \
    $SOLID using 1:2:(0.48):(0.48):3 \
        with boxxyerror \
        linecolor palette \
        fillstyle solid 1.0 \
        noborder \
        notitle, \
    $SOLID using 1:2:($3 < 4 ? sprintf("%d/5",int($3)) : "") \
        with labels \
        center \
        font "Sans,10" \
        tc rgb "#202020" \
        notitle, \
    $SOLID using 1:2:($3 >= 4 ? sprintf("%d/5",int($3)) : "") \
        with labels \
        center \
        font "Sans,10" \
        tc rgb "#FFFFFF" \
        notitle

unset label 101

unset multiplot
unset label 900
unset label 901
unset label 902

# The shared style file opened OUTPUT_DIR/FIGURE_NAME.pdf with `set output`.
# Explicitly close that PDF here so all buffered drawing commands are finalized.
unset output