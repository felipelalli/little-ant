reset

set terminal svg size 1200,620 enhanced font "Sans,13" background rgb "white"
set output "assets/judgment-confidence.svg"

direct(x) = x <= 365 ? 1.00 * (365.0 - x) / 365.0 : 0
assisted(x) = x <= 270 ? 0.80 * (270.0 - x) / 270.0 : 0
model(x) = x <= 30 ? 0.30 * (30.0 - x) / 30.0 : 0
provisional(x) = x <= 30 ? 0.15 * (30.0 - x) / 30.0 : 0

set multiplot layout 1,2 title "Judgment grows stale — history does not disappear" font ",20"

set style line 1 lc rgb "#00875a" lw 5
set style line 2 lc rgb "#1677b8" lw 4
set style line 3 lc rgb "#d97706" lw 4
set style line 4 lc rgb "#8b5cf6" lw 4
set style line 5 lc rgb "#6b7280" lw 2 dt 3

set grid xtics ytics lc rgb "#d9dde3" lw 1
set border lc rgb "#6b7280"
set ylabel "Effective confidence"
set yrange [0:1.05]
set ytics 0.1

set title "Human-reviewed evidence"
set xlabel "Days since judgment"
set xrange [0:365]
set xtics 60
set key top right box opaque spacing 1.2
set arrow 1 from 0,0.60 to 365,0.60 nohead ls 5
set arrow 2 from 0,0.20 to 365,0.20 nohead ls 5
set label 1 "fresh conflict threshold" at 235,0.63 textcolor rgb "#4b5563"
set label 2 "relevance threshold" at 252,0.23 textcolor rgb "#4b5563"
plot direct(x) with lines ls 1 title "direct human", \
     assisted(x) with lines ls 2 title "accepted assisted proposal"

unset label 1
unset label 2
unset arrow 1
unset arrow 2
set title "Low-authority starting evidence"
set xlabel "Days since proposal or placement"
set xrange [0:30]
set xtics 5
set key top right box opaque spacing 1.2
plot model(x) with lines ls 3 title "model-only proposal", \
     provisional(x) with lines ls 4 title "provisional placement"

unset multiplot
set output
