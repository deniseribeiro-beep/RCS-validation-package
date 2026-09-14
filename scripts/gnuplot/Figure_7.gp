reset
FIGURE_NAME = "Figure_7"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 5.25
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
set xtics ("10k" 1, "50k" 2, "100k" 3, "500k" 4, "1M" 5, "2M" 6, "5M" 7) font "Sans,10"
set grid ytics

# Scientific-role clarification: the C implementation is the computational
# correctness/equivalence reference. Per the frozen benchmark protocol, CUDA
# performance speed ratios are calculated against C++ sequential, not against
# another language family.
set label 950 "C reference = computational correctness/equivalence reference; CUDA speed ratios use C++ sequential as the performance baseline" at screen 0.50,0.965 center font "Sans,9" tc rgb "#444444"
set multiplot layout 2,1 rowsfirst margins 0.13,0.98,0.12,0.91 spacing 0.0,0.15

# A. Compute-kernel acceleration relative to the protocol-defined C++ sequential comparator.
set yrange [0:80]
set ytics 0,20,80 font "Sans,10"
unset xlabel
set ylabel "Compute acceleration vs C++ sequential (×)" offset 0.55,0 font "Sans,11"
unset key
set label 100 "A. CUDA compute kernel" at graph 0.0,1.075 left font "Sans,11"
plot DATA every ::1 using (stringcolumn("timing_region") eq "compute" ? workload_id(column("n_records")) : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 1 notitle
unset label 100

# B. End-to-end relative speed; 1× marks parity with C++ sequential.
set yrange [0:1.05]
set ytics 0,0.2,1.0 font "Sans,10"
set xlabel "Number of biospecimen profiles" offset 0,0.25 font "Sans,11"
set ylabel "End-to-end speed vs C++ sequential (×)" offset 0.55,0 font "Sans,11"
set arrow 901 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 1.0 linecolor rgb "#777777" back
set label 102 "B. CUDA end-to-end" at graph 0.0,1.075 left font "Sans,11"
set label 103 "1× = parity with C++ sequential" at graph 0.985, first 0.965 right font "Sans,9" tc rgb "#666666"
plot DATA every ::1 using (stringcolumn("timing_region") eq "end_to_end" ? workload_id(column("n_records")) : 1/0):(column("geometric_mean_speedup")):(column("speedup_ci95_low")):(column("speedup_ci95_high")) \
         with yerrorlines ls 2 notitle
unset label 102
unset label 103
unset arrow 901

unset multiplot
unset label 950
unset output
