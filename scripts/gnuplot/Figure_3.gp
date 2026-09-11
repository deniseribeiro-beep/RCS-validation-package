reset
FIGURE_NAME = "Figure_3"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 3.65
load "scripts/gnuplot/ieee_access_style.gp"

DATA = "outputs/tables/Table_Combinatorial_Grade_Distribution.csv"

grade_id(s) = s eq "Grade A" ? 1 : s eq "Grade B" ? 2 : s eq "Grade C" ? 3 : s eq "Grade D" ? 4 : s eq "Grade E" ? 5 : 1/0
xpos(m,g) = grade_id(g) + (m eq "solid" ? 6 : 0)

unset key
set xrange [0.3:11.7]
set yrange [0:58]
set boxwidth 0.72
set style fill solid 0.82 border lc rgb "#4A4A4A" lw 0.7
set xtics ("Grade A" 1, "Grade B" 2, "Grade C" 3, "Grade D" 4, "Grade E" 5, \
           "Grade A" 7, "Grade B" 8, "Grade C" 9, "Grade D" 10, "Grade E" 11) font "Helvetica,8"
set ytics ("0%" 0, "10%" 10, "20%" 20, "30%" 30, "40%" 40, "50%" 50)
set ylabel "Proportion of admissible combinatorial profiles"
unset xlabel
set grid ytics

set label 100 "Fluid biospecimens" at graph 0.23,1.055 center font "Helvetica,9"
set label 101 "Solid biospecimens" at graph 0.77,1.055 center font "Helvetica,9"
set arrow 100 from first 6, graph 0 to first 6, graph 1 nohead dt 3 lw 0.8 lc rgb "#B0B0B0" back

plot DATA every ::1 using (strcol(1) eq "fluid" ? xpos(strcol(1),strcol(2)) : 1/0):(100.0*$4) \
         with boxes lc rgb "#4C78A8" notitle, \
     DATA every ::1 using (strcol(1) eq "solid" ? xpos(strcol(1),strcol(2)) : 1/0):(100.0*$4) \
         with boxes lc rgb "#D9822B" notitle, \
     DATA every ::1 using (xpos(strcol(1),strcol(2))):(100.0*$4 + 3.0):(sprintf("%.1f",100.0*$4)."%\n".sprintf("n=%d",int($3))) \
         with labels center font "Helvetica,7" tc rgb "#202020" notitle

unset output
