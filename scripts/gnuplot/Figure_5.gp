reset
FIGURE_NAME = "Figure_5"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 5.20
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
set xtics ("10k" 1, "50k" 2, "100k" 3, "500k" 4, "1M" 5, "2M" 6, "5M" 7) font "Sans,10"
set grid ytics
set multiplot layout 2,1 rowsfirst margins 0.13,0.98,0.12,0.93 spacing 0.0,0.15

# A. Batch elapsed time.
unset logscale y
set yrange [0:*]
set format y "%.2g"
unset xlabel
set ylabel "Median elapsed time (s)" offset 0.6,0 font "Sans,11"
set key top left horizontal opaque nobox font "Sans,10"
set label 100 "A. C reference batch elapsed time" at graph 0.0,1.075 left font "Sans,11"
plot DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "compute") ? workload_id(column("n_records")) : 1/0):(column("median_elapsed_sec")):(column("median_ci95_low_sec")):(column("median_ci95_high_sec")) \
         with yerrorlines ls 1 title "Compute", \
     DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "end_to_end") ? workload_id(column("n_records")) : 1/0):(column("median_elapsed_sec")):(column("median_ci95_low_sec")):(column("median_ci95_high_sec")) \
         with yerrorlines ls 2 title "End-to-end"
unset label 100

# B. Per-profile computational cost.
unset key
set yrange [0:*]
set format y "%.2g"
set xlabel "Number of biospecimen profiles" offset 0,0.25 font "Sans,11"
set ylabel "Median time per profile (µs)" offset 0.6,0 font "Sans,11"
set label 101 "B. Median per-profile computational cost" at graph 0.0,1.075 left font "Sans,11"
plot DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "compute") ? workload_id(column("n_records")) : 1/0):(1e6*column("median_elapsed_sec")/column("n_records")):(1e6*column("median_ci95_low_sec")/column("n_records")):(1e6*column("median_ci95_high_sec")/column("n_records")) \
         with yerrorlines ls 1 notitle, \
     DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "end_to_end") ? workload_id(column("n_records")) : 1/0):(1e6*column("median_elapsed_sec")/column("n_records")):(1e6*column("median_ci95_low_sec")/column("n_records")):(1e6*column("median_ci95_high_sec")/column("n_records")) \
         with yerrorlines ls 2 notitle
unset label 101

unset multiplot
unset output
