reset
FIGURE_NAME = "Figure_5"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 3.75
load "scripts/gnuplot/ieee_access_style.gp"

DATA = "outputs/tables/Table_Benchmark_Runtime_Summary.csv"

set logscale x 10
set xtics ("10k" 10000, "50k" 50000, "100k" 100000, "500k" 500000, "1M" 1000000, "2M" 2000000, "5M" 5000000) font "Helvetica,8" rotate by -35
set xrange [8000:6500000]
set grid xtics ytics

set multiplot layout 1,2 rowsfirst margins 0.105,0.975,0.20,0.89 spacing 0.10,0.0

# (a) Batch elapsed time. The final benchmark distinguishes steady compute from
# full end-to-end execution, so both timing regions are shown explicitly.
set logscale y 10
set format y "%.3g"
set xlabel "Number of biospecimen profiles"
set ylabel "Median elapsed time (s)"
set key top left box opaque
set label 100 "(a)" at graph 0.02,0.95 left font "Helvetica,9"
plot DATA every ::1 using ((strcol(2) eq "R" && strcol(4) eq "r_sequential" && strcol(6) eq "compute") ? $3 : 1/0):8:9:10 \
         with yerrorlines ls 1 title "Compute", \
     DATA every ::1 using ((strcol(2) eq "R" && strcol(4) eq "r_sequential" && strcol(6) eq "end_to_end") ? $3 : 1/0):8:9:10 \
         with yerrorlines ls 2 title "End-to-end"
unset label 100

# (b) Per-profile computational cost from the same median and bootstrap CI.
unset key
set xlabel "Number of biospecimen profiles"
set ylabel "Median time per profile (µs)"
set label 101 "(b)" at graph 0.02,0.95 left font "Helvetica,9"
plot DATA every ::1 using ((strcol(2) eq "R" && strcol(4) eq "r_sequential" && strcol(6) eq "compute") ? $3 : 1/0):(1e6*$8/$3):(1e6*$9/$3):(1e6*$10/$3) \
         with yerrorlines ls 1 notitle, \
     DATA every ::1 using ((strcol(2) eq "R" && strcol(4) eq "r_sequential" && strcol(6) eq "end_to_end") ? $3 : 1/0):(1e6*$8/$3):(1e6*$9/$3):(1e6*$10/$3) \
         with yerrorlines ls 2 notitle
unset label 101

unset multiplot
unset output
