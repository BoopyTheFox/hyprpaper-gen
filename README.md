# hyprpaper-gen

## What is it 
A simple script to ease management of hyprpaper.conf

## What can it do
- Randomize wallpapers
	- One for all monitors
	- Random for all monitors
- Pick specific wallpapers
	- One for all monitors
	- Pick for every monitor
- Detect and keep already assigned wallpapers (if no options are specified)
- Preload all wallpapers from specific directory into RAM (if you're into that kinda stuff)

## How can it be used
1. Generate config once and forget it
2. Generate it each time hyprland starts (if you wanna randomize wallpapers, for example)

## Installation 

### git
1. Clone and copy script to your hypr dir
```bash
git clone https://github.com/BoopyTheFox/hyprpaper-gen
cd hyprpaper-gen
cp hyprpaper-gen ~/.config/hypr/scripts
```
2. Then just put in somewhere into your hyprland.conf
```conf
exec-once = ~/.config/hypr/scripts/hyprpaper-gen.sh --start
```

### AUR (WIP)
It is also available in AUR (not yet)
```bash
paru -S hyprpaper-gen-git
```

```conf
exec-once = hyprpaper-gen --start
```
