#!/bin/bash
# 256 Farben für Dark-Mode (Vordergrund auf Schwarz, Hintergrundblöcke)

echo "=== 256 Farben als Text auf schwarzem Grund (Dark-Mode) ==="
for i in {0..255}; do
    # Schwarzer Hintergrund (48;5;0) + Farbe i als Schrift
    printf "\e[48;5;0;38;5;${i}m%3d \e[0m" $i
    if [ $(( (i+1) % 16 )) -eq 0 ] || [ $i -eq 255 ]; then
        echo
    fi
done
echo

echo "=== 256 Farben als Hintergrundblöcke (Terminalhintergrund bleibt dunkel) ==="
for i in {0..255}; do
    # Hintergrund = Farbe i, Schriftfarbe automatisch (hier schwarz/weiß)
    if [ $i -lt 16 ] || ( [ $i -ge 232 ] && [ $i -le 243 ] ); then
        fg=97   # weiß für sehr dunkle Hintergründe
    else
        fg=30   # schwarz für helle Hintergründe
    fi
    printf "\e[${fg};48;5;${i}m%3d \e[0m" $i
    if [ $(( (i+1) % 16 )) -eq 0 ] || [ $i -eq 255 ]; then
        echo
    fi
done
