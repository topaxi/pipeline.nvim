local M = {}

function M.check()
  local health = vim.health

  health.start('Github REST provider')

  local k, token, source =
    pcall(require('pipeline.providers.github.utils').get_github_token)

  if k and token then
    if source == 'env' then
      health.ok('Found GitHub token in env')
    elseif source == 'gh' then
      health.ok('Found GitHub token via gh cli')
    else
      health.ok('Found GitHub token')
    end
  else
    health.error('No GitHub token found')
  end
end

return M
