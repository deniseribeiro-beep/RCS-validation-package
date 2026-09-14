reset
FIGURE_NAME = "Figure_3"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 3.25
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Combinatorial_Grade_Distribution.csv", TABLES_DIR)

grade_id(s) = s eq "Grade A" ? 1 : s eq "Grade B" ? 2 : s eq "Grade C" ? 3 : s eq "Grade D" ? 4 : s eq "Grade E" ? 5 : 1/0
xpos(m,g) = grade_id(g) + (m eq "solid" ? 6 : 0)

unset key
set xrange [0.35:11.65]
set yrange [0:60]
set lmargin 11.5
set rmargin 1.5
set bmargin 3.6
set tmargin 2.2
set boxwidth 0.72
set style fill solid 0.92 border lc rgb "#FFFFFF"
set xtics ("Grade A" 1, "Grade B" 2, "Grade C" 3, "Grade D" 4, "Grade E" 5, \
           "Grade A" 7, "Grade B" 8, "Grade C" 9, "Grade D" 10, "Grade E" 11) font "Sans,8"
set ytics 0,10,60 font "Sans,8"
set ylabel "Proportion of admissible combinatorial profiles (%)" offset 0.8,0 font "Sans,9"
unset xlabel
set grid ytics

set label 100 "Fluid biospecimens" at first 3, first 56 center font "Sans,9"
set label 101 "Solid biospecimens" at first 9, first 56 center font "Sans,9"
set arrow 100 from first 6, first 0 to first 6, first 60 nohead dt 3 lw 0.55 lc rgb "#D0D0D0" back

plot DATA every ::1 using (stringcolumn("matrix") eq "fluid" ? xpos(stringcolumn("matrix"),stringcolumn("final_grade")) : 1/0):(100.0*column("proportion")) \
         with boxes lc rgb "#4C78A8" notitle, \
     DATA every ::1 using (stringcolumn("matrix") eq "solid" ? xpos(stringcolumn("matrix"),stringcolumn("final_grade")) : 1/0):(100.0*column("proportion")) \
         with boxes lc rgb "#D9822B" notitle, \
     DATA every ::1 using (xpos(stringcolumn("matrix"),stringcolumn("final_grade"))):(100.0*column("proportion") + 2.3):(sprintf("%.1f%%\nn=%d",100.0*column("proportion"),int(column("n")))) \
         with labels center font "Sans,7" tc rgb "#202020" notitle

unset output
