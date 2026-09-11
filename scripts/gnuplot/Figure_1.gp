reset
FIGURE_NAME = "Figure_1"
FIGURE_WIDTH = 7.16
FIGURE_HEIGHT = 5.25
load "scripts/gnuplot/ieee_access_style.gp"

unset key
unset border
unset tics
unset grid
set xrange [0:100]
set yrange [0:100]

# Layer headings
set label 1 "Evidence layer" at 3,96 left font "Helvetica,10"
set label 2 "Governance admissibility layer" at 3,72 left font "Helvetica,10"
set label 3 "RCS scoring layer" at 3,39 left font "Helvetica,10"

# Evidence boxes
set object 1 rect from 4,79 to 30,92 fc rgb "#EEF3F8" fs solid 1.0 border lc rgb "#404040" lw 1.0
set object 2 rect from 37,79 to 63,92 fc rgb "#F4F4F4" fs solid 1.0 border lc rgb "#404040" lw 1.0
set object 3 rect from 70,79 to 96,92 fc rgb "#EEF3F8" fs solid 1.0 border lc rgb "#404040" lw 1.0
set label 11 "SPREC-derived\npre-analytical evidence" at 17,85.5 center font "Helvetica,9"
set label 12 "ISO 20387 / ISBER\ngovernance evidence" at 50,85.5 center font "Helvetica,9"
set label 13 "MIABIS-compatible\nmetadata" at 83,85.5 center font "Helvetica,9"

# Governance checks
set object 10 rect from 4,57 to 18,67 fc rgb "#F7F7F7" fs solid 1.0 border lc rgb "#505050" lw 0.9
set object 11 rect from 20,57 to 34,67 fc rgb "#F7F7F7" fs solid 1.0 border lc rgb "#505050" lw 0.9
set object 12 rect from 36,57 to 50,67 fc rgb "#F7F7F7" fs solid 1.0 border lc rgb "#505050" lw 0.9
set object 13 rect from 52,57 to 66,67 fc rgb "#F7F7F7" fs solid 1.0 border lc rgb "#505050" lw 0.9
set object 14 rect from 68,57 to 82,67 fc rgb "#F7F7F7" fs solid 1.0 border lc rgb "#505050" lw 0.9
set object 15 rect from 84,57 to 98,67 fc rgb "#F7F7F7" fs solid 1.0 border lc rgb "#505050" lw 0.9
set label 20 "Semantic\nvalidation" at 11,62 center font "Helvetica,8"
set label 21 "Metadata\ncompleteness" at 27,62 center font "Helvetica,8"
set label 22 "Documentation" at 43,62 center font "Helvetica,8"
set label 23 "Monitoring" at 59,62 center font "Helvetica,8"
set label 24 "Traceability" at 75,62 center font "Helvetica,8"
set label 25 "Terminology\ncompatibility" at 91,62 center font "Helvetica,8"

set object 20 rect from 38,44 to 62,53 fc rgb "#DDEAF3" fs solid 1.0 border lc rgb "#303030" lw 1.2
set label 30 "Governance gate" at 50,48.5 center font "Helvetica,9"

# Scoring boxes
set object 30 rect from 4,19 to 36,34 fc rgb "#EEF3F8" fs solid 1.0 border lc rgb "#404040" lw 1.0
set object 31 rect from 43,19 to 75,34 fc rgb "#EEF3F8" fs solid 1.0 border lc rgb "#404040" lw 1.0
set label 40 "Fluid biospecimens\nP_pre  P_cent1  P_cent2\nP_post  P_store" at 20,26.5 center font "Helvetica,8"
set label 41 "Solid biospecimens\nP_warm  P_cold  P_fix\nP_fixTime  P_store" at 59,26.5 center font "Helvetica,8"

set object 32 rect from 80,19 to 96,34 fc rgb "#E7F2EC" fs solid 1.0 border lc rgb "#404040" lw 1.0
set label 42 "RCS = 100 - P_bio\nOperational grade\nA-E" at 88,26.5 center font "Helvetica,8"

# Non-admissible route
set object 40 rect from 70,43 to 96,52 fc rgb "#F3E7E7" fs solid 1.0 border lc rgb "#505050" lw 1.0
set label 50 "Non-admissible: Grade E" at 83,47.5 center font "Helvetica,8"

# Flow arrows
set arrow 1 from 17,79 to 17,69 head filled size screen 0.010,15,45 lw 1.0 lc rgb "#4A4A4A"
set arrow 2 from 50,79 to 50,69 head filled size screen 0.010,15,45 lw 1.0 lc rgb "#4A4A4A"
set arrow 3 from 83,79 to 83,69 head filled size screen 0.010,15,45 lw 1.0 lc rgb "#4A4A4A"
set arrow 4 from 50,57 to 50,53 head filled size screen 0.010,15,45 lw 1.1 lc rgb "#303030"
set arrow 5 from 62,48.5 to 70,48.5 head filled size screen 0.010,15,45 lw 1.0 lc rgb "#4A4A4A"
set arrow 6 from 50,44 to 50,38 nohead lw 1.0 lc rgb "#4A4A4A"
set arrow 7 from 50,38 to 20,38 nohead lw 1.0 lc rgb "#4A4A4A"
set arrow 8 from 20,38 to 20,34 head filled size screen 0.010,15,45 lw 1.0 lc rgb "#4A4A4A"
set arrow 9 from 50,38 to 59,38 nohead lw 1.0 lc rgb "#4A4A4A"
set arrow 10 from 59,38 to 59,34 head filled size screen 0.010,15,45 lw 1.0 lc rgb "#4A4A4A"
set arrow 11 from 36,26.5 to 43,26.5 head filled size screen 0.010,15,45 lw 0.9 lc rgb "#707070"
set arrow 12 from 75,26.5 to 80,26.5 head filled size screen 0.010,15,45 lw 1.0 lc rgb "#4A4A4A"

set label 60 "Admissible" at 52,40.5 left font "Helvetica,8"

plot NaN notitle
unset output
