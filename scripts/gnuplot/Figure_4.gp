reset
FIGURE_NAME = "Figure_4"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 4.25
load "scripts/gnuplot/ieee_access_style.gp"

DATA = "outputs/tables/Table_Threshold_Transition_Detail.csv"

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

# Build transient in-memory grids directly from the canonical detail table.
# No figure-source CSV is written.
set print $FLUID
 do for [i=1:5] {
    do for [j=1:4] {
        stats DATA every ::1 using ((strcol(1) eq "fluid" && strcol(2) eq FLUID_AXIS[i] && strcol(9) eq TRANS_KEY[j] && strcol(14) eq "TRUE") ? 1 : 0) nooutput
        print sprintf("%d %d %.0f", j, i, STATS_sum)
    }
    print ""
 }
set print

set print $SOLID
 do for [i=1:5] {
    do for [j=1:4] {
        stats DATA every ::1 using ((strcol(1) eq "solid" && strcol(2) eq SOLID_AXIS[i] && strcol(9) eq TRANS_KEY[j] && strcol(14) eq "TRUE") ? 1 : 0) nooutput
        print sprintf("%d %d %.0f", j, i, STATS_sum)
    }
    print ""
 }
set print

unset key
unset grid
set xrange [0.5:4.5]
set yrange [5.5:0.5]
set xtics ("A→B" 1, "B→C" 2, "C→D" 3, "D→E" 4) font "Helvetica,8"
set cbrange [0:5]
set palette defined (0 "#F7F7F7", 1 "#DCE8F0", 3 "#91BAD3", 5 "#3F82B2")
unset colorbox

set multiplot layout 1,2 rowsfirst margins 0.12,0.96,0.18,0.88 spacing 0.11,0.0

# Fluid panel
set ytics ("Pre-centrifugation delay" 1, "Primary centrifugation" 2, "Second centrifugation" 3, "Post-centrifugation delay" 4, "Storage" 5) font "Helvetica,7"
set xlabel "RCS grade-transition threshold"
unset ylabel
set label 100 "Fluid biospecimens" at graph 0.5,1.065 center font "Helvetica,9"
plot $FLUID using 1:2:3 with image notitle, \
     $FLUID using 1:2:($3 <= 3 ? sprintf("%d/5",int($3)) : "") with labels center font "Helvetica,8" tc rgb "#202020" notitle, \
     $FLUID using 1:2:($3 > 3 ? sprintf("%d/5",int($3)) : "") with labels center font "Helvetica,8" tc rgb "#FFFFFF" notitle
unset label 100

# Solid panel
set ytics ("Warm ischemia" 1, "Cold ischemia" 2, "Fixation / stabilization" 3, "Fixation time" 4, "Storage" 5) font "Helvetica,7"
set label 101 "Solid biospecimens" at graph 0.5,1.065 center font "Helvetica,9"
plot $SOLID using 1:2:3 with image notitle, \
     $SOLID using 1:2:($3 <= 3 ? sprintf("%d/5",int($3)) : "") with labels center font "Helvetica,8" tc rgb "#202020" notitle, \
     $SOLID using 1:2:($3 > 3 ? sprintf("%d/5",int($3)) : "") with labels center font "Helvetica,8" tc rgb "#FFFFFF" notitle
unset label 101

unset multiplot
unset output
