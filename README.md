# Magneto

A window manager for [Hammerspoon](https://www.hammerspoon.org/) that should more or less replace apps like [Magnet](https://magnet.crowdcafe.com/).

## Features

* Configurable-ish shortcuts for moving windows to common locations
    * Modifier is configurable. Defaults to `ctrl + alt`
    * Shortcuts:
        * `modifier + u/i/j/k`: Move current window to northwest/northeast/southwest/southeast corner of current screen.
        * `modifier + arrows`: Move current window to a half of the screen
        * `modifier + d/f/g`: Move current window to the left, middle, or right third of the current screen
        * `modifier + e/r/t`: Move current window to the left, middle, or right two third of the current screen
* "Throw" a window to the side of the screen with a mouse to resize and align it with a graphical indication of what will happen

## Wishlist

* "Saved" layouts

## Installation

* Clone this repo into `~/.hammerspoon/Spoons` (so that `init.lua` exists at `~/.hammerspoon/Spoons/Magneto.spoon/init.lua`)
* Add the following to `~/.hammerspoon/init.lua`:

```lua
-- Load, configure, and start Magneto.
m = hs.loadSpoon("Magneto")
m:start()
```

If you want to change any of the settings, you can do that in your init.lua like so:

```lua
-- Load, configure, and start Magneto.
m = hs.loadSpoon("Magneto")
m.config["animationDuration"] = 1
m.config["mouseThrowing"] = false
m:start()
```

## Configuration

Magneto exposes some configuration options that you can use to change how the plugin behaves.

* `config["modifier"]` -- (**Default**: `{"ctrl", "alt"}`). The modifier keys that you'll have to hold down in addition to the shortcuts listed above to move windows.
* `config["animationDuration"]` -- (**Default**: 0). The number of seconds that window movement animations will take to complete. Decimals are fine.
* `config["dragZoneSize"]` -- (**Default**: 75). The size in pixels that a one-unit drag zone will take up. Probably don't change this unless you know what you're doing. See `obj:getThrowableZones()` for how this gets used.
* `config["mouseThrowing"]` -- (**Default**: true). Whether or not mouse support is enabled. When enabled, you can drag a window to a drop zone on an edge of the screen to resize it (in addition to using the keyboard shortcuts).
* `config["drawTargetSizeOnDrag"]` -- (**Default**: true). If mouse support is enabled, this will cause the plugin to draw a screen overlay showing where a window will end up when you let go of the mouse button. If `mouseThrowing` is disabled, this setting has no effect.
