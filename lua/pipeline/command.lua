local M = {}

local function handle_pipeline_command(a)
  local pipeline = require('pipeline')

  if a.name == 'GhActions' then
    vim.notify_once(
      'GhActions command is deprecated, use Pipeline instead',
      vim.log.levels.WARN
    )
  end

  local action = a.fargs[1] or 'toggle'

  if action == 'open' then
    return pipeline.open()
  elseif action == 'close' then
    return pipeline.close()
  elseif action == 'toggle' then
    return pipeline.toggle()
  elseif action == 'remote' then
    return pipeline.select_remote()
  end
end

local function completion_customlist()
  return {
    'open',
    'close',
    'toggle',
    'remote',
  }
end

function M.setup()
  vim.api.nvim_create_user_command('Pipeline', handle_pipeline_command, {
    nargs = '?',
    complete = completion_customlist,
  })
  vim.api.nvim_create_user_command('GhActions', handle_pipeline_command, {
    nargs = '?',
    complete = completion_customlist,
  })
end

return M
