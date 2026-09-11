reset
FIGURE_NAME = "Figure_2"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 3.75
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
set xrange [0.4:13.6]
set yrange [5.5:0.5]
set xtics ("Optimal" 1, "Mild\nsuboptimal" 2, "Moderate\nsuboptimal" 3, "Severe\nsuboptimal" 4, "Critical\npenalty" 5, "Governance\nfailure" 6, \
           "Optimal" 8, "Mild\nsuboptimal" 9, "Moderate\nsuboptimal" 10, "Severe\nsuboptimal" 11, "Critical\npenalty" 12, "Governance\nfailure" 13) font "Helvetica,7"
set ytics ("Grade A" 1, "Grade B" 2, "Grade C" 3, "Grade D" 4, "Grade E" 5)
set xlabel "Synthetic validation scenario"
set ylabel "Assigned RCS grade"
unset grid

set palette defined (0 "#FFFFFF", 0.02 "#EAF2F8", 0.25 "#C9DDEA", 0.50 "#9EC5DD", 0.75 "#6EA6CA", 1.00 "#3F82B2")
set cbrange [0:1]
set cbtics ("0%" 0, "25%" 0.25, "50%" 0.50, "75%" 0.75, "100%" 1)
set cblabel "Proportion"
set colorbox vertical

set label 100 "Fluid biospecimens" at graph 0.23,1.055 center font "Helvetica,9"
set label 101 "Solid biospecimens" at graph 0.77,1.055 center font "Helvetica,9"
set arrow 100 from first 7, graph 0 to first 7, graph 1 nohead dt 3 lw 0.8 lc rgb "#B0B0B0" back

# Sparse rows represent the non-zero cells; the white background represents zero.
# Numerical labels make the heatmap interpretable independently of colour.
plot DATA every ::1 using (xpos(strcol(1),strcol(2))):(grade_id(strcol(4))):7 \
         with points pointtype 5 pointsize 4.5 linecolor palette notitle, \
     DATA every ::1 using (xpos(strcol(1),strcol(2))):(grade_id(strcol(4))):($7 <= 0.55 ? sprintf("%.1f",100.0*$7)."%" : "") \
         with labels center font "Helvetica,7" textcolor rgb "#202020" notitle, \
     DATA every ::1 using (xpos(strcol(1),strcol(2))):(grade_id(strcol(4))):($7 > 0.55 ? sprintf("%.1f",100.0*$7)."%" : "") \
         with labels center font "Helvetica,7" textcolor rgb "#FFFFFF" notitle

unset output
