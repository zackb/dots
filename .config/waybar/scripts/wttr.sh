#!/usr/bin/sh
req=$(curl -s 'wttr.in?lang=gibberish&format=%25t%7C%25l%2B(%25c%25f)%2B%25h%2C%2B%25C')
bar=$(echo $req | awk -F "|" '{print $1}')
tooltip=$(echo $req | awk -F "|" '{print $2}')
echo "{\"text\":\"$bar\", \"tooltip\":\"$tooltip\"}"
