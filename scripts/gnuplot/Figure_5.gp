reset
FIGURE_NAME = "Figure_5"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 5.65
load "scripts/gnuplot/ieee_access_style.gp"

if (!exists("TABLES_DIR")) TABLES_DIR = "outputs/local/tables"
DATA = sprintf("%s/Table_Benchmark_Runtime_Summary.csv", TABLES_DIR)

set logscale x 10
set xrange [8000:6500000]
set xtics ("10k" 10000, "50k" 50000, "100k" 100000, "500k" 500000, "1M" 1000000, "2M" 2000000, "5M" 5000000) font "Helvetica,8"
set grid xtics ytics

set multiplot layout 2,1 rowsfirst margins 0.13,0.975,0.105,0.94 spacing 0.0,0.13

# (a) C reference batch elapsed time
set logscale y 10
set autoscale y
set format y "%.3g"
unset xlabel
set ylabel "Median elapsed time (s)" offset 0.7,0
set key top left horizontal opaque nobox
set label 100 "(a) C reference" at graph 0.015,0.91 left font "Helvetica,10"
plot DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "compute") ? column("n_records") : 1/0):(column("median_elapsed_sec")):(column("median_ci95_low_sec")):(column("median_ci95_high_sec")) \
         with yerrorlines ls 1 title "Compute", \
     DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "end_to_end") ? column("n_records") : 1/0):(column("median_elapsed_sec")):(column("median_ci95_low_sec")):(column("median_ci95_high_sec")) \
         with yerrorlines ls 2 title "End-to-end"
unset label 100

# (b) Per-profile cost derived from the same medians and bootstrap intervals
unset key
set autoscale y
set format y "%.3g"
set xlabel "Number of biospecimen profiles" offset 0,0.35
set ylabel "Median time per profile (µs)" offset 0.7,0
set label 101 "(b)" at graph 0.015,0.91 left font "Helvetica,10"
plot DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "compute") ? column("n_records") : 1/0):(1e6*column("median_elapsed_sec")/column("n_records")):(1e6*column("median_ci95_low_sec")/column("n_records")):(1e6*column("median_ci95_high_sec")/column("n_records")) \
         with yerrorlines ls 1 notitle, \
     DATA every ::1 using ((stringcolumn("language_family") eq "C reference" && stringcolumn("implementation") eq "c_reference" && stringcolumn("timing_region") eq "end_to_end") ? column("n_records") : 1/0):(1e6*column("median_elapsed_sec")/column("n_records")):(1e6*column("median_ci95_low_sec")/column("n_records")):(1e6*column("median_ci95_high_sec")/column("n_records")) \
         with yerrorlines ls 2 notitle
unset label 101

unset multiplot
unset output
