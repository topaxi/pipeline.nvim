local M = {}
local Config = require('pipeline.config')
local git = require('pipeline.git')
local utils = require('pipeline.utils')

function M.check()
  local health = vim.health

  health.start('Gitlab GraphQL provider')

  if utils.file_exists_in_git_root('.gitlab-ci.yml') then
    local server = select(1, git.get_current_repository())
    if server then
      local host = Config.resolve_host_for('gitlab', server)
      if Config.is_host_allowed(host) then
        local k, token, source = pcall(
          require('pipeline.providers.gitlab.utils').get_gitlab_token,
          host
        )

        if k and token then
          if source == 'env' then
            health.ok('Found GitLab token in env')
          elseif source == 'glab' then
            health.ok('Found GitLab token via glab cli')
          else
            health.ok('Found GitLab token')
          end
        else
          health.error('No GitLab token found')
        end
      else
        health.warn('Host not allowed: ' .. host)
      end
    else
      health.warn('Unable to resolve gitlab host')
    end
  else
    health.ok('Skipping GitLab auth check (no .gitlab-ci.yml)')
  end
end

return M
