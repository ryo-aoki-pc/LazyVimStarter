local M = {}

local uv = vim.uv or vim.loop
local dictionary_base_url = "https://skk-dev.github.io/dict/"
local default_dictionary_name = "SKK-JISYO.L"
local default_dictionary_names = {
  default_dictionary_name,
  "SKK-JISYO.jinmei",
  "SKK-JISYO.geo",
  "SKK-JISYO.station",
  "SKK-JISYO.propernoun",
  "SKK-JISYO.fullname",
  "SKK-JISYO.assoc",
  "SKK-JISYO.zipcode",
  "SKK-JISYO.office.zipcode",
  "SKK-JISYO.JIS2",
  "SKK-JISYO.JIS3_4",
  "SKK-JISYO.JIS2004",
}
local archive_dictionary_sources = {
  ["SKK-JISYO.zipcode"] = {
    archive_type = "tar.gz",
    url = dictionary_base_url .. "zipcode.tar.gz",
    archive_entry = "zipcode/SKK-JISYO.zipcode",
  },
  ["SKK-JISYO.office.zipcode"] = {
    archive_type = "tar.gz",
    url = dictionary_base_url .. "zipcode.tar.gz",
    archive_entry = "zipcode/SKK-JISYO.office.zipcode",
  },
}
local unsupported_archive_dictionary_names = {
  ["SKK-JISYO.edict"] = "tar.gz",
}
local did_setup = false
local warned_missing_dictionaries = {}

local function notify(message, level)
  vim.schedule(function()
    vim.notify(message, level or vim.log.levels.INFO, { title = "skkeleton" })
  end)
end

local function file_exists(path)
  return uv.fs_stat(path) ~= nil
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function remove_file(path)
  if file_exists(path) then
    uv.fs_unlink(path)
  end
end

local function powershell_quote(value)
  return (value:gsub("'", "''"))
end

local function define_vim_global_default(name, value)
  if vim.g[name] == nil then
    vim.g[name] = value
  end
end

local function normalize_dictionary_name(name)
  local dictionary_name = type(name) == "string" and vim.trim(name) or ""
  if dictionary_name == "" then
    return default_dictionary_name
  end

  dictionary_name = dictionary_name:gsub("%.tar%.gz$", "")
  dictionary_name = dictionary_name:gsub("%.gz$", "")

  if not dictionary_name:match("^SKK%-JISYO%.") then
    dictionary_name = "SKK-JISYO." .. dictionary_name
  end

  local archive_type = unsupported_archive_dictionary_names[dictionary_name]
  if archive_type then
    return nil, string.format(
      "%s is distributed as %s and is not supported by :SkkDownloadDictionary. Install it manually.",
      dictionary_name,
      archive_type
    )
  end

  if not dictionary_name:match("^SKK%-JISYO[%w%._%+%-]+$") then
    return nil, string.format("Unsupported SKK dictionary name: %s", dictionary_name)
  end

  return dictionary_name
end

local function append_dictionary_name(dest, seen, name)
  local dictionary_name, err = normalize_dictionary_name(name)
  if err or seen[dictionary_name] then
    return
  end

  seen[dictionary_name] = true
  table.insert(dest, dictionary_name)
end

local function append_dictionary_names(dest, seen, names)
  if type(names) ~= "table" then
    return
  end

  for _, name in ipairs(names) do
    if type(name) == "string" then
      append_dictionary_name(dest, seen, name)
    end
  end
end

local function get_explicit_dictionary_names()
  local names = {}
  local seen = {}

  append_dictionary_names(names, seen, default_dictionary_names)
  append_dictionary_names(names, seen, vim.g.skkeleton_extra_dictionaries)

  return names
end

local function get_managed_dictionary_names()
  local names = {}
  local seen = {}

  append_dictionary_names(names, seen, default_dictionary_names)
  append_dictionary_names(names, seen, vim.g.skkeleton_extra_dictionaries)

  return names
end

local function get_requested_dictionary_names(name)
  local requested_name = type(name) == "string" and vim.trim(name) or ""
  if requested_name == "" then
    return get_explicit_dictionary_names()
  end

  local dictionary_name, err = normalize_dictionary_name(requested_name)
  if not dictionary_name then
    return nil, err
  end

  return { dictionary_name }
end

local function get_dictionary_source(dictionary_name)
  local source = archive_dictionary_sources[dictionary_name]
  if source then
    return source
  end

  return {
    archive_type = "gz",
    url = dictionary_base_url .. dictionary_name .. ".gz",
  }
end

local function resolve_deno_executable()
  local configured = vim.g["denops#deno"]
  if type(configured) == "string" and configured ~= "" and vim.fn.executable(configured) == 1 then
    return configured
  end

  local deno = vim.fn.exepath("deno")
  if deno ~= "" then
    return deno
  end

  if vim.fn.has("win32") == 1 then
    local winget_package = nil
    if vim.env.LOCALAPPDATA then
      winget_package = vim.fn.glob(
        vim.fs.joinpath(vim.env.LOCALAPPDATA, "Microsoft", "WinGet", "Packages", "DenoLand.Deno_*", "deno.exe"),
        false,
        true
      )[1]
    end

    local candidates = {
      vim.env.LOCALAPPDATA and vim.fs.joinpath(vim.env.LOCALAPPDATA, "deno", "bin", "deno.exe") or nil,
      vim.env.LOCALAPPDATA and vim.fs.joinpath(vim.env.LOCALAPPDATA, "Microsoft", "WinGet", "Links", "deno.exe") or nil,
      winget_package,
      vim.env.USERPROFILE and vim.fs.joinpath(vim.env.USERPROFILE, "scoop", "apps", "deno", "current", "deno.exe") or nil,
      vim.env.USERPROFILE and vim.fs.joinpath(vim.env.USERPROFILE, "scoop", "shims", "deno.exe") or nil,
    }

    for _, candidate in ipairs(candidates) do
      if candidate and file_exists(candidate) then
        return candidate
      end
    end
  end

  return "deno"
end

local function download_with_powershell(url, out_path, callback)
  local powershell = vim.fn.exepath("pwsh")
  if powershell == "" then
    powershell = vim.fn.exepath("powershell")
  end

  if powershell == "" then
    callback({ code = 1, stderr = "PowerShell was not found in PATH.", stdout = "" })
    return
  end

  local script = table.concat({
    "$ProgressPreference = 'SilentlyContinue'",
    "$uri = '" .. powershell_quote(url) .. "'",
    "$output = '" .. powershell_quote(out_path) .. "'",
    "$temp = [System.IO.Path]::GetTempFileName()",
    "Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $temp",
    "$input = [System.IO.File]::OpenRead($temp)",
    "try {",
    "  $gzip = New-Object System.IO.Compression.GzipStream($input, [System.IO.Compression.CompressionMode]::Decompress)",
    "  try {",
    "    $outputStream = [System.IO.File]::Create($output)",
    "    try { $gzip.CopyTo($outputStream) } finally { $outputStream.Dispose() }",
    "  } finally { $gzip.Dispose() }",
    "} finally {",
    "  $input.Dispose()",
    "  Remove-Item -Force $temp -ErrorAction SilentlyContinue",
    "}",
  }, "; ")

  vim.system(
    { powershell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script },
    { text = true },
    callback
  )
end

local function download_with_posix(url, out_path, callback)
  if vim.fn.executable("sh") ~= 1 or vim.fn.executable("curl") ~= 1 or vim.fn.executable("gzip") ~= 1 then
    callback({ code = 1, stderr = "sh, curl, and gzip are required to download the SKK dictionary.", stdout = "" })
    return
  end

  local script = string.format(
    "curl -fsSL %s | gzip -dc > %s",
    vim.fn.shellescape(url),
    vim.fn.shellescape(out_path)
  )

  vim.system({ "sh", "-c", script }, { text = true }, callback)
end

local function download_tar_entry_with_powershell(url, archive_entry, out_path, callback)
  local powershell = vim.fn.exepath("pwsh")
  if powershell == "" then
    powershell = vim.fn.exepath("powershell")
  end

  if powershell == "" then
    callback({ code = 1, stderr = "PowerShell was not found in PATH.", stdout = "" })
    return
  end

  local script = table.concat({
    "$ProgressPreference = 'SilentlyContinue'",
    "$uri = '" .. powershell_quote(url) .. "'",
    "$entry = '" .. powershell_quote(archive_entry) .. "'",
    "$output = '" .. powershell_quote(out_path) .. "'",
    "$archive = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + '.tar.gz')",
    "$tarFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + '.tar')",
    "$extractDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())",
    "$tar = Join-Path $env:WINDIR 'System32\\tar.exe'",
    "try {",
    "  New-Item -ItemType Directory -Path $extractDir | Out-Null",
    "  Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $archive",
    "  $input = [System.IO.File]::OpenRead($archive)",
    "  try {",
    "    $gzip = New-Object System.IO.Compression.GzipStream($input, [System.IO.Compression.CompressionMode]::Decompress)",
    "    try {",
    "      $outputStream = [System.IO.File]::Create($tarFile)",
    "      try { $gzip.CopyTo($outputStream) } finally { $outputStream.Dispose() }",
    "    } finally { $gzip.Dispose() }",
    "  } finally { $input.Dispose() }",
    "  & $tar -xf $tarFile -C $extractDir",
    "  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }",
    "  $source = Join-Path $extractDir ($entry -replace '/', [System.IO.Path]::DirectorySeparatorChar)",
    "  if (-not (Test-Path $source)) { throw 'Archive entry was not found: ' + $entry }",
    "  Move-Item -Force $source $output",
    "} finally {",
    "  Remove-Item -Recurse -Force $extractDir -ErrorAction SilentlyContinue",
    "  Remove-Item -Force $archive, $tarFile -ErrorAction SilentlyContinue",
    "}",
  }, "; ")

  vim.system(
    { powershell, "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script },
    { text = true },
    callback
  )
end

local function download_tar_entry_with_posix(url, archive_entry, out_path, callback)
  if vim.fn.executable("sh") ~= 1 or vim.fn.executable("curl") ~= 1 or vim.fn.executable("tar") ~= 1 then
    callback({ code = 1, stderr = "sh, curl, and tar are required to download archive-backed SKK dictionaries.", stdout = "" })
    return
  end

  local script = string.format(
    [=[
set -e
archive="$(mktemp)"
extract_dir="$(mktemp -d)"
entry=%s
out=%s
cleanup() {
  rm -rf "$archive" "$extract_dir"
}
trap cleanup EXIT
curl -fsSL %s > "$archive"
tar -xzf "$archive" -C "$extract_dir"
mv "$extract_dir/$entry" "$out"
]=],
    vim.fn.shellescape(archive_entry),
    vim.fn.shellescape(out_path),
    vim.fn.shellescape(url)
  )

  vim.system({ "sh", "-c", script }, { text = true }, callback)
end

local function dictionary_path(paths, name)
  return vim.fs.joinpath(paths.skk_dir, name)
end

local function get_enabled_dictionary_names(paths)
  local names = {}
  local seen = {}

  append_dictionary_names(names, seen, get_explicit_dictionary_names())

  for _, name in ipairs(default_dictionary_names) do
    if file_exists(dictionary_path(paths, name)) then
      append_dictionary_name(names, seen, name)
    end
  end

  return names
end

local function get_missing_dictionary_names(paths)
  local missing = {}

  for _, name in ipairs(get_explicit_dictionary_names()) do
    if not file_exists(dictionary_path(paths, name)) then
      table.insert(missing, name)
    end
  end

  return missing
end

function M.paths()
  local data_dir = vim.fn.stdpath("data")
  local state_dir = vim.fn.stdpath("state")
  local skk_dir = vim.fs.joinpath(data_dir, "skk")
  local skkeleton_dir = vim.fs.joinpath(data_dir, "skkeleton")
  local rank_dir = vim.fs.joinpath(state_dir, "skkeleton")

  return {
    skk_dir = skk_dir,
    dictionary = vim.fs.joinpath(skk_dir, default_dictionary_name),
    user_dictionary = vim.fs.joinpath(skkeleton_dir, "user-dict"),
    rank_file = vim.fs.joinpath(rank_dir, "rank.json"),
  }
end

function M.dictionary_names()
  local names = {}
  for _, name in ipairs(get_managed_dictionary_names()) do
    table.insert(names, name)
  end
  return names
end

function M.ensure_dirs()
  local paths = M.paths()
  ensure_dir(paths.skk_dir)
  ensure_dir(vim.fs.dirname(paths.user_dictionary))
  ensure_dir(vim.fs.dirname(paths.rank_file))
  return paths
end

function M.dictionary_installed(name)
  local paths = M.paths()
  local dictionary_name, err = normalize_dictionary_name(name)
  if err then
    return false
  end

  return file_exists(dictionary_path(paths, dictionary_name))
end

function M.warn_if_dictionary_missing()
  local paths = M.paths()
  local missing = get_missing_dictionary_names(paths)
  if #missing == 0 then
    warned_missing_dictionaries = {}
    return
  end

  local new_missing = {}
  local still_missing = {}
  for _, name in ipairs(missing) do
    still_missing[name] = true
    if not warned_missing_dictionaries[name] then
      warned_missing_dictionaries[name] = true
      table.insert(new_missing, name)
    end
  end

  for name in pairs(warned_missing_dictionaries) do
    if not still_missing[name] then
      warned_missing_dictionaries[name] = nil
    end
  end

  if #new_missing == 0 then
    return
  end

  notify(
    "SKK dictionaries were not found: "
      .. table.concat(new_missing, ", ")
      .. ". Run :SkkDownloadDictionary to install defaults, or :SkkDownloadDictionary [name] for a specific dictionary.",
    vim.log.levels.WARN
  )
end

function M.download_dictionary(force, name)
  local dictionary_names, name_err = get_requested_dictionary_names(name)
  if not dictionary_names then
    notify(name_err, vim.log.levels.ERROR)
    return
  end

  local deno = resolve_deno_executable()
  if vim.fn.executable(deno) ~= 1 then
    notify("Deno is required. Make sure the deno executable is available before using skkeleton.", vim.log.levels.ERROR)
    return
  end

  local function download_single_dictionary(dictionary_name, on_complete)
    local paths = M.ensure_dirs()
    local source = get_dictionary_source(dictionary_name)
    local url = source.url
    local target_path = dictionary_path(paths, dictionary_name)
    if file_exists(target_path) and not force then
      notify(
        dictionary_name
          .. " is already installed. Use :SkkDownloadDictionary! "
          .. dictionary_name
          .. " to overwrite it."
      )
      if on_complete then
        on_complete({ ok = true, skipped = true, name = dictionary_name, path = target_path })
      end
      return
    end

    local temp_path = target_path .. ".tmp"
    remove_file(temp_path)
    notify("Downloading " .. dictionary_name .. " ...")

    local on_system_complete = vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        remove_file(temp_path)
        local stderr = vim.trim(result.stderr or "")
        local stdout = vim.trim(result.stdout or "")
        local message = stderr ~= "" and stderr or stdout
        if message == "" then
          message = "Unknown error"
        end
        notify("Failed to download " .. dictionary_name .. ": " .. message, vim.log.levels.ERROR)
        if on_complete then
          on_complete({ ok = false, name = dictionary_name, message = message })
        end
        return
      end

      if force then
        remove_file(target_path)
      end

      local ok, rename_err = uv.fs_rename(temp_path, target_path)
      if not ok then
        remove_file(temp_path)
        notify(
          "Downloaded " .. dictionary_name .. " but could not move it into place: " .. tostring(rename_err),
          vim.log.levels.ERROR
        )
        if on_complete then
          on_complete({ ok = false, name = dictionary_name, message = tostring(rename_err) })
        end
        return
      end

      warned_missing_dictionaries[dictionary_name] = nil
      notify("Installed " .. dictionary_name .. " to " .. target_path)

      if vim.fn.exists("*skkeleton#initialize") == 1 then
        pcall(vim.fn["skkeleton#initialize"])
      end

      if on_complete then
        on_complete({ ok = true, name = dictionary_name, path = target_path })
      end
    end)

    if vim.fn.has("win32") == 1 then
      if source.archive_type == "tar.gz" then
        download_tar_entry_with_powershell(url, source.archive_entry, temp_path, on_system_complete)
        return
      end

      download_with_powershell(url, temp_path, on_system_complete)
      return
    end

    if source.archive_type == "tar.gz" then
      download_tar_entry_with_posix(url, source.archive_entry, temp_path, on_system_complete)
      return
    end

    download_with_posix(url, temp_path, on_system_complete)
  end

  if #dictionary_names == 1 then
    download_single_dictionary(dictionary_names[1])
    return
  end

  notify("Downloading default SKK dictionaries: " .. table.concat(dictionary_names, ", "))

  local function download_dictionary_at(index)
    local dictionary_name = dictionary_names[index]
    if not dictionary_name then
      notify("Finished processing default SKK dictionaries.")
      return
    end

    download_single_dictionary(dictionary_name, function(result)
      if not result.ok then
        return
      end

      download_dictionary_at(index + 1)
    end)
  end

  download_dictionary_at(1)
end

function M.apply_config()
  local paths = M.ensure_dirs()
  local dictionaries = {}
  local seen_paths = {}

  for _, name in ipairs(get_enabled_dictionary_names(paths)) do
    local path = dictionary_path(paths, name)
    if file_exists(path) and not seen_paths[path] then
      seen_paths[path] = true
      table.insert(dictionaries, path)
    end
  end

  vim.fn["skkeleton#config"]({
    eggLikeNewline = true,
    globalDictionaries = dictionaries,
    immediatelyDictionaryRW = true,
    kanaTable = "rom",
    markerHenkan = "▿",
    markerHenkanSelect = "▾",
    completionRankFile = paths.rank_file,
    registerConvertResult = true,
    selectCandidateKeys = "asdfjkl",
    showCandidatesCount = 1,
    userDictionary = paths.user_dictionary,
  })

  M.warn_if_dictionary_missing()
end

function M.setup()
  if did_setup then
    return
  end

  did_setup = true
  define_vim_global_default("denops#disabled", 0)
  define_vim_global_default("denops#deno_dir", vim.NIL)
  define_vim_global_default("denops#debug", 0)
  define_vim_global_default("denops#disable_deprecation_warning_message", 0)
  define_vim_global_default("denops#_test", 0)

  local deno = resolve_deno_executable()
  if vim.g["denops#deno"] == nil or vim.fn.executable(vim.g["denops#deno"]) ~= 1 then
    vim.g["denops#deno"] = deno
  end

  M.ensure_dirs()

  vim.api.nvim_create_user_command("SkkDownloadDictionary", function(opts)
    M.download_dictionary(opts.bang, opts.args)
  end, {
    bang = true,
    nargs = "?",
    complete = function(arg_lead)
      local matches = {}
      for _, name in ipairs(M.dictionary_names()) do
        if name:find(arg_lead, 1, true) == 1 then
          table.insert(matches, name)
        end
      end
      return matches
    end,
    desc = "Download default or named SKK dictionaries for skkeleton",
  })

  vim.api.nvim_create_user_command("SkkDictionaryPath", function(opts)
    local paths = M.paths()

    if opts.args ~= "" then
      local dictionary_name, err = normalize_dictionary_name(opts.args)
      if not dictionary_name then
        notify(err, vim.log.levels.ERROR)
        return
      end

      notify(dictionary_name .. ": " .. dictionary_path(paths, dictionary_name))
      return
    end

    local lines = {}
    for _, name in ipairs(M.dictionary_names()) do
      table.insert(lines, name .. ": " .. dictionary_path(paths, name))
    end
    notify(table.concat(lines, "\n"))
  end, {
    nargs = "?",
    desc = "Show configured SKK dictionary paths",
  })
end

return M