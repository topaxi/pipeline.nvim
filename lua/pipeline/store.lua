local utils = require('pipeline.utils')

---@class pipeline.StatePipelineConfig
---@field last_read integer
---@field config table

---@class pipeline.State
---@field repo string
---@field server string
---@field error string|nil
---@field pipelines pipeline.Pipeline[]
---@field runs table<integer | string, pipeline.Run[]> Runs indexed by pipeline id
---@field jobs table<integer | string, pipeline.Job[]> Jobs indexed by run id
---@field steps table<integer | string, pipeline.Step[]> Steps indexed by job id
---@field workflow_configs table<integer, pipeline.StatePipelineConfig>
local initialState = {
  repo = '',
  server = '',
  error = nil,
  pipelines = {},
  latest_run = nil,
  runs = {},
  jobs = {},
  steps = {},
  workflow_configs = {},
}

---@class pipeline.ReadonlyStore
---@field get_state fun(): pipeline.State

---@class pipeline.Store: pipeline.ReadonlyStore
---@field package _state pipeline.State
---@field package _update fun(state: pipeline.State)[]
local M = {
  _state = initialState,
  _update = {},
}

---@param state pipeline.State
local function emit_update(state)
  for _, update in ipairs(M._update) do
    update(state)
  end
end

emit_update = utils.debounced(emit_update)

---@param fn fun(render_state: pipeline.State): pipeline.State|nil
function M.update_state(fn)
  M._state = fn(M._state) or M._state

  emit_update(M._state)
end

---@param fn function<pipeline.State>
function M.on_update(fn)
  table.insert(M._update, fn)
end

---@param fn function<pipeline.State>
function M.off_update(fn)
  M._update = vim.tbl_filter(function(f)
    return f ~= fn
  end, M._update)
end

---@return pipeline.State
function M.get_state()
  return M._state
end

return M
