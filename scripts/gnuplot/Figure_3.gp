reset
FIGURE_NAME = "Figure_3"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 3.35
load "scripts/gnuplot/ieee_access_style.gp"

DATA = "outputs/tables/Table_Combinatorial_Grade_Distribution.csv"

grade_id(s) = s eq "Grade A" ? 1 : s eq "Grade B" ? 2 : s eq "Grade C" ? 3 : s eq "Grade D" ? 4 : s eq "Grade E" ? 5 : 1/0
xpos(m,g) = grade_id(g) + (m eq "solid" ? 6 : 0)

unset key
set xrange [0.35:11.65]
set yrange [0:0.60]
set boxwidth 0.72
set style fill solid 0.92 border lc rgb "#FFFFFF"
set xtics ("Grade A" 1, "Grade B" 2, "Grade C" 3, "Grade D" 4, "Grade E" 5, \
           "Grade A" 7, "Grade B" 8, "Grade C" 9, "Grade D" 10, "Grade E" 11) font sprintf("Helvetica,%.1f", FS_SMALL)
set ytics ("0%" 0, "10%" 0.10, "20%" 0.20, "30%" 0.30, "40%" 0.40, "50%" 0.50, "60%" 0.60)
set ylabel "Proportion of admissible combinatorial profiles" offset 0.8,0
unset xlabel
set grid ytics

set label 100 "Fluid biospecimens" at graph 0.23,1.065 center font sprintf("Helvetica,%.1f", FS_PANEL)
set label 101 "Solid biospecimens" at graph 0.77,1.065 center font sprintf("Helvetica,%.1f", FS_PANEL)
set arrow 100 from first 6, graph 0 to first 6, graph 1 nohead dt 3 lw (0.65*DEVICE_SCALE) lc rgb "#C8C8C8" back

plot DATA every ::1 using (strcol(1) eq "fluid" ? xpos(strcol(1),strcol(2)) : 1/0):4 \
         with boxes lc rgb "#4C78A8" notitle, \
     DATA every ::1 using (strcol(1) eq "solid" ? xpos(strcol(1),strcol(2)) : 1/0):4 \
         with boxes lc rgb "#D9822B" notitle, \
     DATA every ::1 using (xpos(strcol(1),strcol(2))):($4 + 0.025):(sprintf("%.1f%%\nn=%d",100.0*$4,int($3))) \
         with labels center font sprintf("Helvetica,%.1f", FS_SMALL) tc rgb "#202020" notitle

unset output
