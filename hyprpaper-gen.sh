#!/bin/bash

##############
## DEFAULTS ##
##############

# Default paths
config_file="$HOME/.config/hypr/hyprpaper.conf"
wallpaper_dir="$HOME/Pictures/Wallpapers/"

# Default behavior
preload_all=false
start_hyprpaper=false
restart_hyprpaper=false

this_script_name=$(basename "$0")

###############
## FUNCTIONS ##
###############

show_help() {
    cat <<EOF
---
[OPTIONS]
  Set paths:
  -c, --config          Specify the path to the configuration file 
    (default: $config_file)
  -w, --wallpapers      Specify the path to the wallpaper directory 
    (default: $wallpaper_dir)

  Modes (use exclusively):
  (no options)          Keep currently set wallpapers
  -r, --random_single   Set a single random wallpaper for all monitors
  -R, --random          Set a random wallpaper for each monitor
  -p, --pick_single     Pick a specific wallpaper for all monitors
  -P, --pick            Pick a specific wallpaper for a specific monitor
  
  Other options: 
  -a, --all             Preload ALL wallpapers from directory into RAM
                        (fast change but uses a lot of RAM)
  -s, --start           Start hyprpaper (if it's not running)
  -S, --restart         Restart hyprpaper
  -h, --help            Show this help message
---
[EXAMPLES]
  Set non-default paths, pick a random wallpaper:
    $this_script_name -r -c ~/.config/hypr/hyprpaper.conf -w ~/Pictures/Wallpapers/
  
  Pick a specific wallpaper:
    $this_script_name -p ~/Pictures/Wallpaper.jpg
  
  Pick a wallpaper for each monitor:
    $this_script_name -P eDP-1 foo.jpg DP-1 bar.png
  
  Pick a wallpaper for each monitor (but multiline):
    $this_script_name -P \\
      eDP-1  ~/Pictures/Wallpapers/foo.jpg \\
      DP-1   ~/Pictures/Wallpapers/bar.png \\
      HDMI-1 ~/Pictures/Wallpapers/baz.png \\
---
EOF
}

scan_current_config() {
    # If -P | --pick, you can manually assign wallpapers to monitors with no need for hyprctl
    #
    # I did this so i can submit this script to AUR with hyprland only as optional dependency,
    # since some might use it with other wlroots-based compositors
    if [ "$MODE" != "pick" ]; then
        # Store monitors, if hyprctl is installed
        if command -v hyprctl &>/dev/null; then
            monitors=($(hyprctl monitors | awk '/Monitor/{print $2}'))
        else
            echo "No hyprctl installed - can't automatically detect monitors!"
            echo "However, you can manually assign wallpapers to monitors using -P option."
            echo "'$this_script_name -h' for examples"
            exit 1
        fi

        # Store wallpaper paths, if directory and wallpapers do exist
        if [ -d "$wallpaper_dir" ]; then
            all_wallpapers=($(find -L "$wallpaper_dir" -maxdepth 1 -type f -regextype posix-extended -regex ".*\.(jpg|jpeg|jxl|png|xl|webp)" 2>/dev/null))
        else
            echo "$wallpaper_dir directory doesn't exist!"
            echo "'$this_script_name -w /path/to/wallpaper_directory' to set custom directory"
            exit 1
        fi
        
        # Check if there are even wallpapers
        if [ "${#all_wallpapers[@]}" -eq 0 ]; then
            echo "There are no wallpapers in the wallpaper directory!"
            exit 1
        fi
    fi

    # Store "wallpaper = ..." lines, line-by-line
    mapfile -t existing_wallpapers < <(grep 'wallpaper =' "$config_file" 2>/dev/null)
}

set_mode() { 
    # If "MODE" is not set, set it. Else, exit.
    [ ! -v MODE ] && { MODE=$1; } || { show_help; exit 1; }
}

parse_arguments() {
    while [ $# != 0 ]; do
        case "$1" in
            -c|--config)
                config_file="$2"; shift 2 ;;
            -w|--wallpapers)
                wallpaper_dir="$2"; shift 2 ;;
            -r|--random-single)
                set_mode "random_single"; shift ;;
            -R|--random)
                set_mode "random"; shift ;;
            -p|--pick-single)
                set_mode "pick_single"; picked_wallpaper="$2"; shift 2 ;;
            -P|--pick)
                set_mode "pick";
                # 1. While arg is not --option and not empty        (cycle through args)
                # 2. If second arg is not --option and not empty    (if it exists)
                # 3. Add args to mw_pairs                           (that's future $monitor and $wallpaper)
                # 4. Else, show a help message
                while [[ "$2" != -* && -n "$2" ]]; do
                    [[ "$3" != -* && -n "$3" ]] && { mw_pairs+=("$2" "$3"); shift 2; } || { show_help; exit 1; } 
                done 
                shift
                ;;
            -a|--all)
                preload_all=true; shift ;;
            -s|--start)
                start_hyprpaper=true; shift ;;
            -S|--restart)
                restart_hyprpaper=true; shift ;;
            -h|--help)
                show_help; exit 0 ;;
            -*)
                echo "Unknown option: $1"; show_help; exit 1
                ;;
            *)
                break
                ;;
        esac
    done
}

generate_config() {
    echo "# This file was generated by $this_script_name" > "$config_file"
    echo "" >> "$config_file"

    case $MODE in
        # Generate same random "wallpaper =" line for all monitors
        "random_single")
            random_wallpaper="${all_wallpapers[RANDOM % ${#all_wallpapers[@]}]}"
            echo "preload = $random_wallpaper" >> "$config_file"
            echo "" >> "$config_file"
            for monitor in "${monitors[@]}"; do
                echo "wallpaper = $monitor,$random_wallpaper" >> "$config_file"
            done
            echo "" >> "$config_file"
            ;;

        # Generate random "wallpaper =" lines for every monitor
        "random")     
            for monitor in "${monitors[@]}"; do
                random_wallpaper="${all_wallpapers[RANDOM % ${#all_wallpapers[@]}]}"
                echo "preload = $random_wallpaper" >> "$config_file"
                echo "wallpaper = $monitor,$random_wallpaper" >> "$config_file"
                echo "" >> "$config_file" 
            done
            ;;

        # Pick a single wallpaper and generate "wallpaper =" for every monitor
        "pick_single")
            echo "preload = $picked_wallpaper" >> "$config_file"
            echo "" >> "$config_file"
            for monitor in "${monitors[@]}"; do
                echo "wallpaper = $monitor,$picked_wallpaper" >> "$config_file"
            done
            echo "" >> "$config_file"
            ;;

        # Pick monitor and wallpaper, and generate "wallpaper =" lines for them
        "pick") 
            for ((i = 0; i < ${#mw_pairs[@]}; i += 2)); do
                monitor="${mw_pairs[i]}"; wallpaper="${mw_pairs[i+1]}"
                echo "preload = $wallpaper" >> "$config_file"
                echo "wallpaper = $monitor,$wallpaper" >> "$config_file"
                echo "" >> "$config_file"
            done
            ;;

        # (default behaviour) 
        # Keep current wallpapers
        # Set random for every new monitor
        *)
            for monitor in "${monitors[@]}"; do
                # If a "wallpaper =" line is set, reuse it
                if [[ "${existing_wallpapers[@]}" == "wallpaper = $monitor"* ]]; then
                    wallpaper=$(echo "${existing_wallpapers[@]}" | grep $monitor | awk -F '[ ,]' '{print $4}')
                    echo "preload = $wallpaper" >> "$config_file"
                    echo "wallpaper = $monitor,$wallpaper" >> "$config_file"
                    echo "" >> "$config_file"
                    existing_wallpapers=("${existing_wallpapers[@]:1}")
                # If there's no "wallpaper =" line for a monitor, generate it
                else
                    random_wallpaper="${all_wallpapers[RANDOM % ${#all_wallpapers[@]}]}"
                    echo "preload = $random_wallpaper" >> "$config_file"
                    echo "wallpaper = ${monitor[@]},$random_wallpaper" >> "$config_file"
                    echo "" >> "$config_file"
                fi
            done
            ;;
    esac

    # Just preload all pictures from directory into RAM
    if $preload_all; then
        echo "# 'Preload all' flag have been set" >> "$config_file"
        for wallpaper in "${all_wallpapers[@]}"; do
            echo "preload = $wallpaper" >> "$config_file"
        done
    fi

}

##########
## MAIN ##
##########

parse_arguments "$@";
scan_current_config;
generate_config;

if $start_hyprpaper && ! pgrep -x "hyprpaper" > /dev/null; then
    hyprpaper -c $config_file &
fi

if $restart_hyprpaper; then 
    killall hyprpaper; 
    hyprpaper -c $config_file & 
fi
