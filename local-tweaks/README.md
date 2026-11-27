# Archived DiaTweaks Local Setup

Archived on 2026-11-27 (`DiaTweaks v1.2.0` / `086ca40`).

## Contents
- `local/` — Local tweaks from `~/Library/Application Support/DiaPatches/local/`:
  - `EdgeToEdgeChat.m`
  - `ProfileIcons/`
  - `SidebarAddress/`
  - `SiteSearch/`
- `com.diapatches.plist` — Exported `com.diapatches` preferences.

## Restore
```sh
mkdir -p "$HOME/Library/Application Support/DiaPatches/local"
cp -R local-tweaks/local/* "$HOME/Library/Application Support/DiaPatches/local/"
defaults import com.diapatches local-tweaks/com.diapatches.plist
~/Library/Application\ Support/DiaPatches/bin/diapatch install --relaunch
```
