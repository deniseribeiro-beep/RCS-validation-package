reset
FIGURE_NAME = "Figure_6"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 4.25
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Benchmark_Within_Language_Speedup_Summary.csv", TABLES_DIR)
set datafile columnheaders
TARGET_N = 5000000

array W[5]
W[1] = 1
W[2] = 2
W[3] = 4
W[4] = 8
W[5] = 16

# Build compact contiguous data blocks. Direct conditional plotting of the full
# summary table inserts undefined rows between valid points and can visually
# break the connecting curve in some gnuplot builds.
set print $CPP_COMPUTE
do for [i=1:5] {
    stats DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "compute" && column("workers") == W[i]) ? column("geometric_mean_speedup") : 1/0) nooutput
    gm = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "compute" && column("workers") == W[i]) ? column("speedup_ci95_low") : 1/0) nooutput
    lo = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "compute" && column("workers") == W[i]) ? column("speedup_ci95_high") : 1/0) nooutput
    hi = STATS_mean
    print sprintf("%g,%g,%g,%g", W[i], gm, lo, hi)
}
set print

set print $CPP_E2E
do for [i=1:5] {
    stats DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "end_to_end" && column("workers") == W[i]) ? column("geometric_mean_speedup") : 1/0) nooutput
    gm = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "end_to_end" && column("workers") == W[i]) ? column("speedup_ci95_low") : 1/0) nooutput
    lo = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "C++" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cpp_openmp" && stringcolumn("timing_region") eq "end_to_end" && column("workers") == W[i]) ? column("speedup_ci95_high") : 1/0) nooutput
    hi = STATS_mean
    print sprintf("%g,%g,%g,%g", W[i], gm, lo, hi)
}
set print

set print $CYTHON_COMPUTE
do for [i=1:5] {
    stats DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "compute" && column("workers") == W[i]) ? column("geometric_mean_speedup") : 1/0) nooutput
    gm = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "compute" && column("workers") == W[i]) ? column("speedup_ci95_low") : 1/0) nooutput
    lo = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "compute" && column("workers") == W[i]) ? column("speedup_ci95_high") : 1/0) nooutput
    hi = STATS_mean
    print sprintf("%g,%g,%g,%g", W[i], gm, lo, hi)
}
set print

set print $CYTHON_E2E
do for [i=1:5] {
    stats DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "end_to_end" && column("workers") == W[i]) ? column("geometric_mean_speedup") : 1/0) nooutput
    gm = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "end_to_end" && column("workers") == W[i]) ? column("speedup_ci95_low") : 1/0) nooutput
    lo = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "Python/Cython" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "cython_openmp" && stringcolumn("timing_region") eq "end_to_end" && column("workers") == W[i]) ? column("speedup_ci95_high") : 1/0) nooutput
    hi = STATS_mean
    print sprintf("%g,%g,%g,%g", W[i], gm, lo, hi)
}
set print

set print $R_COMPUTE
do for [i=1:5] {
    stats DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "compute" && column("workers") == W[i]) ? column("geometric_mean_speedup") : 1/0) nooutput
    gm = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "compute" && column("workers") == W[i]) ? column("speedup_ci95_low") : 1/0) nooutput
    lo = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "compute" && column("workers") == W[i]) ? column("speedup_ci95_high") : 1/0) nooutput
    hi = STATS_mean
    print sprintf("%g,%g,%g,%g", W[i], gm, lo, hi)
}
set print

set print $R_E2E
do for [i=1:5] {
    stats DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "end_to_end" && column("workers") == W[i]) ? column("geometric_mean_speedup") : 1/0) nooutput
    gm = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "end_to_end" && column("workers") == W[i]) ? column("speedup_ci95_low") : 1/0) nooutput
    lo = STATS_mean
    stats DATA every ::1 using ((stringcolumn("language_family") eq "R" && column("n_records") == TARGET_N && stringcolumn("implementation") eq "r_psock" && stringcolumn("timing_region") eq "end_to_end" && column("workers") == W[i]) ? column("speedup_ci95_high") : 1/0) nooutput
    hi = STATS_mean
    print sprintf("%g,%g,%g,%g", W[i], gm, lo, hi)
}
set print

set logscale x 2
set xrange [0.8:20]
set xtics ("1" 1, "2" 2, "4" 4, "8" 8, "16" 16) font "Sans,10"
set yrange [0.25:1.50]
set ytics ("0.25" 0.25, "0.50" 0.50, "0.75" 0.75, "1.00" 1.00, "1.25" 1.25, "1.50" 1.50) font "Sans,10"
set grid ytics
set arrow 900 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 1.0 linecolor rgb "#777777" back
set label 950 "Workload: 5 million biospecimen profiles" at screen 0.50,0.955 center font "Sans,10" tc rgb "#444444"
set label 951 "Parallel workers / threads" at screen 0.50,0.070 center font "Sans,11"

set multiplot layout 1,3 rowsfirst margins 0.095,0.985,0.19,0.88 spacing 0.05,0.0

# A. C++ / OpenMP
set ylabel "Speedup vs sequential (×)" offset 0.55,0 font "Sans,11"
set format y "%g"
set key bottom center horizontal opaque nobox font "Sans,9"
set label 100 "A. C++ / OpenMP" at graph 0.04,0.93 left font "Sans,10"
plot $CPP_COMPUTE using 1:2:3:4 with yerrorlines ls 1 title "Compute", \
     $CPP_E2E using 1:2:3:4 with yerrorlines ls 2 title "End-to-end"
unset label 100

# B. Cython / OpenMP
unset ylabel
set format y "%g"
unset key
set label 101 "B. Cython / OpenMP" at graph 0.04,0.93 left font "Sans,10"
plot $CYTHON_COMPUTE using 1:2:3:4 with yerrorlines ls 1 notitle, \
     $CYTHON_E2E using 1:2:3:4 with yerrorlines ls 2 notitle
unset label 101

# C. R / PSOCK
set label 102 "C. R / PSOCK" at graph 0.04,0.93 left font "Sans,10"
plot $R_COMPUTE using 1:2:3:4 with yerrorlines ls 1 notitle, \
     $R_E2E using 1:2:3:4 with yerrorlines ls 2 notitle
unset label 102

unset multiplot
unset label 950
unset label 951
unset output
