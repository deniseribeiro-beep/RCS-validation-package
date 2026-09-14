reset
FIGURE_NAME = "Figure_6"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 3.20
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Benchmark_Within_Language_Speedup_Summary.csv", TABLES_DIR)
TARGET_N = 5000000

set logscale x 2
set xrange [0.8:20]
set xtics ("1" 1, "2" 2, "4" 4, "8" 8, "16" 16) font "Helvetica,7"
set yrange [0.25:1.50]
set ytics ("0.25" 0.25, "0.50" 0.50, "0.75" 0.75, "1.00" 1.00, "1.25" 1.25, "1.50" 1.50) font "Helvetica,7"
set grid ytics
set arrow 900 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 0.9 linecolor rgb "#777777" back
set label 950 "Workload: 5 million biospecimen profiles" at screen 0.50,0.955 center font "Helvetica,8" tc rgb "#444444"
set label 951 "Parallel workers / threads" at screen 0.50,0.075 center font "Helvetica,9"

set multiplot layout 1,3 rowsfirst margins 0.10,0.98,0.19,0.88 spacing 0.045,0.0

# A. C++ / OpenMP
set ylabel "Speedup vs sequential (×)" offset 0.55,0 font "Helvetica,8"
set format y "%g"
set key bottom center horizontal opaque nobox font "Helvetica,7"
set label 100 "A. C++ / OpenMP" at graph 0.04,0.93 left font "Helvetica,8"
plot DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "compute") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 title "Compute", \
     DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "end_to_end") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 title "End-to-end"
unset label 100

# B. Cython / OpenMP
unset ylabel
set format y ""
unset key
set label 101 "B. Cython / OpenMP" at graph 0.04,0.93 left font "Helvetica,8"
plot DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "compute") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 notitle, \
     DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "end_to_end") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 notitle
unset label 101

# C. R / PSOCK
set label 102 "C. R / PSOCK" at graph 0.04,0.93 left font "Helvetica,8"
plot DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "compute") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 notitle, \
     DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "end_to_end") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 notitle
unset label 102

unset multiplot
unset label 950
unset label 951
unset output
