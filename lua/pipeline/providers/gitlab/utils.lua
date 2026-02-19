---@class pipeline.providers.gitlab.Utils
local M = {}

---@param server string
---@return string|nil
local function get_token_from_glab_cli(server)
  local has_glab_installed = vim.fn.executable('glab') == 1
  if not has_glab_installed then
    return nil
  end

  local args = { 'glab', 'config', 'get', 'token', '--host', server }

  local res = vim.fn.system(args)
  local token = string.gsub(res or '', '\n', '')

  if token == '' then
    return nil
  end

  return token
end

---@param server string
---@return string, string
function M.get_gitlab_token(server)
  local token = vim.env.GITLAB_TOKEN

  if token then
    return token, 'env'
  end

  token = get_token_from_glab_cli(server)

  if token then
    return token, 'glab'
  end

  -- TODO: We could also ask for the token here via nui and store it ourselves
  assert(nil, 'No GITLAB_TOKEN found in env and no glab cli config found')
end

return M
