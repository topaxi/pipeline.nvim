--# selene: allow(unused_variable)

--- Generic class for all providers
---
--- We assume the following is true for most ci/cd systems:
--- 1. There's multiple different pipelines defined
---   - Github calls these Workflow
---   - Gitlab calls these Pipeline
---   - We call it Pipeline
--- 2. Each pipeline trigger an instance of a pipeline run
---   - Github calls these WorkflowRun
---   - Gitlab calls these Pipeline (they don't seem to have a different
---     terminology for the pipeline definition and a pipeline run)
---   - We call it Run
--- 3. Each pipeline has multiple jobs
---   - We all call these Job
--- 4. Each job has a name and multiple steps
---   - Github calls these Step with an optional name
---   - Gitlab has just a list of scripts
---   - We call it Step
---
--- Optionally, some providers have a concept of stages, ex. Gitlab, to group
--- jobs within a Pipeline. Groups can be used to sort/group these in the UI
--- tree.

---@class pipeline.Provider
---@field protected config pipeline.Config
---@field protected store pipeline.Store
---@field private listener_count integer
local Provider = {}
Provider.__index = Provider

---@return pipeline.Provider
function Provider:extend()
  local Class = setmetatable({}, self)
  Class.__index = Class
  return Class
end

---Detect whether this provider handles the given remote.
---@param remote pipeline.Remote
---@return boolean
function Provider.detect(remote)
  vim.notify_once('Provider does not implement detect', vim.log.levels.WARN)

  return false
end

---@generic T: pipeline.Provider
---@param config pipeline.Config
---@param store pipeline.Store
---@param opts? table
---@param remote? pipeline.Remote
---@return self
function Provider:new(config, store, opts, remote)
  local instance = setmetatable({}, self)
  instance.config = config
  instance.store = store
  instance.listener_count = 0
  instance:init(opts or {}, remote)
  return instance
end

---Constructor function, called when creating a new Provider instance.
---@param opts table
---@param remote? pipeline.Remote
function Provider:init(opts, remote) end

---Start fetching or listening to data from the provider.
function Provider:connect() end

---Stop fetching or listening to data from the provider.
function Provider:disconnect() end

---Dispatch a new pipeline run
---@param pipeline pipeline.Pipeline|nil
function Provider:dispatch(pipeline) end

---Retry a failed pipeline run/job/step
---@param pipeline_object pipeline.PipelineObject|nil
function Provider:retry(pipeline_object) end

function Provider:listen()
  if self.listener_count == 0 then
    self:connect()
  end
  self.listener_count = self.listener_count + 1
end

function Provider:close()
  self.listener_count = self.listener_count - 1
  if self.listener_count == 0 then
    self:disconnect()
  end
end

return Provider
