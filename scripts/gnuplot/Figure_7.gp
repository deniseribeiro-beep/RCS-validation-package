reset
FIGURE_NAME = "Figure_7"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 4.70
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Benchmark_CUDA_Speedup_Summary.csv", TABLES_DIR)

workload_id(n) = n == 10000 ? 1 : \
                 n == 50000 ? 2 : \
                 n == 100000 ? 3 : \
                 n == 500000 ? 4 : \
                 n == 1000000 ? 5 : \
                 n == 2000000 ? 6 : \
                 n == 5000000 ? 7 : 1/0

set xrange [0.6:7.4]
set xtics ("10k" 1, "50k" 2, "100k" 3, "500k" 4, "1M" 5, "2M" 6, "5M" 7) font "Sans,8"
set grid ytics
set multiplot layout 2,1 rowsfirst margins 0.13,0.975,0.12,0.93 spacing 0.0,0.16

# A. Compute-kernel acceleration relative to C++ sequential.
set yrange [0:80]
set ytics 0,20,80 font "Sans,8"
unset xlabel
set ylabel "Compute acceleration (×)" offset 0.65,0 font "Sans,9"
unset key
set label 100 "A. CUDA compute kernel vs C++ sequential" at graph 0.0,1.085 left font "Sans,9"
plot DATA every ::1 using (stringcolumn("timing_region") eq "compute" ? workload_id(column("n_records")) : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 notitle
unset label 100

# B. End-to-end relative speed; 1× marks parity with C++ sequential.
set yrange [0:1.05]
set ytics 0,0.2,1.0 font "Sans,8"
set xlabel "Number of biospecimen profiles" offset 0,0.3 font "Sans,9"
set ylabel "End-to-end relative speed (×)" offset 0.65,0 font "Sans,9"
set arrow 901 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 0.9 linecolor rgb "#777777" back
set label 102 "B. CUDA end-to-end vs C++ sequential" at graph 0.0,1.085 left font "Sans,9"
set label 103 "1× baseline" at graph 0.985, first 0.965 right font "Sans,7" tc rgb "#666666"
plot DATA every ::1 using (stringcolumn("timing_region") eq "end_to_end" ? workload_id(column("n_records")) : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 notitle
unset label 102
unset label 103
unset arrow 901

unset multiplot
unset output
