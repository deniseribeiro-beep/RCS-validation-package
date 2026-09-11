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

# PDF is sized in physical inches. PNG uses the same physical proportions at
# 600 dpi; font and line dimensions are scaled so the raster output visually
# matches the PDF instead of producing undersized text.
if (OUTPUT_MODE eq "png") {
    OUTPUT_DPI = 600.0
    DEVICE_SCALE = OUTPUT_DPI / 72.0
    PX_W = int(FIGURE_WIDTH * OUTPUT_DPI + 0.5)
    PX_H = int(FIGURE_HEIGHT * OUTPUT_DPI + 0.5)
    eval sprintf("set terminal pngcairo enhanced color font 'Helvetica,%.1f' size %d,%d", 10.0*DEVICE_SCALE, PX_W, PX_H)
    set output sprintf("%s/%s.png", OUTPUT_DIR, FIGURE_NAME)
} else {
    DEVICE_SCALE = 1.0
    eval sprintf("set terminal pdfcairo enhanced color font 'Helvetica,10' size %.3fin,%.3fin", FIGURE_WIDTH, FIGURE_HEIGHT)
    set output sprintf("%s/%s.pdf", OUTPUT_DIR, FIGURE_NAME)
}

FS_TICK = 9.0 * DEVICE_SCALE
FS_AXIS = 10.0 * DEVICE_SCALE
FS_SMALL = 8.0 * DEVICE_SCALE
FS_ANNOT = 8.5 * DEVICE_SCALE
FS_PANEL = 10.0 * DEVICE_SCALE
FS_KEY = 9.0 * DEVICE_SCALE
LW_BASE = 1.0 * DEVICE_SCALE
LW_DATA = 1.55 * DEVICE_SCALE
LW_GRID = 0.45 * DEVICE_SCALE

set border linewidth LW_BASE linecolor rgb "#3A3A3A"
set tics out nomirror scale 0.45 font sprintf("Helvetica,%.1f", FS_TICK)
set xlabel font sprintf("Helvetica,%.1f", FS_AXIS)
set ylabel font sprintf("Helvetica,%.1f", FS_AXIS)
set cblabel font sprintf("Helvetica,%.1f", FS_KEY)
set cbtics font sprintf("Helvetica,%.1f", FS_SMALL)
set key font sprintf("Helvetica,%.1f", FS_KEY) samplen 2.0 spacing 1.08
set grid back linewidth LW_GRID dashtype 3 linecolor rgb "#D9D9D9"

# Colour-blind-conscious line styles. Colour is reinforced by line type and
# point symbol so figures remain interpretable in grayscale.
set style line 1 linecolor rgb "#0072B2" linewidth LW_DATA dashtype 1 pointtype 7 pointsize 0.82
set style line 2 linecolor rgb "#D55E00" linewidth LW_DATA dashtype 2 pointtype 5 pointsize 0.82
set style line 3 linecolor rgb "#009E73" linewidth LW_DATA dashtype 4 pointtype 9 pointsize 0.82
set style line 4 linecolor rgb "#CC79A7" linewidth LW_DATA dashtype 5 pointtype 11 pointsize 0.82
set style line 5 linecolor rgb "#4D4D4D" linewidth (1.25*DEVICE_SCALE) dashtype 3 pointtype 13 pointsize 0.76
