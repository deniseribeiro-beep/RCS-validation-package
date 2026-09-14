# Shared publication graphics style.
# The calling script must define FIGURE_NAME, FIGURE_WIDTH, and FIGURE_HEIGHT.
# Final generated figures are vector PDF only.
# Output directories are created by the platform-specific generation wrapper.

if (!exists("OUTPUT_DIR")) OUTPUT_DIR = "outputs/local/figures"
if (!exists("FIGURE_NAME")) { print "FIGURE_NAME is required"; exit }
if (!exists("FIGURE_WIDTH")) FIGURE_WIDTH = 7.16
if (!exists("FIGURE_HEIGHT")) FIGURE_HEIGHT = 4.5

set encoding utf8
set datafile separator comma
set datafile missing "NA"
set decimalsign locale "C"

# Portable sans-serif family avoids platform-specific Helvetica substitution
# while preserving a journal-style neutral typeface.
eval sprintf("set terminal pdfcairo enhanced color font 'Sans,11' size %.3fin,%.3fin", FIGURE_WIDTH, FIGURE_HEIGHT)
set output sprintf("%s/%s.pdf", OUTPUT_DIR, FIGURE_NAME)

set border linewidth 1.15 linecolor rgb "#3A3A3A"
set tics out nomirror scale 0.52 font "Sans,10"
set xlabel font "Sans,11"
set ylabel font "Sans,11"
set cblabel font "Sans,10"
set cbtics font "Sans,9"
set key font "Sans,10" samplen 2.0 spacing 1.10
set grid back linewidth 0.55 dashtype 3 linecolor rgb "#D9D9D9"

set style line 1 linecolor rgb "#3F8AE0" linewidth 1.90 dashtype 1 pointtype 7 pointsize 1.00
set style line 2 linecolor rgb "#5A5A5A" linewidth 1.80 dashtype 1 pointtype 9 pointsize 0.95
set style line 3 linecolor rgb "#009E73" linewidth 1.80 dashtype 4 pointtype 9 pointsize 0.95
set style line 4 linecolor rgb "#CC79A7" linewidth 1.80 dashtype 5 pointtype 11 pointsize 0.95
set style line 5 linecolor rgb "#4D4D4D" linewidth 1.45 dashtype 3 pointtype 13 pointsize 0.90
