local M = {
  init_root = '',
  ---@type { remote: pipeline.Remote, provider_name: string }[]
  available_remotes = {},
  ---@type pipeline.Provider|nil
  pipeline = nil,
}

---@param opts? pipeline.Config
function M.setup(opts)
  opts = opts or {}

  M.init_root = vim.fn.getcwd()

  require('pipeline.config').setup(opts)
  require('pipeline.ui').setup()
  require('pipeline.command').setup()

  M.setup_provider()
end

function M.setup_provider()
  if #M.available_remotes > 0 then
    return
  end

  local git = require('pipeline.git')
  local Config = require('pipeline.config')
  local remotes = git.get_remotes()

  -- Phase 1: Detect matching (remote, provider) pairs from local git data
  for _, remote in ipairs(remotes) do
    for provider_name, _ in pairs(Config.options.providers) do
      local Provider = require('pipeline.providers')[provider_name]

      if Provider.detect(remote) then
        table.insert(M.available_remotes, {
          remote = remote,
          provider_name = provider_name,
        })
        break -- one provider type per remote
      end
    end
  end

  -- Phase 2: Pick the best default and activate
  local selected = M.pick_default_remote()
  if selected then
    M.activate(selected)
  else
    local store = require('pipeline.store')
    M.pipeline =
      require('pipeline.providers.provider'):new(Config.options, store)
  end
end

---Pick the best remote to activate by default.
---Prefers origin for backwards compatibility, then first match.
---@return { remote: pipeline.Remote, provider_name: string }|nil
function M.pick_default_remote()
  if #M.available_remotes == 0 then
    return nil
  end

  -- Prefer origin for backwards compatibility
  for _, entry in ipairs(M.available_remotes) do
    if entry.remote.name == 'origin' then
      return entry
    end
  end

  -- Last resort: first match
  return M.available_remotes[1]
end

---Activate a specific remote as the current provider.
---Tears down any existing provider and creates a new one.
---@param entry { remote: pipeline.Remote, provider_name: string }
function M.activate(entry)
  -- Tear down existing provider if active
  if
    M.pipeline
    and M.pipeline.listener_count
    and M.pipeline.listener_count > 0
  then
    M.pipeline:disconnect()
  end

  local Config = require('pipeline.config')
  local store = require('pipeline.store')
  local Provider = require('pipeline.providers')[entry.provider_name]
  local provider_options = Config.options.providers[entry.provider_name]

  -- Reset store state for the new remote
  store.update_state(function(state)
    state.error = nil
    state.pipelines = {}
    state.runs = {}
    state.jobs = {}
    state.steps = {}
    state.workflow_configs = {}
  end)

  M.pipeline =
    Provider:new(Config.options, store, provider_options, entry.remote)
end

---Open a picker to select from available remotes.
function M.select_remote()
  if #M.available_remotes <= 1 then
    vim.notify('No other remotes available', vim.log.levels.INFO)
    return
  end

  local was_polling = M.pipeline
    and M.pipeline.listener_count
    and M.pipeline.listener_count > 0

  vim.ui.select(M.available_remotes, {
    prompt = 'Select remote',
    format_item = function(entry)
      return string.format(
        '%s (%s/%s)',
        entry.remote.name,
        entry.remote.server,
        entry.remote.repo
      )
    end,
  }, function(selected)
    if not selected then
      return
    end

    M.activate(selected)

    if was_polling then
      M.pipeline:listen()
    end
  end)
end

function M.start_polling()
  M.pipeline:listen()
end

function M.stop_polling()
  M.pipeline:close()
end

local function now()
  return os.time()
end

local WORKFLOW_CONFIG_CACHE_TTL_S = 10

---TODO We should run this after fetching the workflows instead of within the state update event
---@param state pipeline.State
function M.update_workflow_configs(state)
  local gh_utils = require('pipeline.providers.github.utils')
  local n = now()

  for _, pipeline in ipairs(state.pipelines) do
    if
      not state.workflow_configs[pipeline.pipeline_id]
      or (n - state.workflow_configs[pipeline.pipeline_id].last_read)
        > WORKFLOW_CONFIG_CACHE_TTL_S
    then
      state.workflow_configs[pipeline.pipeline_id] = {
        last_read = n,
        config = gh_utils.get_workflow_config(pipeline.meta.workflow_path),
      }
    end
  end
end

---@param pipeline_object pipeline.PipelineObject|nil
local function open_pipeline_url(pipeline_object)
  if not pipeline_object then
    return
  end

  if type(pipeline_object.url) ~= 'string' or pipeline_object.url == '' then
    return
  end

  require('pipeline.utils').open(pipeline_object.url)
end

function M.open()
  local ui = require('pipeline.ui')
  local store = require('pipeline.store')

  ui.open()
  ui.split:map('n', 'q', M.close, { noremap = true })

  ui.split:map('n', 'gp', function()
    open_pipeline_url(ui.get_pipeline())
  end, { noremap = true, desc = 'Open pipeline URL' })

  ui.split:map('n', 'gw', function()
    vim.notify(
      'Keybind gw to jump to workflow is deprecated, use gp instead',
      vim.log.levels.WARN
    )

    open_pipeline_url(ui.get_pipeline())
  end, { noremap = true, desc = 'Open pipeline URL (deprecated)' })

  ui.split:map('n', 'gr', function()
    open_pipeline_url(ui.get_run())
  end, { noremap = true, desc = 'Open pipeline run URL' })

  ui.split:map('n', 'gj', function()
    open_pipeline_url(ui.get_job())
  end, { noremap = true, desc = 'Open pipeline job URL' })

  ui.split:map('n', 'gs', function()
    open_pipeline_url(ui.get_step())
  end, { noremap = true, desc = 'Open pipeline step URL' })

  ui.split:map('n', 'gR', function()
    M.select_remote()
  end, { noremap = true, desc = 'Select remote' })

  ui.split:map('n', 'd', function()
    M.pipeline:dispatch(ui.get_pipeline())
  end, { noremap = true, desc = 'Dispatch pipeline run' })

  ui.split:map('n', 'rr', function()
    M.pipeline:retry(ui.get_run())
  end, { noremap = true, desc = 'Retry pipeline run' })

  ui.split:map('n', 'rj', function()
    M.pipeline:retry(ui.get_job())
  end, { noremap = true, desc = 'Retry pipeline job' })

  ui.split:map('n', 'rs', function()
    M.pipeline:retry(ui.get_step())
  end, { noremap = true, desc = 'Retry pipeline step' })

  M.start_polling()

  --TODO: This might get called after rendering..
  store.on_update(M.update_workflow_configs)
end

function M.close()
  local ui = require('pipeline.ui')
  local store = require('pipeline.store')

  ui.close()
  M.stop_polling()
  store.off_update(M.update_workflow_configs)
end

function M.toggle()
  local ui = require('pipeline.ui')

  if ui.split.winid then
    return M.close()
  else
    return M.open()
  end
end

return M
