local utils = require('pipeline.utils')
local Provider = require('pipeline.providers.polling')

local function gh_api()
  return require('pipeline.providers.github.rest._api')
end

---@class pipeline.providers.github.rest.Options: pipeline.providers.polling.Options
---@field refresh_interval? number
local defaultOptions = {
  refresh_interval = 10,
}

---@class pipeline.providers.github.rest.Provider: pipeline.providers.polling.Provider
---@field protected opts pipeline.providers.github.rest.Options
---@field private server string
---@field private repo string
local GithubRestProvider = Provider:extend()

---@param remote pipeline.Remote
---@return boolean
function GithubRestProvider.detect(remote)
  if not utils.file_exists_in_git_root('.github/workflows') then
    return false
  end

  local Config = require('pipeline.config')
  local server = Config.resolve_host_for('github', remote.server)

  if not Config.is_host_allowed(server) then
    return false
  end

  return server ~= nil and remote.repo ~= nil
end

---@param opts pipeline.providers.github.rest.Options
---@param remote pipeline.Remote
function GithubRestProvider:init(opts, remote)
  self.opts = vim.tbl_deep_extend('force', defaultOptions, opts)

  Provider.init(self, self.opts)

  local Config = require('pipeline.config')
  self.server = Config.resolve_host_for('github', remote.server)
  self.repo = remote.repo

  self.store.update_state(function(state)
    state.server = self.server
    state.repo = self.repo
  end)
end

function GithubRestProvider:poll()
  self:fetch()
end

--TODO Only periodically fetch all workflows
--     then fetch runs for a single workflow (tabs/expandable)
--     Maybe periodically fetch all workflow runs to update
--     "toplevel" workflow states
--TODO Maybe send lsp progress events when fetching, to interact
--     with fidget.nvim
function GithubRestProvider:fetch()
  self:fetch_workflows()
  self:fetch_runs()
end

---@package
function GithubRestProvider:fetch_workflows()
  local Mapper = require('pipeline.providers.github.rest._mapper')

  gh_api().get_workflows(self.server, self.repo, {
    callback = function(err, workflows)
      self.store.update_state(function(state)
        state.error = err and err.message or nil

        if not state.error and workflows then
          state.pipelines = vim.tbl_map(Mapper.to_pipeline, workflows)
        end
      end)
    end,
  })
end

---@package
function GithubRestProvider:fetch_runs()
  local Mapper = require('pipeline.providers.github.rest._mapper')

  gh_api().get_repository_workflow_runs(self.server, self.repo, 100, {
    callback = function(err, workflow_runs)
      ---@type pipeline.Run[]
      local runs = vim.tbl_map(Mapper.to_run, workflow_runs or {})
      ---@type pipeline.Run[]
      local old_runs = vim
        .iter(vim.tbl_values(self.store.get_state().runs))
        :flatten()
        :totable()

      self.store.update_state(function(state)
        state.error = err and err.message or nil

        if not state.error then
          state.latest_run = runs[1]
          state.runs = utils.group_by(function(run)
            return run.pipeline_id
          end, runs)
        end
      end)

      local running_workflows = utils.uniq(
        function(run)
          return run.run_id
        end,
        vim.tbl_filter(function(run)
          return run.status ~= 'completed' and run.status ~= 'skipped'
        end, { unpack(runs), unpack(old_runs) })
      )

      for _, run in ipairs(running_workflows) do
        self:fetch_jobs(run.run_id)
      end
    end,
  })
end

---@param run_id number
---@package
function GithubRestProvider:fetch_jobs(run_id)
  local Mapper = require('pipeline.providers.github.rest._mapper')

  gh_api().get_workflow_run_jobs(self.server, self.repo, run_id, 20, {
    callback = function(err, jobs)
      self.store.update_state(function(state)
        state.error = err and err.message or nil
        if not state.error then
          state.jobs[run_id] = vim.tbl_map(Mapper.to_job, jobs)

          for _, job in ipairs(jobs) do
            state.steps[job.id] = vim.tbl_map(function(step)
              return Mapper.to_step(job.id, step)
            end, job.steps)
          end
        end
      end)
    end,
  })
end

---@param pipeline pipeline.providers.github.rest.Pipeline|nil
function GithubRestProvider:dispatch(pipeline)
  if not pipeline then
    return
  end

  local store = require('pipeline.store')

  if pipeline then
    local Config = require('pipeline.config')

    -- TODO should we get current ref instead or show an input with the
    --      default branch or current ref preselected?
    local dispatch_branch = Config.get_dispatch_branch()
    ---@type pipeline.providers.github.WorkflowDef|nil
    local workflow_config =
      require('pipeline.yaml').read_yaml_file(pipeline.meta.workflow_path)

    if not workflow_config or not workflow_config.on.workflow_dispatch then
      return
    end

    ---@type pipeline.providers.github.WorkflowDef.DispatchInputs
    local inputs = {}

    if not utils.is_nil(workflow_config.on.workflow_dispatch) then
      ---@type pipeline.providers.github.WorkflowDef.DispatchInputs
      inputs = workflow_config.on.workflow_dispatch.inputs
    end

    local questions = {}
    local i = 0
    local input_values = vim.empty_dict()

    -- TODO: Would be great to be able to cycle back to previous inputs
    local function ask_next()
      i = i + 1

      if #questions > 0 and i <= #questions then
        questions[i]:mount()
      else
        gh_api().dispatch_workflow(
          self.server,
          self.repo,
          pipeline.pipeline_id,
          dispatch_branch,
          {
            body = { inputs = input_values or {} },
            callback = function(err, res)
              if err or not res then
                return
              end
              self:fetch_jobs(res.workflow_run_id)
            end,
          }
        )

        local function format_input_value(value)
          if type(value) == 'string' then
            if value:find('%s') then
              return string.format('%q', value)
            end

            return value
          end

          if type(value) == 'table' then
            local ok, encoded = pcall(vim.json.encode, value)
            if ok then
              return encoded
            end
          end

          return tostring(value)
        end

        local function format_input_values(values)
          if not values or vim.tbl_isempty(values) then
            return ''
          end

          local keys = vim.tbl_keys(values)
          table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
          end)

          local parts = {}
          for _, key in ipairs(keys) do
            local value = format_input_value(values[key])
            table.insert(parts, string.format('%s=%s', key, value))
          end

          return table.concat(parts, ', ')
        end

        if #questions == 0 then
          vim.notify(string.format('Dispatched %s', pipeline.name))
        else
          vim.notify(
            string.format(
              'Dispatched %s with %s',
              pipeline.name,
              format_input_values(input_values)
            )
          )
        end
      end
    end

    for name, input in pairs(inputs) do
      local prompt = string.format('%s: ', input.description or name)

      if input.type == 'choice' then
        local question = require('pipeline.ui.components.select') {
          prompt = prompt,
          title = pipeline.name,
          options = input.options,
          on_submit = function(value)
            input_values[name] = value.text
            ask_next()
          end,
        }

        question:on('BufLeave', function()
          question:unmount()
        end)

        table.insert(questions, question)
      else
        local question = require('pipeline.ui.components.input') {
          prompt = prompt,
          title = pipeline.name,
          default_value = tostring(input.default),
          on_submit = function(value)
            input_values[name] = value
            ask_next()
          end,
        }

        question:on('BufLeave', function()
          question:unmount()
        end)

        table.insert(questions, question)
      end
    end

    ask_next()
  end
end

return GithubRestProvider
