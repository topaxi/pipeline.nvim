local M = {}
local Config = require('pipeline.config')
local git = require('pipeline.git')
local utils = require('pipeline.utils')

function M.check()
  local health = vim.health

  health.start('Gitlab GraphQL provider')

  if not utils.file_exists_in_git_root('.gitlab-ci.yml') then
    health.ok('Skipping GitLab auth check (no .gitlab-ci.yml)')
    return
  end

  local remotes = git.get_remotes()
  local found_gitlab = false

  for _, remote in ipairs(remotes) do
    if remote.server ~= Config.options.providers.github.default_host then
      local host = Config.resolve_host_for('gitlab', remote.server)
      if Config.is_host_allowed(host) then
        found_gitlab = true
        local k, token, source = pcall(
          require('pipeline.providers.gitlab.utils').get_gitlab_token,
          host
        )

        if k and token then
          if source == 'env' then
            health.ok(
              string.format('Found GitLab token in env for %s', remote.name)
            )
          elseif source == 'glab' then
            health.ok(
              string.format(
                'Found GitLab token via glab cli for %s',
                remote.name
              )
            )
          else
            health.ok(string.format('Found GitLab token for %s', remote.name))
          end
        else
          health.error(
            string.format('No GitLab token found for %s', remote.name)
          )
        end
      else
        health.warn('Host not allowed: ' .. host)
      end
    end
  end

  if not found_gitlab then
    health.warn('Unable to resolve gitlab host from any remote')
  end
end

return M
