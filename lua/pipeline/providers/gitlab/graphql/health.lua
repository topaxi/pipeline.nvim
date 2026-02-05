local M = {}
local Config = require('pipeline.config')
local git = require('pipeline.git')

function M.check()
  local health = vim.health

  health.start('Gitlab GraphQL provider')

  if vim.fn.executable('glab') == 1 then
    health.ok('Found glab cli')

    local server = select(1, git.get_current_repository())
    if server then
      local host = Config.resolve_host_for('gitlab', server)
      if Config.is_host_allowed(host) then
        local output = vim.fn.system({
          'glab',
          'auth',
          'status',
          '--hostname',
          host,
        })
        if vim.v.shell_error == 0 then
          health.ok('glab authenticated for ' .. host)
        else
          health.error('glab not authenticated for ' .. host, output)
        end
      else
        health.warn('Host not allowed: ' .. host)
      end
    else
      health.warn('Unable to resolve gitlab host')
    end
  else
    health.error('glab cli not found')
  end
end

return M
