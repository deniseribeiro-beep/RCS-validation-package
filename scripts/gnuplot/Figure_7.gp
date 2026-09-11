reset
FIGURE_NAME = "Figure_7"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 4.05
load "scripts/gnuplot/ieee_access_style.gp"

DATA = "outputs/tables/Table_Benchmark_CUDA_Speedup_Summary.csv"

set logscale x 10
set logscale y 10
set xrange [8000:6500000]
set yrange [0.02:120]
set xtics ("10k" 10000, "50k" 50000, "100k" 100000, "500k" 500000, "1M" 1000000, "2M" 2000000, "5M" 5000000) font "Helvetica,8" rotate by -30
set ytics ("0.03" 0.03, "0.1" 0.1, "0.3" 0.3, "1" 1, "3" 3, "10" 10, "30" 30, "100" 100)
set xlabel "Number of biospecimen profiles"
set ylabel "Acceleration relative to C++ sequential (×)"
set key top right box opaque
set grid xtics ytics
set arrow 900 from graph 0, first 1 to graph 1, first 1 nohead dashtype 3 linewidth 1.0 linecolor rgb "#777777" back

plot DATA every ::1 using (strcol(2) eq "compute" ? $1 : 1/0):4:5:6 \
         with yerrorlines ls 1 title "Compute", \
     DATA every ::1 using (strcol(2) eq "end_to_end" ? $1 : 1/0):4:5:6 \
         with yerrorlines ls 2 title "End-to-end"

unset output
