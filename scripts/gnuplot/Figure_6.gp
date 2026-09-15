reset

FIGURE_NAME = "Figure_6"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 8.80

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


# ============================================================
# C++ / OpenMP — compute
# ============================================================

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


# ============================================================
# C++ / OpenMP — end-to-end
# ============================================================

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


# ============================================================
# Cython / OpenMP — compute
# ============================================================

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


# ============================================================
# Cython / OpenMP — end-to-end
# ============================================================

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


# ============================================================
# R / PSOCK — compute
# ============================================================

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


# ============================================================
# R / PSOCK — end-to-end
# ============================================================

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


# ============================================================
# Axes
# ============================================================

set logscale x 2
set xrange [0.8:20]

set xtics ("1" 1, "2" 2, "4" 4, "8" 8, "16" 16) font "Sans,11"

set yrange [0.25:1.50]

set ytics ("0.25" 0.25, \
           "0.50" 0.50, \
           "0.75" 0.75, \
           "1.00" 1.00, \
           "1.25" 1.25, \
           "1.50" 1.50) font "Sans,11"


# ============================================================
# Visible light-gray horizontal and vertical grid
# ============================================================

set grid xtics ytics back linewidth 0.8 dashtype 1 linecolor rgb "#403b3b"

# Reference line at speedup = 1.
set arrow 900 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 1.0 linecolor rgb "#000000" back

# Preserve the original orange series, changing only its line to continuous.
set style line 22 linecolor rgb "#D55E00" linewidth 1.80 dashtype 1 pointtype 9 pointsize 0.95

# Shared labels from the original single-page layout.
set label 950 "Workload: 5 million biospecimen profiles" at screen 0.50,0.975 center font "Sans,11" tc rgb "#444444"

# Keep all three panels on the same portrait PDF page.
set multiplot layout 3,1 rowsfirst margins 0.15,0.98,0.10,0.94 spacing 0.0,0.08


# ============================================================
# A. C++ / OpenMP
# ============================================================

set ylabel "Speedup vs sequential (×)" offset 0,0 font "Sans,12"
set xlabel "OpenMP threads" font "Sans,12"
set format y "%g"

set key top right horizontal opaque nobox font "Sans,10"

set label 100 "A. C++ / OpenMP" at graph 0.02,0.93 left font "Sans,12"

plot $CPP_COMPUTE using 1:2:3:4 with yerrorlines ls 1 title "Compute", \
     $CPP_E2E using 1:2:3:4 with yerrorlines ls 22 title "End-to-end"

# Prevent panel A label from appearing in panels B and C.
unset label 100
unset xlabel


# ============================================================
# B. Cython / OpenMP
# ============================================================

set ylabel "Speedup vs sequential (×)" offset 0,0 font "Sans,12"
set xlabel "OpenMP threads" font "Sans,12"
set format y "%g"

unset key

set label 101 "B. Cython / OpenMP" at graph 0.02,0.93 left font "Sans,12"

plot $CYTHON_COMPUTE using 1:2:3:4 with yerrorlines ls 1 notitle, \
     $CYTHON_E2E using 1:2:3:4 with yerrorlines ls 22 notitle

# Prevent panel B label from appearing in panel C.
unset label 101
unset xlabel


# ============================================================
# C. R / PSOCK
# ============================================================

set ylabel "Speedup vs sequential (×)" offset 0,0 font "Sans,12"
set xlabel "PSOCK workers" font "Sans,12"
set format y "%g"

set label 102 "C. R / PSOCK" at graph 0.02,0.93 left font "Sans,12"

plot $R_COMPUTE using 1:2:3:4 with yerrorlines ls 1 notitle, \
     $R_E2E using 1:2:3:4 with yerrorlines ls 22 notitle

unset label 102
unset xlabel


# ============================================================
# Cleanup
# ============================================================

unset multiplot

unset label 950
unset arrow 900

unset output
