reset

set terminal svg size 1200,620 enhanced font "Sans,13" background rgb "white"
set output "assets/judgment-confidence.svg"

# Public labels derived from the normative linear confidence profile:
# 3 = reviewed, 2 = provisional, 1 = review due, 0 = historical only.
$data << EOD
0 3 3 "reviewed"
1 3 3 "reviewed"
2 3 3 "reviewed"
3 3 3 "reviewed"
4 3 2 "provisional"
5 3 2 "provisional"
6 3 0 "historical only"

0 2 3 "reviewed"
1 2 3 "reviewed"
2 2 3 "reviewed"
3 2 2 "provisional"
4 2 2 "provisional"
5 2 0 "historical only"
6 2 0 "historical only"

0 1 2 "provisional"
1 1 2 "provisional"
2 1 0 "historical only"
3 1 0 "historical only"
4 1 0 "historical only"
5 1 0 "historical only"
6 1 0 "historical only"

0 0 1 "review due"
1 0 1 "review due"
2 0 0 "historical only"
3 0 0 "historical only"
4 0 0 "historical only"
5 0 0 "historical only"
6 0 0 "historical only"
EOD

set title "How judgment evidence ages" font ",20" offset 0,1
set label 1 "Factory defaults · public labels · history remains inspectable" \
  at screen 0.5,0.91 center textcolor rgb "#4b5563" font ",12"

set xrange [-0.5:6.5]
set yrange [-0.5:3.5]
set xtics ("today" 0, "1 week" 1, "1 month" 2, "3 months" 3, \
           "6 months" 4, "9 months" 5, "1 year" 6) scale 0
set ytics ("provisional placement" 0, "model-only proposal" 1, \
           "accepted assisted proposal" 2, "direct human answer" 3) scale 0
set xlabel "Age of the evidence" offset 0,-0.5
set border 0
unset key
unset colorbox

set palette maxcolors 4
set palette defined (0 "#e5e7eb", 1 "#f6c453", 2 "#7dd3fc", 3 "#6ee7b7")
set cbrange [-0.5:3.5]
set style fill solid 1.0 border lc rgb "#ffffff"

plot $data using 1:2:(0.49):(0.47):3 with boxxyerror lc palette, \
     '' using 1:2:4 with labels center font ",11" textcolor rgb "#1f2937"

set output
