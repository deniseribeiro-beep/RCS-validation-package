reset
FIGURE_NAME = "Figure_7"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 3.45
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Benchmark_CUDA_Speedup_Summary.csv", TABLES_DIR)

set logscale x 10
set logscale y 10
set xrange [8000:6500000]
set yrange [0.02:120]
set xtics ("10k" 10000, "50k" 50000, "100k" 100000, "500k" 500000, "1M" 1000000, "2M" 2000000, "5M" 5000000) font "Helvetica,8" rotate by -25
set ytics ("0.03" 0.03, "0.1" 0.1, "0.3" 0.3, "1" 1, "3" 3, "10" 10, "30" 30, "100" 100)
set xlabel "Number of biospecimen profiles" offset 0,0.35
set ylabel "Acceleration relative to C++ sequential (×)" offset 0.7,0
set key top right horizontal opaque nobox
set grid xtics ytics
set arrow 900 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 0.9 linecolor rgb "#777777" back
set label 900 "1×" at graph 0.01, first 1.12 left font "Helvetica,8" tc rgb "#666666"

plot DATA every ::1 using (stringcolumn("timing_region") eq "compute" ? column("n_records") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 title "Compute", \
     DATA every ::1 using (stringcolumn("timing_region") eq "end_to_end" ? column("n_records") : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 title "End-to-end"

unset label 900
unset output
