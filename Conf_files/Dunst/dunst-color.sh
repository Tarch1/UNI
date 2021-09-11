#!/bin/sh

#        -lf/nf/cf color
#            Defines the foreground color for low, normal and critical notifications respectively.
# 
#        -lb/nb/cb color
#            Defines the background color for low, normal and critical notifications respectively.
# 
#        -lfr/nfr/cfr color
#            Defines the frame color for low, normal and critical notifications respectively.


[ -f "$HOME/.cache/wal/colors.sh" ] && . "$HOME/.cache/wal/colors.sh"

pidof dunst && killall dunst
dunst -lf  $color15 \
      -lb  $color3 \
      -lfr $color6 \
      -nf  $color1 \
      -nb  $color4 \
      -nfr $color7 \
      -cf  $color9 \
      -cb  $color5 \
      -cfr $color8 > /dev/null 2>&1 &
