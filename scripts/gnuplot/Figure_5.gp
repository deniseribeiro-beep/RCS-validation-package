reset
FIGURE_NAME = "Figure_5"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 5.65
load "scripts/gnuplot/ieee_access_style.gp"

DATA = "outputs/tables/Table_Benchmark_Runtime_Summary.csv"

set logscale x 10
set xrange [8000:6500000]
set xtics ("10k" 10000, "50k" 50000, "100k" 100000, "500k" 500000, "1M" 1000000, "2M" 2000000, "5M" 5000000) font sprintf("Helvetica,%.1f", FS_SMALL)
set grid xtics ytics

# Stacked panels reproduce the manuscript's readable runtime layout. The final
# benchmark retains the distinction between steady compute and end-to-end time.
set multiplot layout 2,1 rowsfirst margins 0.13,0.975,0.105,0.94 spacing 0.0,0.13

# (a) Batch elapsed time
set logscale y 10
set yrange [0.001:10]
set format y "%.3g"
unset xlabel
set ylabel "Median elapsed time (s)" offset 0.7,0
set key top left horizontal opaque no box
set label 100 "(a)" at graph 0.015,0.91 left font sprintf("Helvetica,%.1f", FS_PANEL)
plot DATA every ::1 using ((strcol(2) eq "R" && strcol(4) eq "r_sequential" && strcol(6) eq "compute") ? $3 : 1/0):8:9:10 \
         with yerrorlines ls 1 title "Compute", \
     DATA every ::1 using ((strcol(2) eq "R" && strcol(4) eq "r_sequential" && strcol(6) eq "end_to_end") ? $3 : 1/0):8:9:10 \
         with yerrorlines ls 2 title "End-to-end"
unset label 100

# (b) Per-profile cost derived from the same medians and bootstrap intervals
unset key
set yrange [0.1:100]
set format y "%.3g"
set xlabel "Number of biospecimen profiles" offset 0,0.35
set ylabel "Median time per profile (µs)" offset 0.7,0
set label 101 "(b)" at graph 0.015,0.91 left font sprintf("Helvetica,%.1f", FS_PANEL)
plot DATA every ::1 using ((strcol(2) eq "R" && strcol(4) eq "r_sequential" && strcol(6) eq "compute") ? $3 : 1/0):(1e6*$8/$3):(1e6*$9/$3):(1e6*$10/$3) \
         with yerrorlines ls 1 notitle, \
     DATA every ::1 using ((strcol(2) eq "R" && strcol(4) eq "r_sequential" && strcol(6) eq "end_to_end") ? $3 : 1/0):(1e6*$8/$3):(1e6*$9/$3):(1e6*$10/$3) \
         with yerrorlines ls 2 notitle
unset label 101

unset multiplot
unset output
