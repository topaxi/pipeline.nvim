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

---@param job Job
local function create_job(job)
  return require('plenary.job'):new(job)
end

local function glab_graphql(query, variables, host)
  local args = {
    'api',
    'graphql',
    '-f',
    'query=' .. query,
  }

  if host and host ~= '' then
    table.insert(args, '--hostname')
    table.insert(args, host)
  end

  for key, value in pairs(variables) do
    table.insert(args, '-F')
    table.insert(args, key .. '=' .. value)
  end

  return create_job {
    command = 'glab',
    args = args,
  }
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

---@param host string|nil
---@param repo string
---@param limit number
---@param callback fun(response: pipeline.providers.gitlab.graphql.QueryResponse)
function M.get_project_pipelines(host, repo, limit, callback)
  local query_job = glab_graphql(
    pipelines_with_jobs_query,
    { repo = repo, limit = limit },
    host
  )

  query_job:start()
  query_job:after(function(job)
    callback(vim.json.decode(table.concat(job:result(), '')))
  end)
end

return M
