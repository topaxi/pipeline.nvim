local M = {}

local pipelines_with_jobs_query = [[
  query ($repo: ID!, $limit: Int!) {
    project(fullPath: $repo) {
      id
      ciConfigPathOrDefault
      pipelines(first: $limit) {
        nodes {
          id
          name
          commit {
            message
          }
          path
          cancelable
          retryable
          createdAt
          status
          jobs {
            nodes {
              id
              name
              status
              manualJob
              retryable
              cancelable
              stage {
                name
              }
              webPath
            }
          }
        }
      }
    }
  }
]]

local function gl_utils()
  return require('pipeline.providers.gitlab.utils')
end

---@param host string
---@param query string
---@param variables table
---@param callback fun(err: string|nil, response: table|nil)
local function graphql_request(host, query, variables, callback)
  local url = string.format('https://%s/api/graphql', host)

  local token = gl_utils().get_gitlab_token(host)

  local curl = require('plenary.curl')

  curl.post(url, {
    headers = {
      Authorization = string.format('Bearer %s', token),
      ['Content-Type'] = 'application/json',
    },
    body = vim.json.encode { query = query, variables = variables },
    callback = vim.schedule_wrap(function(response)
      if not response or not response.body then
        callback('No response body', nil)
        return
      end
      local ok, decoded = pcall(vim.json.decode, response.body)
      if not ok then
        callback('Failed to decode response: ' .. tostring(decoded), nil)
        return
      end
      callback(nil, decoded)
    end),
    on_error = vim.schedule_wrap(function(err)
      callback(tostring(err), nil)
    end),
  })
end

---@alias pipeline.providers.gitlab.graphql.CiJobStatus 'CANCELED'|'CANCELING'|'CREATED'|'FAILED'|'MANUAL'|'PENDING'|'PREPARING'|'RUNNING'|'SCHEDULED'|'SKIPPED'|'SUCCESS'|'WAITING_FOR_CALLBACK'|'WAITING_FOR_RESOURCE'
---@alias pipeline.providers.gitlab.graphql.PipelineStatus 'CREATED'|'WAITING_FOR_RESOURCE'|'PREPARING'|'WAITING_FOR_CALLBACK'|'PENDING'|'RUNNING'|'FAILED'|'SUCCESS'|'CANCELED'|'CANCELING'|'SKIPPED'|'MANUAL'|'SCHEDULED'

---@class pipeline.providers.gitlab.graphql.QueryResponseJob
---@field id string
---@field name string
---@field status pipeline.providers.gitlab.graphql.CiJobStatus
---@field manualJob boolean
---@field retryable boolean
---@field cancelable boolean
---@field stage { name: string }
---@field webPath string

---@class pipeline.providers.gitlab.graphql.QueryResponsePipeline
---@field id string
---@field name string|nil
---@field commit { message: string }
---@field path string
---@field cancelable boolean
---@field retryable boolean
---@field createdAt string
---@field status pipeline.providers.gitlab.graphql.PipelineStatus
---@field jobs { nodes: pipeline.providers.gitlab.graphql.QueryResponseJob[] }

---@class pipeline.providers.gitlab.graphql.QueryResponseProject
---@field id string
---@field ciConfigPathOrDefault string
---@field pipelines { nodes: pipeline.providers.gitlab.graphql.QueryResponsePipeline[] }

---@class pipeline.providers.gitlab.graphql.QueryResponse
---@field data { project: pipeline.providers.gitlab.graphql.QueryResponseProject }

---@param host string
---@param repo string
---@param limit number
---@param callback fun(response: pipeline.providers.gitlab.graphql.QueryResponse)
function M.get_project_pipelines(host, repo, limit, callback)
  graphql_request(
    host,
    pipelines_with_jobs_query,
    { repo = repo, limit = limit },
    function(err, response)
      if err then
        error(err)
        return
      end
      callback(response)
    end
  )
end

return M
