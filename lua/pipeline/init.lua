local M = {
  init_root = '',
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
  if M.pipeline then
    return
  end

  local Config = require('pipeline.config')
  local store = require('pipeline.store')

  for provider, provider_options in pairs(Config.options.providers) do
    local Provider = require('pipeline.providers')[provider]

    if Provider.detect() then
      M.pipeline = Provider:new(Config.options, store, provider_options)
      break
    end
  end

  if not M.pipeline then
    M.pipeline =
      require('pipeline.providers.provider'):new(Config.options, store)
  end
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
