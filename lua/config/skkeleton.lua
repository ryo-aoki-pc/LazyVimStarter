-- SKK (skkeleton) configuration module.
-- Responsible for: Deno path resolution on Windows, dictionary directory + downloader,
-- skkeleton runtime config, key mappings, and a cursor-anchored mode indicator.

local M = {}

----------------------------------------------------------------------
-- Paths
----------------------------------------------------------------------

local function dict_dir()
  local dir = vim.fn.stdpath("data") .. "/skk"
  vim.fn.mkdir(dir, "p")
  return dir
end

local function user_jisyo_path()
  local dir = vim.fn.stdpath("state") .. "/skk"
  vim.fn.mkdir(dir, "p")
  return dir .. "/user-jisyo"
end

----------------------------------------------------------------------
-- Dictionary set
----------------------------------------------------------------------

-- Each entry: name -> { url, archive = "gzip"|"tar.gz", outputs = { filename, ... } }
-- For gzip archives the output filename equals the gunzipped basename.
-- For tar.gz the outputs list every file we want to extract.
local DICT_BASE = "https://skk-dev.github.io/dict/"

local DICTIONARIES = {
  ["SKK-JISYO.L"]          = { url = DICT_BASE .. "SKK-JISYO.L.gz",          archive = "gzip",  outputs = { "SKK-JISYO.L" } },
  ["SKK-JISYO.jinmei"]     = { url = DICT_BASE .. "SKK-JISYO.jinmei.gz",     archive = "gzip",  outputs = { "SKK-JISYO.jinmei" } },
  ["SKK-JISYO.geo"]        = { url = DICT_BASE .. "SKK-JISYO.geo.gz",        archive = "gzip",  outputs = { "SKK-JISYO.geo" } },
  ["SKK-JISYO.station"]    = { url = DICT_BASE .. "SKK-JISYO.station.gz",    archive = "gzip",  outputs = { "SKK-JISYO.station" } },
  ["SKK-JISYO.propernoun"] = { url = DICT_BASE .. "SKK-JISYO.propernoun.gz", archive = "gzip",  outputs = { "SKK-JISYO.propernoun" } },
  ["SKK-JISYO.fullname"]   = { url = DICT_BASE .. "SKK-JISYO.fullname.gz",   archive = "gzip",  outputs = { "SKK-JISYO.fullname" } },
  ["SKK-JISYO.assoc"]      = { url = DICT_BASE .. "SKK-JISYO.assoc.gz",      archive = "gzip",  outputs = { "SKK-JISYO.assoc" } },
  ["SKK-JISYO.JIS2"]       = { url = DICT_BASE .. "SKK-JISYO.JIS2.gz",       archive = "gzip",  outputs = { "SKK-JISYO.JIS2" } },
  ["SKK-JISYO.JIS3_4"]     = { url = DICT_BASE .. "SKK-JISYO.JIS3_4.gz",     archive = "gzip",  outputs = { "SKK-JISYO.JIS3_4" } },
  ["SKK-JISYO.JIS2004"]    = { url = DICT_BASE .. "SKK-JISYO.JIS2004.gz",    archive = "gzip",  outputs = { "SKK-JISYO.JIS2004" } },
  ["zipcode"] = {
    url = DICT_BASE .. "zipcode.tar.gz",
    archive = "tar.gz",
    outputs = { "SKK-JISYO.zipcode", "SKK-JISYO.office.zipcode" },
  },
}

-- The order also defines lookup priority for skkeleton.
local DEFAULT_NAMES = {
  "SKK-JISYO.L",
  "SKK-JISYO.jinmei",
  "SKK-JISYO.geo",
  "SKK-JISYO.station",
  "SKK-JISYO.propernoun",
  "SKK-JISYO.fullname",
  "SKK-JISYO.assoc",
  "zipcode",
  "SKK-JISYO.JIS2",
  "SKK-JISYO.JIS3_4",
  "SKK-JISYO.JIS2004",
}

-- Returns a flat list of {path, encoding} pairs for skkeleton#config.globalDictionaries,
-- filtered to files that actually exist on disk.
function M.dictionary_paths()
  local dir = dict_dir()
  local paths = {}
  for _, name in ipairs(DEFAULT_NAMES) do
    local entry = DICTIONARIES[name]
    if entry then
      for _, fname in ipairs(entry.outputs) do
        local p = dir .. "/" .. fname
        if vim.fn.filereadable(p) == 1 then
          table.insert(paths, { p, "euc-jp" })
        end
      end
    end
  end
  return paths
end

----------------------------------------------------------------------
-- Deno discovery (Windows-friendly)
----------------------------------------------------------------------

local function resolve_deno()
  if vim.fn.executable("deno") == 1 then
    return "deno"
  end
  if vim.fn.has("win32") == 1 then
    local local_appdata = os.getenv("LOCALAPPDATA") or ""
    local userprofile   = os.getenv("USERPROFILE")  or ""
    local candidates = {
      local_appdata .. "\\Microsoft\\WinGet\\Links\\deno.exe",
      userprofile   .. "\\scoop\\apps\\deno\\current\\deno.exe",
    }
    -- WinGet Packages\DenoLand.Deno_*\deno.exe (glob)
    local winget_pkg_glob = local_appdata .. "\\Microsoft\\WinGet\\Packages\\DenoLand.Deno_*\\deno.exe"
    for _, found in ipairs(vim.fn.glob(winget_pkg_glob, true, true)) do
      table.insert(candidates, found)
    end
    for _, p in ipairs(candidates) do
      if vim.fn.executable(p) == 1 then
        return p
      end
    end
  end
  return nil
end

----------------------------------------------------------------------
-- Downloader
----------------------------------------------------------------------

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "SKK" })
end

-- Recursively find a file by basename under `root`. Returns absolute path or nil.
local function find_file(root, basename)
  local matches = vim.fn.glob(root .. "/**/" .. basename, true, true)
  if #matches > 0 then
    return matches[1]
  end
  local top = root .. "/" .. basename
  if vim.fn.filereadable(top) == 1 then
    return top
  end
  return nil
end

local function download_one(name, cb)
  local entry = DICTIONARIES[name]
  if not entry then
    notify("Unknown dictionary: " .. name, vim.log.levels.ERROR)
    return cb(false)
  end
  local dir = dict_dir()
  local archive_path = dir .. "/" .. vim.fn.fnamemodify(entry.url, ":t")
  notify("Downloading " .. name .. " ...")

  vim.system(
    { "curl", "-fsSL", "-o", archive_path, entry.url },
    { text = false },
    vim.schedule_wrap(function(curl_res)
      if curl_res.code ~= 0 then
        notify("curl failed for " .. name .. ":\n" .. (curl_res.stderr or ""), vim.log.levels.ERROR)
        return cb(false)
      end

      if entry.archive == "gzip" then
        -- gunzip in-place (-f overwrites existing .L etc.)
        vim.system({ "gzip", "-df", archive_path }, { text = true }, vim.schedule_wrap(function(ex_res)
          if ex_res.code ~= 0 then
            notify("Extract failed for " .. name .. ":\n" .. (ex_res.stderr or ""), vim.log.levels.ERROR)
            return cb(false)
          end
          notify("Installed " .. name)
          cb(true)
        end))
      elseif entry.archive == "tar.gz" then
        -- Extract whole archive to a temp dir, then move requested files by basename.
        -- This handles archives that wrap their content in a subdirectory
        -- (e.g. zipcode.tar.gz contains `zipcode/SKK-JISYO.zipcode`).
        local tmp = vim.fn.tempname()
        vim.fn.mkdir(tmp, "p")
        vim.system(
          { "tar", "-xzf", archive_path, "-C", tmp },
          { text = true },
          vim.schedule_wrap(function(ex_res)
            if ex_res.code ~= 0 then
              notify("Extract failed for " .. name .. ":\n" .. (ex_res.stderr or ""), vim.log.levels.ERROR)
              vim.fn.delete(tmp, "rf")
              return cb(false)
            end
            local missing = {}
            for _, fname in ipairs(entry.outputs) do
              local found = find_file(tmp, fname)
              if found then
                vim.fn.rename(found, dir .. "/" .. fname)
              else
                table.insert(missing, fname)
              end
            end
            vim.fn.delete(tmp, "rf")
            vim.fn.delete(archive_path)
            if #missing > 0 then
              notify(
                "Missing in archive for " .. name .. ": " .. table.concat(missing, ", "),
                vim.log.levels.ERROR
              )
              return cb(false)
            end
            notify("Installed " .. name)
            cb(true)
          end)
        )
      end
    end)
  )
end

local function download_many(names, on_done)
  local i = 0
  local function step()
    i = i + 1
    if i > #names then
      if on_done then on_done() end
      return
    end
    download_one(names[i], function(_) step() end)
  end
  step()
end

----------------------------------------------------------------------
-- Re-register dictionaries with a running skkeleton
----------------------------------------------------------------------

local function reload_dictionaries()
  if vim.fn.exists("*skkeleton#config") == 0 then
    return -- skkeleton not loaded yet; initialize-pre hook will pick them up.
  end
  vim.fn["skkeleton#config"]({ globalDictionaries = M.dictionary_paths() })
end

----------------------------------------------------------------------
-- Floating mode indicator
----------------------------------------------------------------------

local MODE_LABEL = {
  hira    = "あ",
  kata    = "ア",
  hankata = "ｱ",
  zenkaku = "Ａ",
  abbrev  = "SKK:Abbr",
}

M._indicator = { buf = nil, win = nil }

local function current_skkeleton_mode()
  if vim.fn.exists("*skkeleton#mode") == 1 then
    local ok, mode = pcall(vim.fn["skkeleton#mode"])
    if ok and type(mode) == "string" and mode ~= "" then
      return mode
    end
  end

  local mode = vim.g["skkeleton#mode"]
  return type(mode) == "string" and mode or ""
end

local function indicator_label()
  if vim.g["skkeleton#enabled"] ~= 1 and vim.g["skkeleton#enabled"] ~= true then
    return nil
  end
  local mode = current_skkeleton_mode()
  return MODE_LABEL[mode] or MODE_LABEL.hira
end

function M.hide_indicator()
  local win = M._indicator.win
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
  end
  M._indicator.win = nil
end

function M.show_indicator()
  -- Skip in non-insert/cmdline modes; nothing to anchor cleanly.
  local m = vim.fn.mode()
  if m == "c" then
    -- Floating windows over the cmdline are unreliable; skip.
    return
  end
  local label = indicator_label()
  if not label then
    M.hide_indicator()
    return
  end

  local buf = M._indicator.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "wipe"
    M._indicator.buf = buf
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { label })

  local width = vim.fn.strdisplaywidth(label)
  local opts = {
    relative   = "cursor",
    row        = 1,
    col        = 0,
    width      = width,
    height     = 1,
    focusable  = false,
    style      = "minimal",
    noautocmd  = true,
    zindex     = 50,
  }

  local win = M._indicator.win
  if win and vim.api.nvim_win_is_valid(win) then
    -- nvim_win_set_config does not accept noautocmd; drop it.
    local update = vim.deepcopy(opts)
    update.noautocmd = nil
    vim.api.nvim_win_set_config(win, update)
  else
    win = vim.api.nvim_open_win(buf, false, opts)
    M._indicator.win = win
    vim.wo[win].winhighlight = "Normal:SkkeletonIndicator,NormalFloat:SkkeletonIndicator"
  end
end

----------------------------------------------------------------------
-- User commands
----------------------------------------------------------------------

local function define_commands()
  vim.api.nvim_create_user_command("SkkDownloadDictionary", function(opts)
    local names
    if #opts.fargs == 0 then
      names = DEFAULT_NAMES
    else
      names = opts.fargs
    end
    download_many(names, reload_dictionaries)
  end, {
    nargs = "*",
    complete = function()
      return vim.tbl_keys(DICTIONARIES)
    end,
    desc = "Download SKK dictionaries (all defaults if no args)",
  })

  vim.api.nvim_create_user_command("SkkDictionaryPath", function()
    local paths = M.dictionary_paths()
    if #paths == 0 then
      notify("No dictionaries installed yet. Run :SkkDownloadDictionary", vim.log.levels.WARN)
      return
    end
    for _, p in ipairs(paths) do
      print(p[1])
    end
  end, { desc = "List installed SKK dictionary paths" })
end

----------------------------------------------------------------------
-- skkeleton initialize hook
----------------------------------------------------------------------

function M.on_initialize()
  local paths = M.dictionary_paths()
  if #paths == 0 then
    notify(
      "No SKK dictionaries found. Run :SkkDownloadDictionary to install the defaults.",
      vim.log.levels.WARN
    )
  end
  vim.fn["skkeleton#config"]({
    globalDictionaries        = paths,
    userDictionary            = user_jisyo_path(),
    showCandidatesCount       = 1,
    eggLikeNewline            = true,
    registerConvertResult     = true,
    markerHenkan              = "▽",
    markerHenkanSelect        = "▼",
    -- Enable Google Japanese Input CGI API as a fallback source.
    -- https://www.google.co.jp/ime/cgiapi.html (requires network access)
    sources                   = { "skk_dictionary", "google_japanese_input" },
  })

  -- Remap abbrev trigger: `l` enters abbrev mode (only in hira mode --
  -- see SkkeletonAbbrevKey autocmd), `/` is unbound (passes through).
  vim.fn["skkeleton#register_keymap"]("input", "l", "abbrev")
  vim.fn["skkeleton#register_keymap"]("input", "/", "")
end

-- Toggle the `l` keymap based on current skkeleton mode.
-- In hira mode: `l` triggers abbrev. In abbrev (and other) modes:
-- unmap `l` so it falls through to kanaInput and is inserted literally.
function M.sync_abbrev_keymap()
  local mode = current_skkeleton_mode()
  local func = (mode == "hira") and "abbrev" or ""
  pcall(vim.fn["skkeleton#register_keymap"], "input", "l", func)
end

----------------------------------------------------------------------
-- Public setup
----------------------------------------------------------------------

function M.setup()
  -- Late-bind Deno (options.lua sets a default early to avoid E121).
  local deno = resolve_deno()
  if deno then
    vim.g["denops#deno"] = deno
  end

  define_commands()

  -- Toggle keymap (insert + cmdline). The buffer-local lhs syntax is required.
  local function map(mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, { silent = true })
  end
  map("i", "<C-j>", "<Plug>(skkeleton-toggle)")
  map("c", "<C-j>", "<Plug>(skkeleton-toggle)")
  map("t", "<C-j>", "<Plug>(skkeleton-toggle)")

  -- Indicator highlight (overridable by user).
  vim.api.nvim_set_hl(0, "SkkeletonIndicator", { link = "IncSearch", default = true })

  local group = vim.api.nvim_create_augroup("SkkeletonIndicator", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "skkeleton-enable-pre",
    callback = function()
      vim.schedule(M.show_indicator)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "skkeleton-disable-pre",
    callback = function()
      vim.schedule(M.hide_indicator)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "skkeleton-mode-changed",
    callback = function()
      vim.schedule(M.show_indicator)
      vim.schedule(M.sync_abbrev_keymap)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "skkeleton-enable-post",
    callback = function()
      vim.schedule(M.sync_abbrev_keymap)
    end,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
    group = group,
    callback = function()
      if vim.g["skkeleton#enabled"] == 1 or vim.g["skkeleton#enabled"] == true then
        M.show_indicator()
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "WinLeave" }, {
    group = group,
    callback = function()
      M.hide_indicator()
    end,
  })
end

return M
