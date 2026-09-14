reset
FIGURE_NAME = "Figure_4"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 5.10
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
set xtics ("A→B" 1, "B→C" 2, "C→D" 3, "D→E" 4) font "Helvetica,9"
set cbrange [0:5]
set palette maxcolors 6
set palette defined (0 "#F4F4F4", 1 "#E4EEF9", 2 "#C8DCF4", 3 "#9FC1EA", 4 "#6E9EDB", 5 "#2F6FB2")
set cbtics ("0" 0, "1" 1, "2" 2, "3" 3, "4" 4, "5" 5)
unset colorbox

set label 900 "Five renormalized weight settings per axis: -20%, -10%, nominal, +10%, +20%" at screen 0.50,0.135 center font "Helvetica,8" tc rgb "#444444"
set label 901 "Weight settings reaching each grade boundary (0–5)" at screen 0.50,0.095 center font "Helvetica,8"
set multiplot layout 1,2 rowsfirst margins 0.17,0.975,0.22,0.90 spacing 0.14,0.0

set ytics ("Pre-centrifugation delay" 1, "Primary centrifugation" 2, "Second centrifugation" 3, "Post-centrifugation delay" 4, "Storage" 5) font "Helvetica,8"
set xlabel "RCS grade boundary" offset 0,0.25
set label 100 "(a) Fluid biospecimens" at graph 0.0,1.075 left font "Helvetica,10"
plot $FLUID using 1:2:3 with points pointtype 5 pointsize 4.7 linecolor palette notitle, \
     $FLUID using 1:2:($3 < 4 ? sprintf("%d/5",int($3)) : "") with labels center font "Helvetica,8" tc rgb "#202020" notitle, \
     $FLUID using 1:2:($3 >= 4 ? sprintf("%d/5",int($3)) : "") with labels center font "Helvetica,8" tc rgb "#FFFFFF" notitle
unset label 100

set ytics ("Warm ischemia" 1, "Cold ischemia" 2, "Fixation / stabilization" 3, "Fixation time" 4, "Storage" 5) font "Helvetica,8"
set label 101 "(b) Solid biospecimens" at graph 0.0,1.075 left font "Helvetica,10"
set colorbox horizontal user origin screen 0.35,0.045 size screen 0.30,0.023
plot $SOLID using 1:2:3 with points pointtype 5 pointsize 4.7 linecolor palette notitle, \
     $SOLID using 1:2:($3 < 4 ? sprintf("%d/5",int($3)) : "") with labels center font "Helvetica,8" tc rgb "#202020" notitle, \
     $SOLID using 1:2:($3 >= 4 ? sprintf("%d/5",int($3)) : "") with labels center font "Helvetica,8" tc rgb "#FFFFFF" notitle
unset label 101

unset multiplot
unset label 900
unset label 901
unset output
