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
    github = {},
    gitlab = {},
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
  ---@class pipeline.config.Highlights
  highlights = {
    ---@type vim.api.keyset.highlight
    PipelineError = { link = 'DiagnosticError' },
    ---@type vim.api.keyset.highlight
    PipelineRunIconSuccess = { link = 'DiagnosticOk' },
    ---@type vim.api.keyset.highlight
    PipelineRunIconFailure = { link = 'DiagnosticError' },
    ---@type vim.api.keyset.highlight
    PipelineRunIconStartup_failure = { link = 'DiagnosticError' },
    ---@type vim.api.keyset.highlight
    PipelineRunIconPending = { link = 'DiagnosticWarn' },
    ---@type vim.api.keyset.highlight
    PipelineRunIconRequested = { link = 'DiagnosticWarn' },
    ---@type vim.api.keyset.highlight
    PipelineRunIconWaiting = { link = 'DiagnosticWarn' },
    ---@type vim.api.keyset.highlight
    PipelineRunIconIn_progress = { link = 'DiagnosticWarn' },
    ---@type vim.api.keyset.highlight
    PipelineRunIconCancelled = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    PipelineRunIconSkipped = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    PipelineRunCancelled = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    PipelineRunSkipped = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    PipelineJobCancelled = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    PipelineJobSkipped = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    PipelineStepCancelled = { link = 'Comment' },
    ---@type vim.api.keyset.highlight
    PipelineStepSkipped = { link = 'Comment' },
  },
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

return M
