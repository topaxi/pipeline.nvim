---@class pipeline.Config
local defaultConfig = {
  --- The browser executable path to open workflow runs/jobs in
  ---@type string|nil
  browser = nil,
  --- How much workflow runs and jobs should be indented
  indent = 2,
  --- Provider options
  ---@class pipeline.config.Providers
  ---@field github? pipeline.providers.github.rest.Options
  ---@field gitlab? pipeline.providers.gitlab.graphql.Options
  providers = {
    github = {
      default_host = 'github.com',
      --- Mapping of names that should be renamed to resolvable hostnames
      --- names are something that you've used as a repository url,
      --- that can't be resolved by this plugin, like aliases from ssh config
      --- for example to resolve "gh" to "github.com"
      --- ```lua
      --- resolve_host = function(host)
      ---   if host == "gh" then
      ---     return "github.com"
      ---   end
      --- end
      --- ```
      --- Return nil to fallback to the default_host
      ---@param host string
      ---@return string|nil
      resolve_host = function(host)
        return host
      end,
    },
    gitlab = {
      default_host = 'gitlab.com',
      --- Mapping of names that should be renamed to resolvable hostnames
      --- names are something that you've used as a repository url,
      --- that can't be resolved by this plugin, like aliases from ssh config
      --- for example to resolve "gl" to "gitlab.com"
      --- ```lua
      --- resolve_host = function(host)
      ---   if host == "gl" then
      ---     return "gitlab.com"
      ---   end
      --- end
      --- ```
      --- Return nil to fallback to the default_host
      ---@param host string
      ---@return string|nil
      resolve_host = function(host)
        return host
      end,
    },
  },
  --- Allowed hosts to fetch data from, github.com is always allowed
  --- @type string[]
  allowed_hosts = {},
  ---@class pipeline.config.Icons
  icons = {
    workflow_dispatch = '⚡️',
    ---@class pipeline.config.IconConclusion
    conclusion = {
      success = '✓',
      failure = 'X',
      startup_failure = 'X',
      cancelled = '⊘',
      skipped = '◌',
      action_required = '⚠',
    },
    ---@class pipeline.config.IconStatus
    status = {
      unknown = '?',
      pending = '○',
      queued = '○',
      requested = '○',
      waiting = '○',
      in_progress = '●',
    },
  },
  ---@alias hl_group 'PipelineError' | 'PipelineRunIconSuccess' | 'PipelineRunIconFailure' | 'PipelineRunIconStartup_failure' | 'PipelineRunIconPending' | 'PipelineRunIconRequested' | 'PipelineRunIconWaiting' | 'PipelineRunIconIn_progress' | 'PipelineRunIconCancelled' | 'PipelineRunIconSkipped' | 'PipelineRunCancelled' | 'PipelineRunSkipped' | 'PipelineJobCancelled' | 'PipelineJobSkipped' | 'PipelineStepCancelled' | 'PipelineStepSkipped'
  ---@type table<hl_group, vim.api.keyset.highlight>
  highlights = {
    PipelineError = { link = 'DiagnosticError' },
    PipelineRunIconSuccess = { link = 'DiagnosticOk' },
    PipelineRunIconFailure = { link = 'DiagnosticError' },
    PipelineRunIconStartup_failure = { link = 'DiagnosticError' },
    PipelineRunIconPending = { link = 'DiagnosticWarn' },
    PipelineRunIconRequested = { link = 'DiagnosticWarn' },
    PipelineRunIconWaiting = { link = 'DiagnosticWarn' },
    PipelineRunIconIn_progress = { link = 'DiagnosticWarn' },
    PipelineRunIconCancelled = { link = 'Comment' },
    PipelineRunIconSkipped = { link = 'Comment' },
    PipelineRunCancelled = { link = 'Comment' },
    PipelineRunSkipped = { link = 'Comment' },
    PipelineJobCancelled = { link = 'Comment' },
    PipelineJobSkipped = { link = 'Comment' },
    PipelineStepCancelled = { link = 'Comment' },
    PipelineStepSkipped = { link = 'Comment' },
  },
  ---@module 'nui.split'
  ---@type nui_split_options
  split = {
    relative = 'editor',
    position = 'right',
    size = 60,
    win_options = {
      wrap = false,
      number = false,
      foldlevel = nil,
      foldcolumn = '0',
      cursorcolumn = false,
      signcolumn = 'no',
    },
  },
}

local M = {
  options = defaultConfig,
}

---@param opts? pipeline.Config
function M.setup(opts)
  opts = opts or {}

  M.options = vim.tbl_deep_extend('force', defaultConfig, opts)
  M.options.allowed_hosts = M.options.allowed_hosts or {}
  table.insert(M.options.allowed_hosts, 'github.com')
  table.insert(M.options.allowed_hosts, 'gitlab.com')
end

function M.is_host_allowed(host)
  for _, allowed_host in ipairs(M.options.allowed_hosts) do
    if host == allowed_host then
      return true
    end
  end

  return false
end

---@param provider string
---@param host string
function M.resolve_host_for(provider, host)
  return M.options.providers[provider]
      and M.options.providers[provider].resolve_host
      and M.options.providers[provider].resolve_host(host)
    or M.options.providers[provider].default_host
end

return M
