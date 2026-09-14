reset
FIGURE_NAME = "Figure_7"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 5.45
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
set xtics ("10k" 1, "50k" 2, "100k" 3, "500k" 4, "1M" 5, "2M" 6, "5M" 7) font "Helvetica,8"
set grid ytics
set multiplot layout 2,1 rowsfirst margins 0.14,0.975,0.11,0.955 spacing 0.0,0.13

# (a) Compute-kernel acceleration.
set yrange [0:82]
set ytics ("0" 0, "20" 20, "40" 40, "60" 60, "80" 80)
unset xlabel
set ylabel "Compute acceleration (×)" offset 0.6,0
unset key
set arrow 900 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 1.0 linecolor rgb "#777777" back
set label 100 "(a) CUDA compute kernel vs C++ sequential" at graph 0.015,0.90 left font "Helvetica,10"
set label 101 "Higher values = faster kernel" at graph 0.985,0.90 right font "Helvetica,7" tc rgb "#666666"
plot DATA every ::1 using (stringcolumn("timing_region") eq "compute" ? workload_id(column("n_records")) : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 notitle, \
     DATA every ::1 using (stringcolumn("timing_region") eq "compute" ? workload_id(column("n_records")) : 1/0):(column("geometric_mean_speedup") + 4.0):(sprintf("%.1f×",column("geometric_mean_speedup"))) \
         with labels center font "Helvetica,8" tc rgb "#202020" notitle
unset label 100
unset label 101
unset arrow 900

# (b) End-to-end relative speed.
set yrange [0:1.05]
set ytics ("0" 0, "0.2" 0.2, "0.4" 0.4, "0.6" 0.6, "0.8" 0.8, "1.0" 1.0)
set xlabel "Number of biospecimen profiles" offset 0,0.35
set ylabel "End-to-end relative speed (×)" offset 0.6,0
set arrow 901 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 1.0 linecolor rgb "#666666" back
set label 102 "(b) CUDA end-to-end vs C++ sequential" at graph 0.015,0.90 left font "Helvetica,10"
set label 103 "Values <1 = slower than C++ sequential" at graph 0.985,0.90 right font "Helvetica,7" tc rgb "#666666"
set label 104 "1× baseline" at graph 0.985, first 0.965 right font "Helvetica,7" tc rgb "#666666"
plot DATA every ::1 using (stringcolumn("timing_region") eq "end_to_end" ? workload_id(column("n_records")) : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 notitle, \
     DATA every ::1 using (stringcolumn("timing_region") eq "end_to_end" ? workload_id(column("n_records")) : 1/0):(column("geometric_mean_speedup") + 0.045):(sprintf("%.2f×",column("geometric_mean_speedup"))) \
         with labels center font "Helvetica,8" tc rgb "#202020" notitle
unset label 102
unset label 103
unset label 104
unset arrow 901

unset multiplot
unset output
