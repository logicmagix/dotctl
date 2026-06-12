-- dotctl - hyprland keybindings (Lua format for v0.55+)
-- -----------------------------------------------------------------------------
-- User-sourceable keybind snippet. Add this line to ~/.config/hypr/hyprland.lua:
--
--     dofile(os.getenv("HOME") .. "/.config/hypr/dotctl-keybinds.lua")
--
-- These binds are safe to comment out individually if they collide with your
-- existing setup.
-- -----------------------------------------------------------------------------

-- --- Waybar & wallpaper cycling ----------------------------------------------
-- NOTE: uses hardcoded SUPER (Mod4) instead of mainMod so the snippet works
-- regardless of where in hyprland.lua the dofile() directive is placed.
-- If you use a different main modifier, edit the "SUPER + ALT" tokens below.
--
-- Cycle through the 4 canonical waybar variants (pill/console x full/minimal)
hl.bind("SUPER + ALT + Up",    hl.dsp.exec_cmd("dotctl cycle waybar next"))
hl.bind("SUPER + ALT + Down",  hl.dsp.exec_cmd("dotctl cycle waybar prev"))
-- Cycle the wallpaper image within the current theme
hl.bind("SUPER + ALT + Right", hl.dsp.exec_cmd("dotctl cycle wallpaper next"))
hl.bind("SUPER + ALT + Left",  hl.dsp.exec_cmd("dotctl cycle wallpaper prev"))

-- --- Audio output switching --------------------------------------------------
-- One-touch route the default sink to a specific output class. audio-output
-- resolves the sink at runtime via pactl port-type + description detection.
hl.bind("ALT + SHIFT + A", hl.dsp.exec_cmd("audio-output aux"))       -- analog / line-out
hl.bind("ALT + SHIFT + S", hl.dsp.exec_cmd("audio-output speaker"))   -- hdmi / monitor speakers
hl.bind("ALT + SHIFT + H", hl.dsp.exec_cmd("audio-output headset"))   -- wired or wireless headset
hl.bind("ALT + SHIFT + L", hl.dsp.exec_cmd("audio-output bluetooth")) -- any paired bluez sink
hl.bind("ALT + SHIFT + M", hl.dsp.exec_cmd("audio-output toggle-mute"))
