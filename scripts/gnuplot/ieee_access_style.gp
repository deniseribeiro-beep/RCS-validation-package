# Shared IEEE Access graphics style.
# The calling script must define FIGURE_NAME, FIGURE_WIDTH, and FIGURE_HEIGHT.
# OUTPUT_MODE may be set to 'pdf' or 'png'; PDF is the default.
# Output directories are created by the platform-specific generation wrapper.

if (!exists("OUTPUT_MODE")) OUTPUT_MODE = "pdf"
if (!exists("OUTPUT_DIR")) OUTPUT_DIR = "outputs/figures"
if (!exists("FIGURE_NAME")) { print "FIGURE_NAME is required"; exit }
if (!exists("FIGURE_WIDTH")) FIGURE_WIDTH = 7.16
if (!exists("FIGURE_HEIGHT")) FIGURE_HEIGHT = 4.5

set encoding utf8
set datafile separator comma
set datafile missing "NA"
set decimalsign locale "C"

# PDF is sized in physical inches. PNG uses the same proportions at 600 dpi.
# pngcairo fontscale/linewidth/pointscale preserve the physical appearance of
# the PDF when the raster canvas is enlarged for publication-resolution output.
DEVICE_SCALE = 1.0
if (OUTPUT_MODE eq "png") {
    OUTPUT_DPI = 600.0
    RASTER_SCALE = OUTPUT_DPI / 72.0
    PX_W = int(FIGURE_WIDTH * OUTPUT_DPI + 0.5)
    PX_H = int(FIGURE_HEIGHT * OUTPUT_DPI + 0.5)
    eval sprintf("set terminal pngcairo enhanced color font 'Helvetica,10' fontscale %.5f linewidth %.5f pointscale %.5f size %d,%d", RASTER_SCALE, RASTER_SCALE, RASTER_SCALE, PX_W, PX_H)
    set output sprintf("%s/%s.png", OUTPUT_DIR, FIGURE_NAME)
} else {
    eval sprintf("set terminal pdfcairo enhanced color font 'Helvetica,10' size %.3fin,%.3fin", FIGURE_WIDTH, FIGURE_HEIGHT)
    set output sprintf("%s/%s.pdf", OUTPUT_DIR, FIGURE_NAME)
}

set border linewidth 1.0 linecolor rgb "#3A3A3A"
set tics out nomirror scale 0.45 font "Helvetica,9"
set xlabel font "Helvetica,10"
set ylabel font "Helvetica,10"
set cblabel font "Helvetica,9"
set cbtics font "Helvetica,8"
set key font "Helvetica,9" samplen 2.0 spacing 1.08
set grid back linewidth 0.45 dashtype 3 linecolor rgb "#D9D9D9"

# Colour-blind-conscious line styles. Colour is reinforced by line type and
# point symbol so figures remain interpretable in grayscale.
set style line 1 linecolor rgb "#0072B2" linewidth 1.55 dashtype 1 pointtype 7 pointsize 0.82
set style line 2 linecolor rgb "#D55E00" linewidth 1.55 dashtype 2 pointtype 5 pointsize 0.82
set style line 3 linecolor rgb "#009E73" linewidth 1.55 dashtype 4 pointtype 9 pointsize 0.82
set style line 4 linecolor rgb "#CC79A7" linewidth 1.55 dashtype 5 pointtype 11 pointsize 0.82
set style line 5 linecolor rgb "#4D4D4D" linewidth 1.25 dashtype 3 pointtype 13 pointsize 0.76
