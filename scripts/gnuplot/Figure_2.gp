reset
FIGURE_NAME = "Figure_2"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 3.45
load "scripts/gnuplot/ieee_access_style.gp"

DATA = "outputs/tables/Table_Synthetic_Validation_Grade_Distribution.csv"

scenario_id(s) = s eq "optimal" ? 1 : \
                 s eq "mild_suboptimal" ? 2 : \
                 s eq "moderate_suboptimal" ? 3 : \
                 s eq "severe_suboptimal" ? 4 : \
                 s eq "critical_penalty_burden" ? 5 : \
                 s eq "governance_failure" ? 6 : 1/0
grade_id(s) = s eq "Grade A" ? 1 : s eq "Grade B" ? 2 : s eq "Grade C" ? 3 : s eq "Grade D" ? 4 : s eq "Grade E" ? 5 : 1/0
xpos(m,s) = scenario_id(s) + (m eq "solid" ? 7 : 0)

unset key
unset grid
set xrange [0.35:13.65]
set yrange [5.55:0.45]
set xtics ("Optimal" 1, "Mild\nsuboptimal" 2, "Moderate\nsuboptimal" 3, "Severe\nsuboptimal" 4, "Critical\npenalty" 5, "Governance\nfailure" 6, \
           "Optimal" 8, "Mild\nsuboptimal" 9, "Moderate\nsuboptimal" 10, "Severe\nsuboptimal" 11, "Critical\npenalty" 12, "Governance\nfailure" 13) font "Helvetica,8"
set ytics ("Grade A" 1, "Grade B" 2, "Grade C" 3, "Grade D" 4, "Grade E" 5)
set xlabel "Synthetic validation scenario" offset 0,0.25
set ylabel "Assigned RCS grade" offset 0.8,0

# Sparse rows are the non-zero cells, so absent grade/scenario combinations
# are true zero-valued cells and are rendered as the white plot background.
# The palette therefore uses white at zero to keep the legend semantically
# consistent with the plotted heatmap.
set palette defined (0 "#FFFFFF", 0.02 "#E7F0FF", 0.25 "#C8DCF9", 0.50 "#94BDF4", 0.75 "#6A9FF0", 1.00 "#4589FF")
set cbrange [0:1]
set cbtics ("0" 0, "25" 0.25, "50" 0.50, "75" 0.75, "100" 1)
set cblabel "Proportion (%)" offset 1.2,0
set colorbox vertical user origin screen 0.925,0.22 size screen 0.018,0.60

set label 100 "Fluid biospecimens" at graph 0.23,1.065 center font "Helvetica,10"
set label 101 "Solid biospecimens" at graph 0.77,1.065 center font "Helvetica,10"
set arrow 100 from first 7, graph 0 to first 7, graph 1 nohead dt 3 lw 0.65 lc rgb "#C8C8C8" back

# Cell labels are percentages; the unit is stated on the colourbar.
plot DATA every ::1 using (xpos(strcol(1),strcol(2))):(grade_id(strcol(4))):7 \
         with points pointtype 5 pointsize 5.0 linecolor palette notitle, \
     DATA every ::1 using (xpos(strcol(1),strcol(2))):(grade_id(strcol(4))):($7 <= 0.55 ? sprintf("%.1f",100.0*$7) : "") \
         with labels center font "Helvetica,8" textcolor rgb "#202020" notitle, \
     DATA every ::1 using (xpos(strcol(1),strcol(2))):(grade_id(strcol(4))):($7 > 0.55 ? sprintf("%.1f",100.0*$7) : "") \
         with labels center font "Helvetica,8" textcolor rgb "#FFFFFF" notitle

unset output
