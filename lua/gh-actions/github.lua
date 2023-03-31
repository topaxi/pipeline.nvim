local curl = require("plenary.curl")
local job = require("plenary.job")

local M = {}

---@class GhWorkflow
---@field id number
---@field node_id string
---@field name string
---@field path string
---@field state string
---@field created_at string
---@field updated_at string
---@field url string
---@field html_url string
---@field badge_url string

---@class GhWorkflowsResponse
---@field total_count number
---@field workflows GhWorkflow[]

---@return string
local function read_gh_hosts_token()
  -- TODO: Can we not depend on `yq` for parsing yml?
  local yq = job:new({
    command = "yq",
    args = { "-o", "json", vim.fn.expand("$HOME/.config/gh/hosts.yml") },
  })

  yq:sync()

  local jsonStr = table.concat(yq:result(), "\n")
  local ghHostsConfig = vim.json.decode(jsonStr)

  return ghHostsConfig["github.com"].oauth_token
end

---@return string
local function get_github_token()
  return vim.env.GITHUB_TOKEN
    or read_gh_hosts_token()
    -- TODO: We could also ask for the token here via nui
    or assert(nil, "No GITHUB_TOKEN found in env and no gh cli config found")
end

---@param path string
function M.fetch(path)
  return curl.get(string.format("https://api.github.com%s", path), {
    headers = {
      Authorization = string.format("Bearer %s", get_github_token()),
    },
  })
end

---@param repo string
---@return GhWorkflow[]
function M.get_workflows(repo)
  local response = M.fetch(string.format("/repos/%s/actions/workflows", repo))

  if not response then
    return {}
  end

  ---@type GhWorkflowsResponse | nil
  local responseData = vim.json.decode(response.body)

  return responseData and responseData.workflows or {}
end

return M