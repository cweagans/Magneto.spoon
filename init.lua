
-- Magneto: A semi-tiling window manager for macOS and Hammerspoon.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Magneto"
obj.version = "1.0"
obj.author = "Cameron Eagans <me@cweagans.net>"
obj.homepage = "https://github.com/cweagans/Magneto.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- Keychain.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log level for the messages coming from the Spoon.
obj.logger = hs.logger.new('Magneto')

--- Magneto.keybinds
--- Variable
--- Map of keybind parts to use to set keybindings for Magneto.
obj.config = {
    modifier = {"ctrl", "alt"},
    animationDuration = 0,
    dragZoneSize = 75,
    mouseThrowing = true,
    drawTargetSizeOnDrag = true,
}

--- Magneto.savedStates
--- Variable
--- Map of saved window states. Used for toggling between mouse-specified position and Magneto positions.
obj.savedStates = {}

--- Magneto.focusedWindowID
--- Variable
--- Used for determining if the focused window changed between the last drag event and now.
obj.focusedWindowID = nil

--- Magneto.draggedWindowPosition
--- Variable
--- Used for determining if a window gets dragged into a "throwable" zone.
obj.draggedWindowPosition = nil

--- Magneto.dragShouldResize
--- Variable
--- Used for determining if the current window should be resized on leftMouseUp
obj.dragShouldResize = false

--- Magneto.dragZone
--- Variable
--- Used for determining what zone the window should be resized to if appropriate.
obj.dragZone = nil

--- Magneto.canvas
--- Variable
--- Used for drawing window rectangles on the screen to indicate how a window will be resized.
obj.canvas = nil

--- Magneto:start()
--- Method
--- Start Magneto
---
--- Parameters:
---  * None
function obj:start()
    obj.logger.i("Magneto is running!")
    self:setKeybinds()

    if self.config.mouseThrowing then
        self:watchMouse()
    end
end

--- Magneto: drawWindowPositionSuggestion()
--- Method
--- Draw a rectangle on screen showing where a window might be moved.
function obj:drawWindowPositionSuggestion(position)
    win = getCurrentWindow()
    screen = win:screen()

    if not obj.canvas then
        obj.canvas = hs.canvas.new(screen:frame())
    end

    if position then
        suggestedRect = self:getNewWindowRect(position, screen:frame())
        obj.canvas[1] = {
            type = "rectangle",
            frame = suggestedRect,
            id = "suggestion",
            fillColor = {
                blue = 1,
                alpha = .25,
            }
        }
    end

    obj.canvas:show()
end

--- Magneto: clearWindowPositionSuggestion()
--- Method
--- Clear any displayed position suggestions.
function obj:clearWindowPositionSuggestion()
    if self.canvas then
        self.canvas:delete(self.config.animationDuration)
        self.canvas = nil
    end
end

--- Magneto: watchMouse()
--- Method
--- Watch mouse events to detect when a window is being dragged to a "throwable" place on the screen.
---
--- Parameters:
---  * None
function obj:watchMouse()
    -- This event handler is only responsible for determining if 
    mouseDragEventWatcher = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDragged }, function(event)
        currentWindow = getCurrentWindow()
        if not currentWindow then
            return
        end

        -- If the focused window changed, just record the position so the next event
        -- can check for a different position.
        if currentWindow:id() ~= self.focusedWindowID then
            obj.logger.i("Changed window focus to " .. currentWindow:title())
            self.focusedWindowID = currentWindow:id()
            self.draggedWindowPosition = currentWindow:frame()
            return
        end

        currentWindowFrame = currentWindow:frame()
        currentScreenFrame = currentWindow:screen():frame()

        -- If the current window is being moved, then we know the mouse drag event
        -- is actually dragging the current window.
        if not self.draggedWindowPosition or not rectsAreEqual(currentWindowFrame, self.draggedWindowPosition) then
            self.draggedWindowPosition = currentWindowFrame
            mousePos = hs.geometry.point(hs.mouse.getAbsolutePosition())

            for name, rect in pairs(self:getThrowableZones(currentScreenFrame)) do
                if mousePos:inside(rect) then
                    self.dragShouldResize = true
                    self.dragZone = name
                    if self.config.drawTargetSizeOnDrag then
                        self:drawWindowPositionSuggestion(name, currentScreenFrame)
                    end
                    break
                else
                    self.dragShouldResize = false
                    self.dragZone = nil
                    if self.config.drawTargetSizeOnDrag then
                        self:clearWindowPositionSuggestion()
                    end
                end
            end

        end
    end):start()

    -- Once the mouse is released, if the drag event handler has determined that we need to
    -- resize the window, do so.
    leftMouseEventWatcher = hs.eventtap.new({ hs.eventtap.event.types.leftMouseUp }, function(event)
        if self.dragShouldResize then
            if self.dragZone == "fullscreen" then
                self:toggleFullscreen()
            else
                self:togglePosition(self.dragZone)
            end

            window = getCurrentWindow()
            self.savedStates[window:id()] = nil

            -- Clear the drag state after window resize.
            self.dragShouldResize = false
            self.dragZone = nil
            if self.config.drawTargetSizeOnDrag then
                self:clearWindowPositionSuggestion()
            end
        end
    end):start()

end


--- Magneto:setKeybinds()
--- Method
--- Set Magneto keybindings
---
--- Parameters:
---  * None
function obj:setKeybinds()
    -- Fullscreen toggle: modifier + return
    hs.hotkey.bind(self.config.modifier, "return", function()
        self:toggleFullscreen()
    end)

    -- Center: modifier + space
    hs.hotkey.bind(self.config.modifier, "space", function()
        currentWindow = getCurrentWindow()
        if not currentWindow then
            obj.logger.i("Cannot manipulate current window")
            return
        end
        currentWindow:setFrame(getFallbackPosition(), self.config.animationDuration)
    end)

    -- Corner toggles: modifier + u/i/j/k
    hs.hotkey.bind(self.config.modifier, "u", function()
        self:togglePosition("northwest")
    end)
    hs.hotkey.bind(self.config.modifier, "i", function()
        self:togglePosition("northeast")
    end)
    hs.hotkey.bind(self.config.modifier, "j", function()
        self:togglePosition("southwest")
    end)
    hs.hotkey.bind(self.config.modifier, "k", function()
        self:togglePosition("southeast")
    end)

    -- Half toggles: modifier + arrows
    hs.hotkey.bind(self.config.modifier, "up", function()
        self:togglePosition("north")
    end)
    hs.hotkey.bind(self.config.modifier, "right", function()
        self:togglePosition("east")
    end)
    hs.hotkey.bind(self.config.modifier, "down", function()
        self:togglePosition("south")
    end)
    hs.hotkey.bind(self.config.modifier, "left", function()
        self:togglePosition("west")
    end)

    -- Third toggles: modifier + d/f/g
    hs.hotkey.bind(self.config.modifier, "d", function()
        self:togglePosition("leftthird")
    end)
    hs.hotkey.bind(self.config.modifier, "f", function()
        self:togglePosition("middlethird")
    end)
    hs.hotkey.bind(self.config.modifier, "g", function()
        self:togglePosition("rightthird")
    end)

    -- Two-third: modifier + e/r/t
    hs.hotkey.bind(self.config.modifier, "e", function()
        self:togglePosition("lefttwothird")
    end)
    hs.hotkey.bind(self.config.modifier, "r", function()
        self:togglePosition("middletwothird")
    end)
    hs.hotkey.bind(self.config.modifier, "t", function()
        self:togglePosition("righttwothird")
    end)
end

--- Magneto:toggleFullscreen()
--- Method
--- Make current window fullscreen or revert to previously saved coordinates if available.
--- Will use a default position if previous coordinates are not available.
---
--- Parameters:
---  * None
function obj:toggleFullscreen()
    currentWindow = getCurrentWindow()
    if not currentWindow then
        obj.logger.i("Cannot manipulate current window")
        return
    end

    windowID = currentWindow:id()

    if windowIsFullscreenish(currentWindow) then
        if not self.savedStates[windowID] then
            currentWindow:setFrame(getFallbackPosition(), self.config.animationDuration)
        else
            currentWindow:setFrame(self.savedStates[windowID], self.config.animationDuration)
        end
    else
        self.savedStates[windowID] = currentWindow:frame()
        currentWindow:maximize(self.config.animationDuration)
    end
end

function obj:getNewWindowRect(position, screenFrame)
    if not position then
        obj.logger.i("Position not specified")
        return
    end

    currentWindowScreen = screenFrame

    newRect = {}
    newRect.w = currentWindowScreen.w / 2
    newRect.h = currentWindowScreen.h / 2

    -- Corners
    if position == "northeast" then
        newRect.x = newRect.w
        newRect.y = 0
    elseif position == "southeast" then
        newRect.x = newRect.w
        newRect.y = newRect.h
    elseif position == "southwest" then
        newRect.x = 0
        newRect.y = newRect.h
    elseif position == "northwest" then
        newRect.x = 0
        newRect.y = 0

    -- Halves
    elseif position == "east" then
        newRect.w = currentWindowScreen.w / 2
        newRect.h = currentWindowScreen.h
        newRect.x = newRect.w
        newRect.y = 0
    elseif position == "south" or position == "south2" then
        newRect.w = currentWindowScreen.w
        newRect.h = currentWindowScreen.h / 2
        newRect.x = 0
        newRect.y = newRect.h
    elseif position == "west" then
        newRect.w = currentWindowScreen.w / 2
        newRect.h = currentWindowScreen.h
        newRect.x = 0
        newRect.y = 0
    elseif position == "north" or position == "north2" then
        newRect.w = currentWindowScreen.w
        newRect.h = currentWindowScreen.h / 2
        newRect.x = 0
        newRect.y = 0

    -- Thirds
    elseif position == "leftthird" then
        newRect.w = currentWindowScreen.w / 3
        newRect.h = currentWindowScreen.h
        newRect.x = 0
        newRect.y = 0
    elseif position == "middlethird" then
        newRect.w = currentWindowScreen.w / 3
        newRect.h = currentWindowScreen.h
        newRect.x = newRect.w
        newRect.y = 0
    elseif position == "rightthird" then
        newRect.w = currentWindowScreen.w / 3
        newRect.h = currentWindowScreen.h
        newRect.x = newRect.w * 2
        newRect.y = 0

    -- Two-third
    elseif position == "lefttwothird" then
        newRect.w = (currentWindowScreen.w / 3) * 2
        newRect.h = currentWindowScreen.h
        newRect.x = 0
        newRect.y = 0
    elseif position == "middletwothird" then
        newRect.w = (currentWindowScreen.w / 3) * 2
        newRect.h = currentWindowScreen.h
        newRect.x = (currentWindowScreen.w / 6)
        newRect.y = 0
    elseif position == "righttwothird" then
        newRect.w = (currentWindowScreen.w / 3) * 2
        newRect.h = currentWindowScreen.h
        newRect.x = (currentWindowScreen.w / 3)
        newRect.y = 0

    end

    -- Account for macOS toolbar.
    -- TODO: On my setup, I have the toolbar visible at all times, but this is not a valid assumption for everyone.
    -- See https://github.com/Hammerspoon/hammerspoon/issues/2270
    if newRect.y == 0 then
        newRect.y = 23
    end

    return newRect
end

--- Magneto:toggleCorner()
--- Method
--- Toggle window position to specified corner or back to previous state.
--- Will use a default position if previous coordinates are not available.
---
--- Parameters:
---  * String: which corner of the current screen to use
function obj:togglePosition(position)
    if not position then
        obj.logger.i("Position not specified")
        return
    end

    currentWindow = getCurrentWindow()
    if not currentWindow then
        obj.logger.i("Cannot manipulate current window")
        return
    end

    windowID = currentWindow:id()

    currentWindowScreen = currentWindow:screen():frame()

    newRect = self:getNewWindowRect(position, currentWindowScreen)

    currentWindowFrame = currentWindow:frame()

    if (rectsAreEqual(currentWindowFrame, newRect)) then
        if not self.savedStates[windowID] then
            currentWindow:setFrame(getFallbackPosition(), self.config.animationDuration)
        else
            currentWindow:setFrame(self.savedStates[windowID], self.config.animationDuration)
        end
    else
        self.savedStates[windowID] = currentWindow:frame()
        currentWindow:setFrame(newRect, self.config.animationDuration)
    end
end

function getCurrentWindow()
    local currentWindow = hs.window.focusedWindow()

    -- If it's not a standard window, Magneto shouldn't mess with it.
    if not currentWindow:isStandard() then
        return nil
    end

    return currentWindow
end

function windowIsFullscreenish(win)
    winframe = win:frame()
    winscreenframe = win:screen():frame()

    widthSimilarity = winscreenframe.w - winframe.w
    heightSimilarity = winscreenframe.h - winframe.h

    if heightSimilarity <= 50 and widthSimilarity <= 50 then
        return true
    end

    return false
end

function getFallbackPosition()
    currentWindow = hs.window.focusedWindow()
    currentScreen = currentWindow:screen():frame()

    newRect = {}
    newRect.h = (currentScreen.h / 3) * 2
    newRect.w = (currentScreen.w / 3) * 2
    newRect.y = (currentScreen.h / 6)
    newRect.x = (currentScreen.w / 6)

    return newRect
end

function rectsAreEqual(rect1, rect2)
    if not rect1 or not rect2 then
        return false
    end

    -- print("rect1")
    -- print(rect1.x)
    -- print(rect1.y)
    -- print(rect1.w)
    -- print(rect1.h)

    -- print("rect2")
    -- print(rect2.x)
    -- print(rect2.y)
    -- print(rect2.w)
    -- print(rect2.h)

    sameX = (math.floor(rect1.x) == math.floor(rect2.x))
    sameY = (math.floor(rect1.y) == math.floor(rect2.y))
    sameH = (math.floor(rect1.h) == math.floor(rect2.h))
    sameW = (math.floor(rect1.w) == math.floor(rect2.w))

    return (sameX and sameY and sameH and sameW)
end

function obj:getThrowableZones(screenFrame)
    zones = {}

    screenWidth = screenFrame.w
    screenHeight = screenFrame.h

    zoneSize = self.config.dragZoneSize

    -- Corners
    zones["northwest"] = hs.geometry.rect(0, 0, zoneSize, zoneSize)
    zones["northeast"] = hs.geometry.rect(screenWidth - zoneSize, 0, zoneSize, zoneSize)
    zones["southwest"] = hs.geometry.rect(0, screenHeight - zoneSize, zoneSize, zoneSize)
    zones["southeast"] = hs.geometry.rect(screenWidth - zoneSize, screenHeight - zoneSize, zoneSize, zoneSize)

    -- Edges
    zones["north"] = hs.geometry.rect(0, (screenHeight / 4) - zoneSize, zoneSize, zoneSize * 2)
    zones["north2"] = hs.geometry.rect((screenWidth - zoneSize), (screenHeight / 4) - zoneSize, zoneSize, zoneSize * 2)
    zones["south"] = hs.geometry.rect(0, ((screenHeight / 4) * 3) - zoneSize, zoneSize, zoneSize * 2)
    zones["south2"] = hs.geometry.rect((screenWidth - zoneSize), ((screenHeight / 4) * 3) - zoneSize, zoneSize, zoneSize * 2)
    zones["east"] = hs.geometry.rect((screenWidth - zoneSize), (screenHeight / 2) - zoneSize, zoneSize, zoneSize * 2)
    zones["west"] = hs.geometry.rect(0, (screenHeight / 2) - zoneSize, zoneSize, zoneSize * 2)

    -- One thirds
    zones["leftthird"] = hs.geometry.rect((screenWidth / 4) - (zoneSize * 2), (screenHeight - zoneSize), zoneSize * 4, zoneSize)
    zones["middlethird"] = hs.geometry.rect((screenWidth / 2) - (zoneSize * 2), (screenHeight - zoneSize), zoneSize * 4, zoneSize)
    zones["rightthird"] = hs.geometry.rect(((screenWidth / 4) * 3) - (zoneSize * 2), (screenHeight - zoneSize), zoneSize * 4, zoneSize)

    -- Two thirds
    zones["lefttwothird"] = hs.geometry.rect((screenWidth / 4) - (zoneSize * 2), 0, zoneSize * 4, zoneSize)
    zones["middletwothird"] = hs.geometry.rect((screenWidth / 2) - (zoneSize * 2), zoneSize, zoneSize * 4, zoneSize)
    zones["righttwothird"] = hs.geometry.rect(((screenWidth / 4) * 3) - (zoneSize * 2), 0, zoneSize * 4, zoneSize)

    -- Fullscreen
    zones["fullscreen"] = hs.geometry.rect((screenWidth / 2) - (zoneSize * 2), 0, zoneSize * 4, zoneSize)

    return zones
end

return obj
