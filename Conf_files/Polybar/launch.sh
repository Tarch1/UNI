#pkill -f 'hideIt.sh'
#pkill -f 'polybar'

source ~/.cache/wal/colors.sh
export color0_alpha="#22${color1/'#'}"

polybar bar1 2>&1 | tee -a /tmp/polybar1.log & disown
echo "Bars launched..."
#sleep 1
#~/.config/polybar/hide -w -d top -N 'polybar' --region 560x10+800+-100 & disown
#~/.config/polybar/hide -w -d top -N 'polybar' -d top -H -p 3 & disown
