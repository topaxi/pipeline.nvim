local M = {}

---@param job Job
local function create_job(job)
  return require('plenary.job'):new(job)
end

---@param str string
---@return string
local function strip_git_suffix(str)
  if str:sub(-4) == '.git' then
    return str:sub(1, -5)
  end

  return str
end

---@param remote_url string
---@return string|nil, string|nil
local function parse_remote_url(remote_url)
  local cleaned = strip_git_suffix(remote_url)
  cleaned = cleaned:gsub('^%w+://', '')
  cleaned = cleaned:gsub('^.+@', '')
  cleaned = cleaned:gsub(':', '/', 1)

  return cleaned:match('^([^/]+)/(.+)$')
end

---@class pipeline.Remote
---@field name string    remote name (e.g. "origin", "upstream")
---@field server string  hostname (e.g. "github.com")
---@field repo string    owner/repo path (e.g. "org/repo")

---@return pipeline.Remote[]
---@nodiscard
function M.get_remotes()
  local job = create_job {
    command = 'git',
    args = { 'remote' },
  }

  job:sync()

  local remote_names = job:result()
  ---@type pipeline.Remote[]
  local remotes = {}

  for _, name in ipairs(remote_names) do
    local url_job = create_job {
      command = 'git',
      args = { 'config', '--get', string.format('remote.%s.url', name) },
    }

    url_job:sync()

    local url = table.concat(url_job:result(), '')
    local server, repo = parse_remote_url(url)

    if server and repo then
      table.insert(remotes, {
        name = name,
        server = server,
        repo = repo,
      })
    end
  end

  return remotes
end

---@return string, string
---@nodiscard
---@deprecated Use get_remotes() instead
function M.get_current_repository()
  local origin_url_job = create_job {
    command = 'git',
    args = {
      'config',
      '--get',
      'remote.origin.url',
    },
  }

  origin_url_job:sync()

  local origin_url = table.concat(origin_url_job:result(), '')

  local server, repo = parse_remote_url(origin_url)
  return server, repo
end

function M.get_current_branch()
  local job = create_job {
    command = 'git',
    args = { 'branch', '--show-current' },
  }

  job:sync()

  return table.concat(job:result(), '')
end

---@param remote_name? string defaults to "origin"
function M.get_default_branch(remote_name)
  remote_name = remote_name or 'origin'

  local job = create_job {
    command = 'git',
    args = { 'remote', 'show', remote_name },
  }

  job:sync()

  -- luacheck: ignore
  for match in table.concat(job:result(), ''):gmatch('HEAD branch: (%a+)') do
    return match
  end

  return 'main'
end

M._parse_remote_url = parse_remote_url
-- backwards compatibility
M._parse_origin_url = parse_remote_url

return M
