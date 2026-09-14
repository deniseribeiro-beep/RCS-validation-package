reset
FIGURE_NAME = "Figure_4"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 4.95
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Threshold_Transition_Detail.csv", TABLES_DIR)
set datafile columnheaders

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

# Collapse the five renormalized weight settings for each axis/transition into
# the number of settings that can reach that RCS grade-transition threshold.
set print $FLUID
do for [i=1:5] {
    do for [j=1:4] {
        stats DATA every ::1 using ((stringcolumn("matrix") eq "fluid" && stringcolumn("axis") eq FLUID_AXIS[i] && stringcolumn("threshold_transition") eq TRANS_KEY[j] && stringcolumn("reached") eq "TRUE") ? 1 : 0) nooutput
        print sprintf("%d,%d,%.0f", j, i, STATS_sum)
    }
}
set print

set print $SOLID
do for [i=1:5] {
    do for [j=1:4] {
        stats DATA every ::1 using ((stringcolumn("matrix") eq "solid" && stringcolumn("axis") eq SOLID_AXIS[i] && stringcolumn("threshold_transition") eq TRANS_KEY[j] && stringcolumn("reached") eq "TRUE") ? 1 : 0) nooutput
        print sprintf("%d,%d,%.0f", j, i, STATS_sum)
    }
}
set print

unset key
unset grid
set xrange [0.5:4.5]
set yrange [5.5:0.5]
set xtics ("A→B" 1, "B→C" 2, "C→D" 3, "D→E" 4) font "Sans,10"
set cbrange [0:5]
# Zero is deliberately light gray rather than white so a 0/5 cell remains a
# visible categorical marker instead of blending into the page background.
set palette maxcolors 6 defined (0 "#E5E7EB", 1 "#D5DDF7", 2 "#BDC9F4", 3 "#95A9EE", 4 "#6D8FE8", 5 "#4A86E8")
set cbtics ("0" 0, "1" 1, "2" 2, "3" 3, "4" 4, "5" 5) font "Sans,9"
unset colorbox

# Reserve a complete lower band for the shared x label and color scale so the
# PDF does not clip the legend at final page width.
set label 900 "RCS grade-transition threshold" at screen 0.50,0.145 center font "Sans,11"
set label 901 "Perturbation scenarios reached (0–5 of five weight settings)" at screen 0.50,0.075 center font "Sans,10"
set multiplot layout 1,2 rowsfirst margins 0.18,0.95,0.27,0.90 spacing 0.12,0.0

set ytics ("Pre-centrif. delay" 1, "Primary centrif." 2, "Second centrif." 3, "Post-centrif. delay" 4, "Storage" 5) font "Sans,9"
set label 100 "Fluid biospecimens" at graph 0.5,1.065 center font "Sans,11"
plot $FLUID using 1:2:3 with points pointtype 5 pointsize 5.25 linecolor palette notitle, \
     $FLUID using 1:2:($3 < 4 ? sprintf("%d/5",int($3)) : "") with labels center font "Sans,9" tc rgb "#202020" notitle, \
     $FLUID using 1:2:($3 >= 4 ? sprintf("%d/5",int($3)) : "") with labels center font "Sans,9" tc rgb "#FFFFFF" notitle
unset label 100

set ytics ("Warm ischemia" 1, "Cold ischemia" 2, "Fixation / stabil." 3, "Fixation time" 4, "Storage" 5) font "Sans,9"
set label 101 "Solid biospecimens" at graph 0.5,1.065 center font "Sans,11"
set colorbox horizontal user origin screen 0.37,0.030 size screen 0.26,0.025
plot $SOLID using 1:2:3 with points pointtype 5 pointsize 5.25 linecolor palette notitle, \
     $SOLID using 1:2:($3 < 4 ? sprintf("%d/5",int($3)) : "") with labels center font "Sans,9" tc rgb "#202020" notitle, \
     $SOLID using 1:2:($3 >= 4 ? sprintf("%d/5",int($3)) : "") with labels center font "Sans,9" tc rgb "#FFFFFF" notitle
unset label 101

unset multiplot
unset label 900
unset label 901
unset output
