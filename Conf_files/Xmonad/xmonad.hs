import XMonad

import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks

import qualified XMonad.StackSet as W

import System.IO
import System.Exit

import XMonad.Util.Run
import XMonad.Util.EZConfig
import XMonad.Util.SpawnOnce

import XMonad.Layout.Renamed
import XMonad.Layout.Fullscreen
import XMonad.Layout.Magnifier
import XMonad.Layout.Spiral
import XMonad.Layout.Grid
import XMonad.Layout.Spacing
import XMonad.Layout.ResizableTile

import qualified Data.Map        as M
import Colors

myTerminal      = "kitty"
myBorderWidth   = 1 
myModMask       = mod4Mask
myNormalBorderColor  = color2
myFocusedBorderColor = color1

main = do
  abcd <- spawnPipe "xmobar"
  xmonad $ docks $ myConfig abcd

myConfig efgh = defaultConfig
  { terminal           = myTerminal
  , borderWidth        = myBorderWidth
  , modMask            = myModMask
  , workspaces         = myWorkspaces
  , normalBorderColor  = myNormalBorderColor
  , focusedBorderColor = myFocusedBorderColor
--  , keys               = myKeys
  , layoutHook         = myLayout
  , manageHook         = myManage
  , handleEventHook    = myEvent
  , logHook            = myLog efgh
  , startupHook        = myStartup
  }
  `additionalKeysP` myKeys

myEvent = mempty

myLog proc = dynamicLogWithPP $ xmobarPP
  { ppOutput  = hPutStrLn proc
  , ppCurrent = xmobarColor "#98be65" "" . wrap "[" "]" -- Current workspace in xmobar
  , ppVisible = xmobarColor "#98be65" ""                -- Visible but not current workspace
  , ppHidden = xmobarColor "#82AAFF" ""                 -- Hidden workspaces in xmobar
  , ppHiddenNoWindows = xmobarColor "#c792ea" ""        -- Hidden workspaces (no windows)
  , ppUrgent = xmobarColor "#C45500" "" . wrap "!" "!"  -- Urgent workspace
  , ppExtras  = [windowCount]                           -- n windows current workspace
  , ppSep =  "<fc=#98be65> | </fc>"                     -- Separators
  , ppOrder  = \(ws:l:t:ex) -> [ws,l]++ex++[t]
  }


--tall    = Tall 1 (4/100) (1/2)
grid    = renamed [Replace "Grid"] $ mySpacing 10 $ Grid 
spirale = renamed [Replace "Spir"] $ mySpacing 10 $ spiral (1/2)
mirror  = renamed [Replace "Mirror"] $ mySpacing 10
        $ Mirror (ResizableTall 1 (3/100) (1/2) [])
magnify = renamed [Replace "Magn"] $ mySpacing 10
        $ magnifier (Tall 1 (3/100) (1/2))
myTall  = renamed [Replace "Tall"] $ mySpacing 10
        $ ResizableTall 1 (3/100) (1/2) []

mySpacing g = spacingRaw True -- Only for >1 window
  (Border g g g g) True       -- Size of screen edge gaps and Enable
  (Border g g g g) True       -- Size of window gaps and Enable

myLayout = avoidStruts $ myLayoutSet
  where
    myLayoutSet = myTall ||| magnify ||| mirror ||| Full ||| spirale ||| grid


myKeys = 
-- Default     = Util.EZConfig = Normal
-- mod4Mask    =       M       = Super/Windows (xorg M4)
-- mod1Mask    =       M1      = Alt (xorg M1)
-- shiftMask   =       S       = Shift
-- controlMask =       C       = Ctrl
-- xK_space    =    <Space>    = Space
-- formatting example: 
-- ((modm, xK_w), kill) = ("M-w", kill)
  [ ("M-S-r", spawn "xmonad --recompile; xmonad --restart") -- Recompiles xmonad
  , ("M-S-q", io exitSuccess) 
  , ("M-<Return>", spawn myTerminal)
  , ("M-w", kill) 
-- Windows management
  , ("M-t", withFocused $ windows . W.sink)
  , ("M-n", sendMessage NextLayout)
  , ("M-<Tab>", windows W.focusDown)
  , ("M-<Down>", windows W.focusDown)
  , ("M-<Right>", windows W.focusDown)
  , ("M-<Left>", windows W.focusUp)
  , ("M-<Up>", windows W.focusUp)
  , ("M-S-<Down>", windows W.swapDown)
  , ("M-S-<Up>", windows W.swapUp)
  , ("M-S-<Left>", windows W.swapUp)
  , ("M-S-<Right>", windows W.swapDown)
  , ("M-C-<Down>", sendMessage MirrorShrink)
  , ("M-C-<Up>", sendMessage MirrorExpand)
  , ("M-C-<Left>", sendMessage Shrink)
  , ("M-C-<Right>", sendMessage Expand)
  , ("M-S-C-<Up>", decWindowSpacing 4)           -- Decrease window spacing
  , ("M-S-C-<Down>", incWindowSpacing 4)           -- Increase window spacing
  , ("M-S-C-<Left>", decScreenSpacing 4)         -- Decrease screen spacing
  , ("M-S-C-<Right>", incScreenSpacing 4)         -- Increase screen spacing
-- XF86 keys
  , ("<XF86MonBrightnessUp>", spawn "light -A 1")
  , ("<XF86MonBrightnessDown>", spawn "light -U 1")
  , ("<XF86ScreenSaver>", spawn "light -S 0")
  , ("<XF86AudioRaiseVolume>", spawn "sh -c \"pactl set-sink-mute 0 false ; pactl set-sink-volume 0 +1%\"")
  , ("<XF86AudioLowerVolume>", spawn "sh -c \"pactl set-sink-mute 0 false ; pactl set-sink-volume 0 -1%\"")
  , ("<XF86AudioMute>", spawn "pactl set-sink-mute 0 toggle")
  , ("<XF86AudioMicMute>", spawn "pactl set-source-mute 1 toggle")
  , ("<XF86TouchpadToggle>", spawn "~/.config/toggle-touchpad.sh") --not work
  , ("<XF86Sleep>", spawn "dm-tool lock") 
-- Programs
  , ("M-<Space>", spawn "rofi -show combi")
  , ("M-e", spawn "pcmanfm")
  ,("M-f", sendMessage ToggleStruts)
  ]

windowCount  = gets $ Just . show . length . W.integrate' . W.stack . W.workspace . W.current . windowset
xmobarEscape = concatMap doubleLts
  where
    doubleLts '<' = "<<"
    doubleLts x   = [x]

myWorkspaces = clickable . (map xmobarEscape)
  $ [" code ", " web ", " file ", " doc ", " extra "]
  where
  clickable l = [ "<action=xdotool key super+" ++ show (n) ++ ">" ++ ws ++ "</action>" |
    (i,ws) <- zip [1..5] l,
    let n = i ]

myStartup = do
  spawnOnce "setxkbmap -layout it &"
  spawnOnce "numlockx &"
  spawnOnce "xset s 60 120"
  spawnOnce "xss-lock -n \"notify-send -u critical -t 5000 -- 'LOCKING in 2 min'\" -- slock"
  spawnOnce "picom &"
  spawnOnce "wal -i ~/.wallpapers/ -o ~/.config/dunst/dunst-color.sh"
  spawnOnce "~/.config/low-battery.sh"

myManage = composeAll
  [ className =? "firefox" --> doShift "web"
  , className =? "Pcmanfm" --> doShift "file"
  ]

