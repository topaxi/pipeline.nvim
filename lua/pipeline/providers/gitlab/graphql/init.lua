local utils = require('pipeline.utils')
local Provider = require('pipeline.providers.polling')

local function git()
  return require('pipeline.git')
end

local function glab_api()
  return require('pipeline.providers.gitlab.graphql._api')
end

---@class pipeline.providers.gitlab.graphql.Options: pipeline.providers.polling.Options
---@field refresh_interval? number
local defaultOptions = {
  refresh_interval = 10,
}

---@class pipeline.providers.gitlab.graphql.Provider: pipeline.providers.polling.Provider
---@field protected opts pipeline.providers.gitlab.graphql.Options
---@field private server string
---@field private repo string
local GitlabGraphQLProvider = Provider:extend()

function GitlabGraphQLProvider.detect()
  if not utils.file_exists_in_git_root('.gitlab-ci.yml') then
    return false
  end

  if vim.fn.executable('glab') == 0 then
    return false
  end

  local Config = require('pipeline.config')
  local server, repo = git().get_current_repository()
  if server == Config.options.providers.github.default_host then
    return false
  end
  server = Config.resolve_host_for('gitlab', server)

  if not Config.is_host_allowed(server) then
    return
  end

  return server ~= nil and repo ~= nil
end

---@param opts pipeline.providers.github.rest.Options
function GitlabGraphQLProvider:init(opts)
  self.opts = vim.tbl_deep_extend('force', defaultOptions, opts)

  Provider.init(self, self.opts)

  local Config = require('pipeline.config')
  local server, repo = git().get_current_repository()

  self.server = Config.resolve_host_for('gitlab', server)
  self.repo = repo

  self.store.update_state(function(state)
    state.title = string.format('Gitlab Pipelines for %s', repo)
    state.server = self.server
    state.repo = self.repo
  end)
end

function GitlabGraphQLProvider:poll()
  self:fetch()
end

function GitlabGraphQLProvider:fetch()
  local Mapper = require('pipeline.providers.gitlab.graphql._mapper')

  glab_api().get_project_pipelines(
    self.server,
    self.repo,
    10,
    function(response)
      if
        utils.is_nil(response.data)
        or type(response.data.project) == 'userdata'
      then
        -- TODO: Handle errors
        return
      end

      local pipeline = Mapper.to_pipeline(response.data.project)
      local runs = {
        [pipeline.pipeline_id] = vim.tbl_map(function(node)
          return Mapper.to_run(pipeline.pipeline_id, node)
        end, response.data.project.pipelines.nodes),
      }
      local jobs = utils.group_by(
        function(job)
          return job.run_id
        end,
        vim
          .iter(response.data.project.pipelines.nodes)
          :map(function(node)
            return vim.tbl_map(function(job)
              return Mapper.to_job(node.id, job)
            end, node.jobs.nodes)
          end)
          :flatten()
          :totable()
      )

      self.store.update_state(function(state)
        state.pipelines = { pipeline }
        state.latest_run = runs[pipeline.pipeline_id][1]
        state.runs = runs
        state.jobs = jobs
      end)
    end
  )
end

---@param pipeline pipeline.providers.gitlab.graphql.Pipeline|nil
function GitlabGraphQLProvider:dispatch(pipeline)
  if not pipeline then
    return
  end

  if pipeline then
    vim.notify(
      'Gitlab Pipeline dispatch is not yet implemented',
      vim.log.levels.INFO
    )
  end
end

return GitlabGraphQLProvider
