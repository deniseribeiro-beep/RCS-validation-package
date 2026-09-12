reset
FIGURE_NAME = "Figure_6"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 6.65
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Benchmark_Within_Language_Speedup_Summary.csv", TABLES_DIR)
TARGET_N = 5000000

set logscale x 2
set xrange [0.8:20]
set xtics ("1" 1, "2" 2, "4" 4, "8" 8, "16" 16) font "Helvetica,8"
set yrange [0.2:3.1]
set ytics 0.5
set format y "%.1f"
set grid ytics
set arrow 900 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 0.9 linecolor rgb "#777777" back

set multiplot layout 3,1 rowsfirst margins 0.13,0.975,0.09,0.96 spacing 0.0,0.095

set xlabel "Workers" offset 0,0.25
set ylabel "Speedup (×)" offset 0.7,0
set key top right horizontal opaque nobox
set label 100 "(a) R / PSOCK" at graph 0.015,0.89 left font "Helvetica,10"
plot DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "compute") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 title "Compute", \
     DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "end_to_end") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 title "End-to-end"
unset label 100

unset key
set xlabel "Threads" offset 0,0.25
set ylabel "Speedup (×)" offset 0.7,0
set label 101 "(b) Cython / OpenMP" at graph 0.015,0.89 left font "Helvetica,10"
plot DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "compute") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 notitle, \
     DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "end_to_end") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 notitle
unset label 101

set xlabel "Threads" offset 0,0.25
set ylabel "Speedup (×)" offset 0.7,0
set label 102 "(c) C++ / OpenMP" at graph 0.015,0.89 left font "Helvetica,10"
plot DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "compute") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 notitle, \
     DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "end_to_end") ? column("workers") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 notitle
unset label 102

unset multiplot
unset output
