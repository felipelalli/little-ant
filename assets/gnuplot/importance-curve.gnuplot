reset

set terminal svg size 1200,620 enhanced font "Sans,14" background rgb "white"
set output "assets/importance-curve.svg"

count = 53
top_share = 0.60
tail_ratio = 0.70
tail_exploration = 0.02
neutral = 0.35

tail_sum = (1.0 - tail_ratio ** (count - 1)) / (1.0 - tail_ratio)
ranked(x) = x <= 1 ? 1.0 : ((1.0 - top_share) / top_share) * ((1.0 - tail_exploration) * tail_ratio ** (x - 2) / tail_sum + tail_exploration / (count - 1))
factor(x,c) = neutral + c * (ranked(x) - neutral)
total(c) = count * neutral * (1.0 - c) + c / top_share
chance(x,c) = 100.0 * factor(x,c) / total(c)

set title "Forte+: a strong first choice, then a softer fall" font ",20"
set xlabel "Sibling position (53 tasks; other factors equal)"
set ylabel "Projected chance (%) — logarithmic scale"
set xrange [1:53]
set yrange [0.01:100]
set logscale y 10
set samples 53
set xtics ("1st" 1, "10th" 10, "20th" 20, "30th" 30, "40th" 40, "53rd" 53)
set ytics ("0.01" 0.01, "0.1" 0.1, "1" 1, "10" 10, "60" 60)
set grid xtics ytics lc rgb "#d9dde3" lw 1
set border lc rgb "#6b7280"
set key top right box opaque samplen 3 spacing 1.25

set style line 1 lc rgb "#00875a" lw 5
set style line 2 lc rgb "#1677b8" lw 4 dt 2
set style line 3 lc rgb "#d97706" lw 4 dt 3
set style line 4 lc rgb "#7c8593" lw 3 dt 4

set arrow 1 from 4,40 to 1,60 head lc rgb "#00875a" lw 1
set label 1 "60% at the top with full confidence" at 5,40 textcolor rgb "#006b48" left
set label 2 "A positive tail keeps alternatives available" at 27,0.05 textcolor rgb "#4b5563" center

plot chance(x,1.0) with lines ls 1 title "full confidence (1.00)", \
     chance(x,0.6) with lines ls 2 title "fresh threshold (0.60)", \
     chance(x,0.15) with lines ls 3 title "provisional placement (0.15)", \
     chance(x,0.0) with lines ls 4 title "no current evidence (uniform)"

set output
