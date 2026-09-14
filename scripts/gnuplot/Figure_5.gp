reset
FIGURE_NAME = "Figure_5"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 5.55
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Benchmark_Runtime_Summary.csv", TABLES_DIR)

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
set multiplot layout 2,1 rowsfirst margins 0.14,0.975,0.11,0.955 spacing 0.0,0.12

# (a) Batch runtime: lower is better.
set logscale y 10
set yrange [0.0001:1]
set ytics ("0.0001" 0.0001, "0.001" 0.001, "0.01" 0.01, "0.1" 0.1, "1" 1)
unset xlabel
set ylabel "Median batch runtime (s)" offset 0.55,0
set key top left horizontal opaque nobox
set label 100 "(a) Batch runtime — lower is better" at graph 0.015,0.91 left font "Helvetica,10"
plot DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "compute") ? workload_id(column("n_records")) : 1/0):(column("median_elapsed_sec")):(column("median_ci95_low_sec")):(column("median_ci95_high_sec")) \
         with yerrorlines ls 1 title "Compute", \
     DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "end_to_end") ? workload_id(column("n_records")) : 1/0):(column("median_elapsed_sec")):(column("median_ci95_low_sec")):(column("median_ci95_high_sec")) \
         with yerrorlines ls 2 title "End-to-end"
unset label 100

# (b) Throughput: higher is better.
unset key
set yrange [100000:100000000]
set ytics ("0.1M" 100000, "1M" 1000000, "10M" 10000000, "100M" 100000000)
set xlabel "Number of biospecimen profiles" offset 0,0.35
set ylabel "Median throughput (profiles/s)" offset 0.55,0
set label 101 "(b) Throughput — higher is better" at graph 0.015,0.91 left font "Helvetica,10"
plot DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "compute") ? workload_id(column("n_records")) : 1/0):(column("median_throughput_profiles_sec")) \
         with linespoints ls 1 notitle, \
     DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "end_to_end") ? workload_id(column("n_records")) : 1/0):(column("median_throughput_profiles_sec")) \
         with linespoints ls 2 notitle
unset label 101

unset multiplot
unset output
