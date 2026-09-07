-- Keyboard pointer: lattice on the focused window, no drawn overlay.
-- SUPER+A enters; arrows jump cells; another arrow on the last cell scrolls.
-- Space holds the left button (release = release; tap = click).
-- SUPER+Space also holds, so fine aim and drag can overlap.
-- Grid sizes live in ~/.config/omarchy/mousegrid.json (picker overlay).

local DEFAULT_COLS = 6
local DEFAULT_ROWS = 4
local DEFAULT_FINE = 12
local CONFIG = (os.getenv("HOME") or "") .. "/.config/omarchy/mousegrid.json"
local CLICK = (os.getenv("HOME") or "") .. "/.local/bin/mousegrid-click"
local FIFO = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/mousegrid-click.fifo"

local state = {
  bx = 0,
  by = 0,
  bw = 0,
  bh = 0,
  cw = 0,
  ch = 0,
  fine = 12,
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

local function config_number(raw, key, default, lo, hi)
  local matched = raw:match('"' .. key .. '"%s*:%s*(%d+)')
  return clamp(tonumber(matched) or default, lo, hi)
end

local function read_grid()
  local file = io.open(CONFIG, "r")
  if not file then
    return DEFAULT_COLS, DEFAULT_ROWS, DEFAULT_FINE
  end
  local raw = file:read("*a") or ""
  file:close()
  return config_number(raw, "cols", DEFAULT_COLS, 2, 16),
    config_number(raw, "rows", DEFAULT_ROWS, 2, 12),
    config_number(raw, "fine", DEFAULT_FINE, 4, 64)
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
  local cols, rows, fine = read_grid()
  state.bx, state.by, state.bw, state.bh = bx, by, bw, bh
  state.cw = bw / cols
  state.ch = bh / rows
  state.fine = fine
  local cx = bx + bw / 2
  local cy = by + bh / 2
  local col = clamp(math.floor((cx - bx) / state.cw), 0, cols - 1)
  local row = clamp(math.floor((cy - by) / state.ch), 0, rows - 1)
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

local function scroll(dx, dy)
  pointer(string.format("scroll %d %d", dx, dy))
end

local function step_or_scroll(nx, ny, dx, dy)
  local px = math.floor(nx + 0.5)
  local py = math.floor(ny + 0.5)
  local cx = math.floor(state.x + 0.5)
  local cy = math.floor(state.y + 0.5)
  if px == cx and py == cy then
    if not holding then
      scroll(dx, dy)
    end
    return
  end
  warp(nx, ny)
end

local function step_coarse(dx, dy)
  if state.cw <= 0 or state.ch <= 0 then
    return
  end
  local minx = state.bx + state.cw / 2
  local maxx = state.bx + state.bw - state.cw / 2
  local miny = state.by + state.ch / 2
  local maxy = state.by + state.bh - state.ch / 2
  step_or_scroll(
    clamp(state.x + dx * state.cw, minx, maxx),
    clamp(state.y + dy * state.ch, miny, maxy),
    dx,
    dy
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
  local step = state.fine or DEFAULT_FINE
  step_or_scroll(
    clamp(state.x + dx * step, minx, maxx),
    clamp(state.y + dy * step, miny, maxy),
    dx,
    dy
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

-- Submap binds go through hl.bind. o.bind dropped unmodified LEFT/RETURN
-- here after reload, so arrows entered the mode and then did nothing.
local function map(keys, description, fn, opts)
  opts = opts or {}
  opts.description = description
  hl.bind(keys, fn, opts)
end

hl.define_submap("mousegrid", function()
  map("LEFT", "Mousegrid cell left", function()
    step_coarse(-1, 0)
  end, { repeating = true })
  map("RIGHT", "Mousegrid cell right", function()
    step_coarse(1, 0)
  end, { repeating = true })
  map("UP", "Mousegrid cell up", function()
    step_coarse(0, -1)
  end, { repeating = true })
  map("DOWN", "Mousegrid cell down", function()
    step_coarse(0, 1)
  end, { repeating = true })

  map("SUPER + LEFT", "Mousegrid fine left", function()
    step_fine(-1, 0)
  end, { repeating = true })
  map("SUPER + RIGHT", "Mousegrid fine right", function()
    step_fine(1, 0)
  end, { repeating = true })
  map("SUPER + UP", "Mousegrid fine up", function()
    step_fine(0, -1)
  end, { repeating = true })
  map("SUPER + DOWN", "Mousegrid fine down", function()
    step_fine(0, 1)
  end, { repeating = true })

  map("RETURN", "Mousegrid click and leave", function()
    click("left", true)
  end)
  -- Fine aim holds Super, so Space arrives as SUPER+SPACE.
  map("SPACE", "Mousegrid hold left", press_left, { ignore_mods = true })
  map("SPACE", "Mousegrid release left", release_left, { release = true, ignore_mods = true })
  map("SUPER + SPACE", "Mousegrid hold left", press_left)
  map("SUPER + SPACE", "Mousegrid release left", release_left, { release = true })
  map("SHIFT + RETURN", "Mousegrid right-click and leave", function()
    click("right", true)
  end)
  map("ESCAPE", "Leave mousegrid", leave)
  map("SUPER + A", "Leave mousegrid", leave)

  -- Screen/workspace combos leave the mode, then run the Omarchy action.
  -- Super+arrows stay as fine aim and are not included.
  local function escape_then(dispatcher)
    return function()
      leave()
      hl.dispatch(dispatcher)
    end
  end

  for workspace = 1, 10 do
    local number_key = "code:" .. tostring(workspace + 9)
    map("SUPER + " .. number_key, "Leave mousegrid, workspace " .. workspace, escape_then(hl.dsp.focus({ workspace = tostring(workspace) })))
    map("SUPER + SHIFT + " .. number_key, "Leave mousegrid, move to workspace " .. workspace, escape_then(hl.dsp.window.move({ workspace = tostring(workspace) })))
    map("SUPER + SHIFT + ALT + " .. number_key, "Leave mousegrid, send to workspace " .. workspace, escape_then(hl.dsp.window.move({ workspace = tostring(workspace), follow = false })))
  end

  local numpad = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
  for workspace, code in ipairs(numpad) do
    local key = "code:" .. tostring(code)
    map("SUPER + " .. key, "Leave mousegrid, workspace " .. workspace, escape_then(hl.dsp.focus({ workspace = tostring(workspace) })))
    map("SUPER + SHIFT + " .. key, "Leave mousegrid, move to workspace " .. workspace, escape_then(hl.dsp.window.move({ workspace = tostring(workspace) })))
    map("SUPER + SHIFT + ALT + " .. key, "Leave mousegrid, send to workspace " .. workspace, escape_then(hl.dsp.window.move({ workspace = tostring(workspace), follow = false })))
  end

  map("SUPER + TAB", "Leave mousegrid, next workspace", escape_then(hl.dsp.focus({ workspace = "e+1" })))
  map("SUPER + SHIFT + TAB", "Leave mousegrid, previous workspace", escape_then(hl.dsp.focus({ workspace = "e-1" })))
  map("SUPER + CTRL + TAB", "Leave mousegrid, former workspace", escape_then(hl.dsp.focus({ workspace = "previous" })))
  map("CTRL + ALT + TAB", "Leave mousegrid, next monitor", escape_then(hl.dsp.focus({ monitor = "+1" })))
  map("CTRL + ALT + SHIFT + TAB", "Leave mousegrid, previous monitor", escape_then(hl.dsp.focus({ monitor = "-1" })))
  map("SUPER + S", "Leave mousegrid, scratchpad", escape_then(hl.dsp.workspace.toggle_special("scratchpad")))
  map("SUPER + ALT + S", "Leave mousegrid, send to scratchpad", escape_then(hl.dsp.window.move({ workspace = "special:scratchpad", follow = false })))
  map("SUPER + SHIFT + ALT + LEFT", "Leave mousegrid, workspace to left monitor", escape_then(hl.dsp.workspace.move({ monitor = "l" })))
  map("SUPER + SHIFT + ALT + RIGHT", "Leave mousegrid, workspace to right monitor", escape_then(hl.dsp.workspace.move({ monitor = "r" })))
  map("SUPER + SHIFT + ALT + UP", "Leave mousegrid, workspace to up monitor", escape_then(hl.dsp.workspace.move({ monitor = "u" })))
  map("SUPER + SHIFT + ALT + DOWN", "Leave mousegrid, workspace to down monitor", escape_then(hl.dsp.workspace.move({ monitor = "d" })))
end)
