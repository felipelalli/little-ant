reset

set terminal svg size 1200,620 enhanced font "Sans,14" background rgb "white"
set output "assets/importance-curve.svg"

bottom = 0.05
neutral = 0.35
exponent = 2.0

ranked(x) = bottom + (1.0 - bottom) * (1.0 - x / 100.0) ** exponent
factor(x,c) = neutral + c * (ranked(x) - neutral)

set title "Importance shapes chance without becoming a hard queue" font ",20"
set xlabel "Relative position among siblings   ← more important     less important →"
set ylabel "Importance factor"
set xrange [0:100]
set yrange [0:1.05]
set xtics ("top" 0, "25%%" 25, "middle" 50, "75%%" 75, "bottom" 100)
set ytics 0.1
set grid xtics ytics lc rgb "#d9dde3" lw 1
set border lc rgb "#6b7280"
set key top right box opaque samplen 3 spacing 1.25

set style line 1 lc rgb "#00875a" lw 5
set style line 2 lc rgb "#1677b8" lw 4 dt 2
set style line 3 lc rgb "#d97706" lw 4 dt 3
set style line 4 lc rgb "#7c8593" lw 3 dt 4

set arrow 1 from 0,1.0 to 100,0.05 nohead lc rgb "#00875a" dt 5 lw 1
set label 1 "20× reviewed top-to-bottom ratio" at 47,0.88 textcolor rgb "#006b48" center
set label 2 "Every eligible item keeps a positive tail" at 70,0.12 textcolor rgb "#4b5563" center

plot factor(x,1.0) with lines ls 1 title "reviewed order (confidence 1.00)", \
     factor(x,0.6) with lines ls 2 title "fresh threshold (0.60)", \
     factor(x,0.2) with lines ls 3 title "relevance threshold (0.20)", \
     factor(x,0.0) with lines ls 4 title "no current evidence (neutral)"

set output
