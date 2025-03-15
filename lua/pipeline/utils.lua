local stringUtils = require('pipeline.utils.string')

local M = {
  string = stringUtils,
}

---@generic T
---@param debounced_fn fun(arg1: T)
---@return fun(arg1: T)
function M.debounced(debounced_fn)
  local queued = false
  local last_arg = nil

  return function(a)
    last_arg = a

    if queued then
      return
    end

    queued = true

    vim.schedule(function()
      debounced_fn(last_arg)
      queued = false
      last_arg = nil
    end)
  end
end

---@param path string
---@return string|nil
function M.read_file(path)
  local f = io.open(path, 'r')

  if not f then
    return nil
  end

  local content = f:read('*all')

  f:close()

  return content
end

---@generic V
---@param fn fun(arg1: V): any
---@param tbl table<any, V>
---@return table<integer, V>
function M.uniq(fn, tbl)
  local set = {}
  local unique_table = {}

  for _, v in ipairs(tbl) do
    local id = fn(v)

    if not set[id] then
      table.insert(unique_table, v)
      set[id] = true
    end
  end

  return unique_table
end

function M.delay(ms, fn)
  local timer = vim.loop.new_timer()

  if not timer then
    return
  end

  timer:start(ms, 0, function()
    timer:close()
    vim.schedule(fn)
  end)
end

---@generic T
---@param fn fun(value: T, key: number): number
---@param tbl table<number, T>
---@return table<number, T[]>
function M.group_by(fn, tbl)
  local m = {}

  for k, v in ipairs(tbl) do
    local key = fn(v, k)
    m[key] = m[key] or {}
    table.insert(m[key], v)
  end

  return m
end


---@param file string
---@return boolean
function M.file_exists_in_git_root(file)
  local git_root_dir = vim.fn
    .fnamemodify(vim.trim(vim.fn.system('git rev-parse --show-toplevel')), ':p')
    :gsub('/$', '')
  return vim.loop.fs_stat(git_root_dir .. "/" .. file) ~= nil
end

---@param file string
---@return boolean
function M.file_exists(file)
  return vim.loop.fs_stat(file) ~= nil
end

---@param uri string
function M.open(uri)
  if M.file_exists(uri) then
    return M.float { style = '', file = uri }
  end

  local Config = require('pipeline.config')
  local cmd

  if Config.options.browser then
    cmd = { Config.options.browser, uri }
  elseif vim.fn.has('win32') == 1 then
    cmd = { 'explorer', uri }
  elseif vim.fn.has('macunix') == 1 then
    cmd = { 'open', uri }
  else
    if vim.fn.executable('xdg-open') == 1 then
      cmd = { 'xdg-open', uri }
    elseif vim.fn.executable('wslview') == 1 then
      cmd = { 'wslview', uri }
    else
      cmd = { 'open', uri }
    end
  end

  local ret = vim.fn.jobstart(cmd, { detach = true })

  if ret <= 0 then
    local msg = {
      'Failed to open uri',
      ret,
      vim.inspect(cmd),
    }
    vim.notify(table.concat(msg, '\n'), vim.log.levels.ERROR)
  end
end

---@param value any
---@return boolean
function M.is_nil(value)
  return value == nil
    or value == vim.NIL
    or require('pipeline.yaml').is_yaml_nil(value)
end

return M
