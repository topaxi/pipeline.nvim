---@class pipeline.providers.gitlab.graphql.Mapper
local M = {}

---@type table<pipeline.providers.gitlab.graphql.CiJobStatus|pipeline.providers.gitlab.graphql.PipelineStatus, pipeline.Status>
local status_map = {
  CANCELED = 'completed',
  CANCELING = 'waiting',
  CREATED = 'pending',
  FAILED = 'completed',
  MANUAL = 'manual',
  PENDING = 'pending',
  PREPARING = 'queued',
  RUNNING = 'in_progress',
  SCHEDULED = 'queued',
  SKIPPED = 'completed',
  SUCCESS = 'completed',
  WAITING_FOR_CALLBACK = 'waiting',
  WAITING_FOR_RESOURCE = 'waiting',
}

---@type table<pipeline.providers.gitlab.graphql.CiJobStatus|pipeline.providers.gitlab.graphql.PipelineStatus, pipeline.Conclusion>
local conclusion_map = {
  CANCELED = 'cancelled',
  CANCELING = 'cancelled',
  CREATED = 'unknown',
  FAILED = 'failure',
  MANUAL = 'unknown',
  PENDING = 'unknown',
  PREPARING = 'unknown',
  RUNNING = 'unknown',
  SCHEDULED = 'unknown',
  SKIPPED = 'skipped',
  SUCCESS = 'success',
  WAITING_FOR_CALLBACK = 'unknown',
  WAITING_FOR_RESOURCE = 'unknown',
}

---@param status pipeline.providers.gitlab.graphql.CiJobStatus|pipeline.providers.gitlab.graphql.PipelineStatus
---@return pipeline.Status
local function map_status(status)
  return status_map[status] or 'unknown'
end

---@param status pipeline.providers.gitlab.graphql.CiJobStatus|pipeline.providers.gitlab.graphql.PipelineStatus
---@return pipeline.Conclusion
local function map_conclusion(status)
  return conclusion_map[status] or 'unknown'
end

---@class pipeline.providers.gitlab.graphql.Pipeline: pipeline.Pipeline
---@field meta { ci_config_path: string }

---@param project pipeline.providers.gitlab.graphql.QueryResponseProject
---@return pipeline.providers.github.rest.Pipeline
function M.to_pipeline(project)
  return {
    pipeline_id = project.id,
    name = project.ciConfigPathOrDefault,
    meta = { ci_config_path = project.ciConfigPathOrDefault },
  }
end

---@param pipeline_id string
---@param pipeline pipeline.providers.gitlab.graphql.QueryResponsePipeline
---@return pipeline.Run
function M.to_run(pipeline_id, pipeline)
  return {
    run_id = pipeline.id,
    pipeline_id = pipeline_id,
    name = pipeline.commit.message:gsub('\n.*', ''),
    url = pipeline.path,
    status = map_status(pipeline.status),
    conclusion = map_conclusion(pipeline.status),
  }
end

---@param run_id string
---@param job pipeline.providers.gitlab.graphql.QueryResponseJob
---@return pipeline.Job
function M.to_job(run_id, job)
  return {
    job_id = job.id,
    run_id = run_id,
    name = job.name,
    status = map_status(job.status),
    conclusion = map_conclusion(job.status),
  }
end

return M
