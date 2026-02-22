local function gh_utils()
  return require('pipeline.providers.github.utils')
end

---@alias plenary.curl.Error { message: string, stderr: string, exit: number }
---@package

---@class pipeline.providers.github.rest.Api
local M = {}

---@class pipeline.providers.github.rest.FetchOptions
---@field method? 'get'|'patch'|'post'|'put'|'delete'
---@field callback fun(err: plenary.curl.Error|nil, response: table|nil)

---@param server string
---@param path string
---@param opts pipeline.providers.github.rest.FetchOptions
local function fetch(server, path, opts)
  if vim.fn.has('nvim-0.11') == 1 then
    vim.validate('server', server, 'string')
    vim.validate('path', path, 'string')
    vim.validate('opts', opts, 'table', 'opts must be a table')
  else
    vim.validate {
      server = { server, 'string' },
      path = { path, 'string' },
      opts = { opts, 'table' },
    }
  end

  opts.callback = vim.schedule_wrap(opts.callback)

  local url = string.format('https://api.github.com%s', path)
  if server ~= 'github.com' then
    url = string.format('https://%s/api/v3%s', server, path)
  end

  local curl = require('plenary.curl')

  return curl[opts.method or 'get'](
    url,
    vim.tbl_deep_extend('force', opts, {
      headers = {
        Authorization = string.format(
          'Bearer %s',
          gh_utils().get_github_token(nil, server)
        ),
      },
      callback = function(response)
        opts.callback(nil, response)
      end,
      on_error = function(err)
        opts.callback(err, nil)
      end,
    })
  )
end

---@class pipeline.providers.github.rest.FetchJsonOptions: pipeline.providers.github.rest.FetchOptions
---@field map_response? fun(response: table): any

---@param server string
---@param path string
---@param opts pipeline.providers.github.rest.FetchJsonOptions
local function fetch_json(server, path, opts)
  return fetch(
    server,
    path,
    vim.tbl_extend('force', opts, {
      callback = function(err, response)
        if err then
          return opts.callback(err, nil)
        end

        if not response then
          return opts.callback({ message = 'No response body' }, nil)
        end

        if response.status >= 400 then
          return opts.callback(
            { message = string.format('HTTP %d', response.status) },
            nil
          )
        end

        local response_data = vim.json.decode(response.body)

        if opts.map_response then
          response_data = opts.map_response(response_data)
        end

        opts.callback(nil, response_data)
      end,
    })
  )
end

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

---@param server string
---@param repo string
---@param opts { callback: fun(error: plenary.curl.Error|nil, workflows: GhWorkflow[]): any }
function M.get_workflows(server, repo, opts)
  return fetch_json(
    server,
    string.format('/repos/%s/actions/workflows', repo),
    vim.tbl_deep_extend('force', opts, {
      ---@param response GhWorkflowsResponse
      map_response = function(response)
        return response.workflows
      end,
    })
  )
end

---@class GhCommit
---@field id string
---@field message string

---@class GhWorkflowRun
---@field id number
---@field name string
---@field status string
---@field conclusion string
---@field workflow_id number
---@field head_commit GhCommit
---@field url string
---@field html_url string

---@class GhWorkflowRunsResponse
---@field total_count number
---@field workflow_runs GhWorkflowRun[]

---@param server string
---@param repo string
---@param per_page? integer
---@param opts { callback: fun(err: plenary.curl.Error|nil, workflow_runs: GhWorkflowRun[]): any }
function M.get_repository_workflow_runs(server, repo, per_page, opts)
  return fetch_json(
    server,
    string.format('/repos/%s/actions/runs', repo),
    vim.tbl_deep_extend('force', { query = { per_page = per_page } }, opts, {
      ---@param response GhWorkflowRunsResponse
      map_response = function(response)
        return response.workflow_runs
      end,
    })
  )
end

---@param server string
---@param repo string
---@param workflow_id integer|string
---@param per_page? integer
---@param opts { callback: fun(err: plenary.curl.Error|nil, workflow_runs: GhWorkflowRun[]): any }
function M.get_workflow_runs(server, repo, workflow_id, per_page, opts)
  return fetch_json(
    server,
    string.format('/repos/%s/actions/workflows/%d/runs', repo, workflow_id),
    vim.tbl_deep_extend('force', { query = { per_page = per_page } }, opts, {
      ---@param response GhWorkflowRunsResponse
      map_response = function(response)
        return response.workflow_runs
      end,
    })
  )
end

---@class GhWorkflowDispatchResponse
---@field workflow_run_id integer
---@field run_url string
---@field html_url string

---@param server string
---@param repo string
---@param workflow_id integer|string
---@param ref string
---@param opts { body: table, callback?: fun(err: plenary.curl.Error|nil, response: GhWorkflowDispatchResponse|nil): any }
function M.dispatch_workflow(server, repo, workflow_id, ref, opts)
  return fetch_json(
    server,
    string.format(
      '/repos/%s/actions/workflows/%d/dispatches',
      repo,
      workflow_id
    ),
    vim.tbl_deep_extend('force', {}, opts, {
      method = 'post',
      body = vim.json.encode(
        vim.tbl_deep_extend('force', {}, opts.body or {}, {
          ref = ref,
          return_run_details = true,
        })
      ),
    })
  )
end

---@class GhWorkflowRunJobStep
---@field name string
---@field status string
---@field conclusion string
---@field number number

---@class GhWorkflowRunJob
---@field id number
---@field run_id number
---@field status string
---@field conclusion string
---@field name string
---@field steps GhWorkflowRunJobStep[]
---@field url string
---@field html_url string

---@class GhWorkflowRunJobsResponse
---@field total_count number
---@field jobs GhWorkflowRunJob[]

---@param server string
---@param repo string
---@param workflow_run_id integer
---@param per_page? integer
---@param opts { callback: fun(err: plenary.curl.Error|nil, workflow_runs: GhWorkflowRunJob[]): any }
function M.get_workflow_run_jobs(server, repo, workflow_run_id, per_page, opts)
  return fetch_json(
    server,
    string.format('/repos/%s/actions/runs/%d/jobs', repo, workflow_run_id),
    vim.tbl_deep_extend('force', { query = { per_page = per_page } }, opts, {
      ---@param response GhWorkflowRunJobsResponse
      map_response = function(response)
        return response.jobs
      end,
    })
  )
end

return M
