-- The Hyprland half against a stand-in `hl`: the overview's submap is entered
-- and left, also when a config reload has started the Lua afresh while
-- Hyprland was still in it. Run: lua tests/submap.test.lua   (tests/check.sh does)
local dir = (arg and arg[0] or ""):match("^(.*)/[^/]*$") or "."
local FILE = dir .. "/../hypr/mac-mission-control.lua"
local SUBMAP = "mac-mission-control"

local failed = 0
local function check(name, ok)
  print((ok and "ok    " or "FAIL  ") .. name)
  if not ok then failed = failed + 1 end
end

-- What Hyprland keeps across a reload: the current submap ("" is the default).
local current = ""
local dispatched

-- Any hl.* or hl.dsp.* not set below is a no-op that returns a no-op.
local function stub()
  return setmetatable({}, {
    __index = function(t, k) local v = stub(); rawset(t, k, v); return v end,
    __call = function() return nil end,
  })
end

-- A fresh Lua state, as Hyprland starts one on every config reload.
local function fresh(with_api)
  mac_mission_control, mac_mission_control_hooks, mac_mission_control_call = nil, nil, nil
  dispatched = {}
  hl = stub()
  hl.dsp.submap = function(name) return { submap = name } end
  hl.dsp.event = function(data) return { event = data } end
  hl.dispatch = function(d)
    if type(d) == "table" and d.submap then
      table.insert(dispatched, d.submap)
      current = (d.submap == "reset") and "" or d.submap
    end
  end
  for _, f in ipairs({ "get_windows", "get_monitors", "get_workspaces" }) do hl[f] = function() return {} end end
  hl.get_current_submap = with_api ~= false and function() return current end or false -- missing: calling it fails
  dofile(FILE)
end

local overview = { namespace = "mac-mission-control", monitor = { name = "DP-1" } }
local function open() mac_mission_control_call("layer_opened", overview) end
local function close() mac_mission_control_call("layer_closed", overview) end

current = ""
fresh()
check("load: no submap change", #dispatched == 0)
open()
check("open: enters the submap", current == SUBMAP)
close()
check("close: leaves the submap", current == "")

-- hyprctl reload with the overview open: Hyprland stays in the submap.
open()
fresh()
check("load after a reload while open: back to the default submap", current == "" and dispatched[1] == "reset")

-- The overview's layer closing after the new load leaves it too.
current = SUBMAP
fresh()
current = SUBMAP
close()
check("close after a reload: back to the default submap", current == "")

current = SUBMAP
fresh()
current = SUBMAP
mac_mission_control.reset()
check("reset() after a reload: back to the default submap", current == "")

-- Someone else's submap is left alone.
current = "resize"
fresh()
close()
mac_mission_control.reset()
check("another submap is left alone", current == "resize" and #dispatched == 0)

-- Loaded again into the same Lua (the shell restarted) with the overview open.
current = ""
fresh()
open()
dofile(FILE)
check("load into the same Lua while open: leaves the submap", current == "")

-- A Hyprland without hl.get_current_submap still loads and works.
current = ""
fresh(false)
open()
close()
check("without get_current_submap: enter and leave", current == "" and #dispatched == 2)

if failed > 0 then os.exit(1) end
