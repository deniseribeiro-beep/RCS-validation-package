reset
FIGURE_NAME = "Figure_2"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 3.55
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Synthetic_Validation_Grade_Distribution.csv", TABLES_DIR)

scenario_id(s) = s eq "optimal" ? 1 : \
                 s eq "mild_suboptimal" ? 2 : \
                 s eq "moderate_suboptimal" ? 3 : \
                 s eq "severe_suboptimal" ? 4 : \
                 s eq "critical_penalty_burden" ? 5 : \
                 s eq "governance_failure" ? 6 : 1/0
grade_id(s) = s eq "Grade A" ? 1 : s eq "Grade B" ? 2 : s eq "Grade C" ? 3 : s eq "Grade D" ? 4 : s eq "Grade E" ? 5 : 1/0

unset key
unset grid
set xrange [0.5:6.5]
set yrange [5.5:0.5]
set xtics ("Optimal" 1, "Mild\nsuboptimal" 2, "Moderate\nsuboptimal" 3, "Severe\nsuboptimal" 4, "Critical\npenalty" 5, "Governance\nfailure" 6) font "Helvetica,7"
set ytics ("Grade A" 1, "Grade B" 2, "Grade C" 3, "Grade D" 4, "Grade E" 5) font "Helvetica,8"

set palette defined (0 "#FFFFFF", 0.02 "#E7F0FF", 0.25 "#C8DCF9", 0.50 "#94BDF4", 0.75 "#6A9FF0", 1.00 "#4589FF")
set cbrange [0:1]
set cbtics ("0" 0, "25" 0.25, "50" 0.50, "75" 0.75, "100" 1) font "Helvetica,7"

set label 900 "Synthetic validation scenario" at screen 0.50,0.065 center font "Helvetica,9"
set multiplot layout 1,2 rowsfirst margins 0.11,0.90,0.22,0.90 spacing 0.075,0.0

# Fluid matrix
set ylabel "Assigned RCS grade" offset 0.8,0 font "Helvetica,9"
unset colorbox
set label 100 "Fluid biospecimens" at graph 0.5,1.075 center font "Helvetica,9"
plot DATA every ::1 using ((stringcolumn("matrix") eq "fluid") ? scenario_id(stringcolumn("scenario")) : 1/0):(grade_id(stringcolumn("final_grade"))):(column("proportion")) \
         with points pointtype 5 pointsize 4.25 linecolor palette notitle, \
     DATA every ::1 using ((stringcolumn("matrix") eq "fluid") ? scenario_id(stringcolumn("scenario")) : 1/0):(grade_id(stringcolumn("final_grade"))):(column("proportion") <= 0.55 ? sprintf("%.1f",100.0*column("proportion")) : "") \
         with labels center font "Helvetica,7" textcolor rgb "#202020" notitle, \
     DATA every ::1 using ((stringcolumn("matrix") eq "fluid") ? scenario_id(stringcolumn("scenario")) : 1/0):(grade_id(stringcolumn("final_grade"))):(column("proportion") > 0.55 ? sprintf("%.1f",100.0*column("proportion")) : "") \
         with labels center font "Helvetica,7" textcolor rgb "#FFFFFF" notitle
unset label 100

# Solid matrix
unset ylabel
unset ytics
set label 101 "Solid biospecimens" at graph 0.5,1.075 center font "Helvetica,9"
set colorbox vertical user origin screen 0.925,0.29 size screen 0.018,0.50
set cblabel "Proportion (%)" offset 1.0,0 font "Helvetica,8"
plot DATA every ::1 using ((stringcolumn("matrix") eq "solid") ? scenario_id(stringcolumn("scenario")) : 1/0):(grade_id(stringcolumn("final_grade"))):(column("proportion")) \
         with points pointtype 5 pointsize 4.25 linecolor palette notitle, \
     DATA every ::1 using ((stringcolumn("matrix") eq "solid") ? scenario_id(stringcolumn("scenario")) : 1/0):(grade_id(stringcolumn("final_grade"))):(column("proportion") <= 0.55 ? sprintf("%.1f",100.0*column("proportion")) : "") \
         with labels center font "Helvetica,7" textcolor rgb "#202020" notitle, \
     DATA every ::1 using ((stringcolumn("matrix") eq "solid") ? scenario_id(stringcolumn("scenario")) : 1/0):(grade_id(stringcolumn("final_grade"))):(column("proportion") > 0.55 ? sprintf("%.1f",100.0*column("proportion")) : "") \
         with labels center font "Helvetica,7" textcolor rgb "#FFFFFF" notitle
unset label 101

unset multiplot
unset label 900
unset output
