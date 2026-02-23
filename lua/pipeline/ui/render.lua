local Config = require('pipeline.config')
local Buffer = require('pipeline.ui.buffer')
local utils = require('pipeline.utils')

---TODO: Shade background like https://github.com/akinsho/toggleterm.nvim/blob/2e477f7ee8ee8229ff3158e3018a067797b9cd38/lua/toggleterm/colors.lua

---@alias pipeline.RenderLocationKind 'pipeline'|'run'|'job'|'step'

---@class pipeline.RenderLocation
---@field value any
---@field kind pipeline.RenderLocationKind
---@field from? integer
---@field to? integer

---@class pipeline.Render:pipeline.ui.Buffer
---@field store pipeline.ReadonlyStore
---@field locations pipeline.RenderLocation[]
local PipelineRender = {
  locations = {},
}
PipelineRender.__index = setmetatable(PipelineRender, Buffer)

---@param run { status: string, conclusion: string }
---@return string
local function get_workflow_run_icon(run)
  if not run then
    return Config.options.icons.status.unknown
  end

  if run.status == 'completed' then
    return Config.options.icons.conclusion[run.conclusion] or run.conclusion
  end

  return Config.options.icons.status[run.status]
    or Config.options.icons.status.unknown
end

---@param run { status: string, conclusion: string }
---@param prefix string
---@return string|nil
local function get_status_highlight(run, prefix)
  if not run then
    return nil
  end

  if run.status == 'completed' then
    return 'Pipeline'
      .. utils.string.upper_first(prefix)
      .. utils.string.upper_first(run.conclusion)
  end

  return 'Pipeline'
    .. utils.string.upper_first(prefix)
    .. utils.string.upper_first(run.status)
end

---@param store pipeline.ReadonlyStore
---@return pipeline.Render
function PipelineRender.new(store)
  local self = setmetatable({}, PipelineRender)
  ---@cast self pipeline.Render

  Buffer.init(self, { indent = Config.options.indent })

  self.store = store

  return self
end

---@param bufnr integer
function PipelineRender:render(bufnr)
  self._lines = {}
  self.locations = {}

  local state = self.store:get_state()

  self:title(state)
  self:error(state)
  self:pipelines(state)
  self:trim()

  Buffer.render(self, bufnr)
end

--- Render title of the split window
---@param state pipeline.State
function PipelineRender:title(state)
  local title = 'pipeline.nvim'
  if state.repo and state.repo ~= '' then
    title = string.format('Pipelines for %s', state.repo)
  end
  self:append(title):nl():nl()
end

--- Render error message
---@param state pipeline.State
function PipelineRender:error(state)
  if state.error then
    self:append(state.error, 'PipelineError'):nl():nl()
  end
end

--- Render each pipeline
---@param state pipeline.State
function PipelineRender:pipelines(state)
  for _, pipeline in ipairs(state.pipelines) do
    self:pipeline(state, pipeline, state.runs[pipeline.pipeline_id] or {})
  end
end

---@param state pipeline.State
---@param pipeline pipeline.Pipeline
---@param runs pipeline.Run[]
function PipelineRender:pipeline(state, pipeline, runs)
  self:with_location({ kind = 'pipeline', value = pipeline }, function()
    local runs_n = math.min(5, #runs)

    self
      :status_icon(runs[1])
      :append(' ')
      :append(pipeline.name, get_status_highlight(runs[1], 'run'))
      :append(
        state.workflow_configs[pipeline.pipeline_id]
            and state.workflow_configs[pipeline.pipeline_id].config.on.workflow_dispatch
            and (' ' .. Config.options.icons.workflow_dispatch)
          or ''
      )
      :nl()

    -- TODO cutting down on how many we list here, as we fetch 100 overall repo
    -- runs on opening the split. I guess we do want to have this configurable.
    for _, run in ipairs { unpack(runs, 1, runs_n) } do
      self:run(state, run)
    end
  end)

  if #runs > 0 then
    self:nl()
  end
end

---@param state pipeline.State
---@param run pipeline.Run
function PipelineRender:run(state, run)
  self:with_location({ kind = 'run', value = run }, function()
    self
      :status_icon(run, { indent = 1 })
      :append(' ')
      :append(run.name, get_status_highlight(run, 'run'))
      :nl()

    if run.status ~= 'completed' then
      for _, job in ipairs(state.jobs[run.run_id] or {}) do
        self:job(state, job)
      end
    end
  end)
end

---@param state pipeline.State
---@param job pipeline.Job
function PipelineRender:job(state, job)
  self:with_location({ kind = 'job', value = job }, function()
    self
      :status_icon(job, { indent = 2 })
      :append(' ')
      :append(job.name, get_status_highlight(job, 'job'))
      :nl()

    if job.status ~= 'completed' and state.steps[job.job_id] then
      for _, step in ipairs(state.steps[job.job_id]) do
        self:step(step)
      end
    end
  end)
end

---@param step pipeline.Step
function PipelineRender:step(step)
  self:with_location({ kind = 'step', value = step }, function()
    self
      :status_icon(step, { indent = 3 })
      :append(' ')
      :append(step.name, get_status_highlight(step, 'step'))
      :nl()
  end)
end

---@param status { status: string, conclusion: string }
---@param opts? { indent?: number | nil }
function PipelineRender:status_icon(status, opts)
  opts = opts or {}

  self:append(
    get_workflow_run_icon(status),
    get_status_highlight(status, 'RunIcon'),
    opts
  )

  return self
end

---@param location pipeline.RenderLocation
function PipelineRender:append_location(location)
  table.insert(
    self.locations,
    vim.tbl_extend('keep', location, { to = self:get_current_line_nr() - 1 })
  )
end

---@param kind pipeline.RenderLocationKind
---@param line integer
function PipelineRender:get_location(kind, line)
  for _, loc in ipairs(self.locations) do
    if loc.kind == kind and line >= loc.from and line <= loc.to then
      return loc.value
    end
  end
end

---@param location pipeline.RenderLocation
---@param fn fun()
function PipelineRender:with_location(location, fn)
  local start_line_nr = self:get_current_line_nr()

  fn()

  self:append_location(
    vim.tbl_extend('keep', location, { from = start_line_nr })
  )
end

return PipelineRender
