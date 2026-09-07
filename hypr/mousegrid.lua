-- Keyboard pointer: 6x4 lattice on the focused window, no overlay.
-- SUPER+A enters; arrows jump cells; SUPER+arrows nudge; Enter clicks and leaves.
-- Space holds the left button (release = release; tap = click).
-- SUPER+Space also holds, so fine aim and drag can overlap.

local COLS = 6
local ROWS = 4
local FINE = 12
local CLICK = (os.getenv("HOME") or "") .. "/.local/bin/mousegrid-click"
local FIFO = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/mousegrid-click.fifo"

local state = {
  bx = 0,
  by = 0,
  bw = 0,
  bh = 0,
  cw = 0,
  ch = 0,
  x = 0,
  y = 0,
}

local saved_hide = true
local cursor_hijacked = false
local holding = false

local function clamp(value, lo, hi)
  if value < lo then
    return lo
  end
  if value > hi then
    return hi
  end
  return value
end

local function target_box()
  local win = hl.get_active_window()
  if win and win.mapped and not win.hidden and win.at and win.size then
    return win.at.x, win.at.y, win.size.x, win.size.y
  end
  local mon = hl.get_active_monitor() or hl.get_monitor_at_cursor()
  if mon then
    return mon.x, mon.y, mon.width, mon.height
  end
  return 0, 0, 1920, 1080
end

local function pointer(cmd)
  local fifo = io.open(FIFO, "w")
  if fifo then
    fifo:write(cmd .. "\n")
    fifo:flush()
    fifo:close()
    return
  end
  hl.exec_cmd(o.shell_quote(CLICK) .. " " .. cmd)
end

local function warp(x, y)
  local nx = math.floor(x + 0.5)
  local ny = math.floor(y + 0.5)
  local dx = nx - math.floor(state.x + 0.5)
  local dy = ny - math.floor(state.y + 0.5)
  state.x = x
  state.y = y
  if holding then
    if dx ~= 0 or dy ~= 0 then
      pointer(string.format("move %d %d", dx, dy))
    end
    return
  end
  hl.dispatch(hl.dsp.cursor.move({ x = nx, y = ny }))
end

local function show_cursor()
  if cursor_hijacked then
    return
  end
  local ok, value = pcall(hl.get_config, "cursor.hide_on_key_press")
  if ok then
    saved_hide = value and true or false
  else
    saved_hide = true
  end
  hl.config({ cursor = { hide_on_key_press = false } })
  cursor_hijacked = true
end

local function restore_cursor()
  if not cursor_hijacked then
    return
  end
  hl.config({ cursor = { hide_on_key_press = saved_hide } })
  cursor_hijacked = false
end

local function enter()
  local bx, by, bw, bh = target_box()
  if bw < 8 or bh < 8 then
    return
  end
  holding = false
  hl.exec_cmd(o.shell_quote(CLICK) .. " --daemon")
  state.bx, state.by, state.bw, state.bh = bx, by, bw, bh
  state.cw = bw / COLS
  state.ch = bh / ROWS
  local cx = bx + bw / 2
  local cy = by + bh / 2
  local col = clamp(math.floor((cx - bx) / state.cw), 0, COLS - 1)
  local row = clamp(math.floor((cy - by) / state.ch), 0, ROWS - 1)
  show_cursor()
  warp(bx + (col + 0.5) * state.cw, by + (row + 0.5) * state.ch)
  hl.dispatch(hl.dsp.submap("mousegrid"))
end

local function release_left()
  if not holding then
    return
  end
  holding = false
  pointer("up")
end

local function press_left()
  if holding then
    return
  end
  holding = true
  pointer("down")
end

local function leave()
  release_left()
  restore_cursor()
  hl.dispatch(hl.dsp.submap("reset"))
end

local function step_coarse(dx, dy)
  if state.cw <= 0 or state.ch <= 0 then
    return
  end
  local minx = state.bx + state.cw / 2
  local maxx = state.bx + state.bw - state.cw / 2
  local miny = state.by + state.ch / 2
  local maxy = state.by + state.bh - state.ch / 2
  warp(
    clamp(state.x + dx * state.cw, minx, maxx),
    clamp(state.y + dy * state.ch, miny, maxy)
  )
end

local function step_fine(dx, dy)
  if state.bw <= 0 or state.bh <= 0 then
    return
  end
  local minx = state.bx + 2
  local maxx = state.bx + state.bw - 2
  local miny = state.by + 2
  local maxy = state.by + state.bh - 2
  warp(
    clamp(state.x + dx * FINE, minx, maxx),
    clamp(state.y + dy * FINE, miny, maxy)
  )
end

local function click(button, exit_after)
  if holding and button == "left" then
    if exit_after then
      leave()
    end
    return
  end
  pointer(button)
  if exit_after then
    leave()
  end
end

hl.on("hyprland.start", function()
  hl.exec_cmd(o.shell_quote(CLICK) .. " --daemon")
end)

hl.on("keybinds.submap", function(name)
  if name ~= "mousegrid" then
    release_left()
    restore_cursor()
  end
end)

o.bind("SUPER + A", "Mousegrid", enter)

hl.define_submap("mousegrid", function()
  o.bind("LEFT", "Mousegrid cell left", function()
    step_coarse(-1, 0)
  end, { repeating = true })
  o.bind("RIGHT", "Mousegrid cell right", function()
    step_coarse(1, 0)
  end, { repeating = true })
  o.bind("UP", "Mousegrid cell up", function()
    step_coarse(0, -1)
  end, { repeating = true })
  o.bind("DOWN", "Mousegrid cell down", function()
    step_coarse(0, 1)
  end, { repeating = true })

  o.bind("SUPER + LEFT", "Mousegrid fine left", function()
    step_fine(-1, 0)
  end, { repeating = true })
  o.bind("SUPER + RIGHT", "Mousegrid fine right", function()
    step_fine(1, 0)
  end, { repeating = true })
  o.bind("SUPER + UP", "Mousegrid fine up", function()
    step_fine(0, -1)
  end, { repeating = true })
  o.bind("SUPER + DOWN", "Mousegrid fine down", function()
    step_fine(0, 1)
  end, { repeating = true })

  o.bind("RETURN", "Mousegrid click and leave", function()
    click("left", true)
  end)
  -- Fine aim holds Super, so Space arrives as SUPER+SPACE.
  o.bind("SPACE", "Mousegrid hold left", press_left, { ignore_mods = true })
  o.bind("SPACE", "Mousegrid release left", release_left, { release = true, ignore_mods = true })
  o.bind("SUPER + SPACE", "Mousegrid hold left", press_left)
  o.bind("SUPER + SPACE", "Mousegrid release left", release_left, { release = true })
  o.bind("SHIFT + RETURN", "Mousegrid right-click and leave", function()
    click("right", true)
  end)
  o.bind("ESCAPE", "Leave mousegrid", leave)
  o.bind("SUPER + A", "Leave mousegrid", leave)
end)
