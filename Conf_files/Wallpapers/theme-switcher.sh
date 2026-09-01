#!/bin/bash
# ~/.config/wallpapers/theme-switcher.sh

WALL_DIR="$HOME/.config/wallpapers"
DAY_DIR="$WALL_DIR/day"
NIGHT_DIR="$WALL_DIR/night"
CURRENT_WALL=""
CURRENT_THEME=""

apply_theme() {
    local theme="$1"
    local target_dir="$2"

    # Se la cartella è vuota o non esiste, esce per sicurezza
    [[ ! -d "$target_dir" ]] && return 1

    # Pescaggio casuale di un'immagine valida (supporta jpg, jpeg, png, webp)
    local wall
    wall=$(find "$target_dir" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n 1)

    [[ -z "$wall" ]] && return 1

    # Evita di ricaricare lo stesso identico wallpaper se per caso viene estratto lo stesso
    if [[ "$CURRENT_WALL" == "$wall" ]]; then
        return 0
    fi
    CURRENT_WALL="$wall"

    # 1. Imposta lo sfondo in base al Window Manager in uso
    if [[ "$XDG_CURRENT_DESKTOP" == "Hyprland" ]]; then
        hyprctl hyprpaper preload "$wall"
        hyprctl hyprpaper wallpaper ",$wall"
    else
        # Per Niri e gli altri usiamo swww
        swww img "$wall" --transition-type wipe --transition-duration 2
    fi

    # 2. Wallust estrae i colori e genera i file (Usa palette scura se siamo nella cartella night)
    if [[ "$theme" == "night" ]]; then
        wallust run "$wall" --palette dark16
    else
        wallust run "$wall"
    fi

    # 3. Ricarica a caldo Waybar e Swaync per applicare i nuovi colori
    killall -SIGUSR2 waybar
    swaync-client -rs

    CURRENT_THEME="$theme"
}

# Assicuriamoci che i demoni degli sfondi siano pronti all'avvio
sleep 3

while true; do
    HOUR=$(date +%H)
    
    # Giorno: dalle 07:00 alle 18:59
    if (( HOUR >= 7 && HOUR < 19 )); then
        if [[ "$CURRENT_THEME" != "day" ]]; then
            apply_theme "day" "$DAY_DIR"
        fi
    # Notte: dalle 19:00 alle 06:59
    else
        if [[ "$CURRENT_THEME" != "night" ]]; then
            apply_theme "night" "$NIGHT_DIR"
        fi
    fi
    
    # Controlla ogni 5 minuti se è ora di cambiare fascia oraria
    sleep 300
done
