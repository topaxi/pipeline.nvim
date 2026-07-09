---@meta

---@alias pipeline.Status 'pending'|'manual'|'queued'|'requested'|'waiting'|'in_progress'|'completed'|'unknown'
---@alias pipeline.Conclusion 'success'|'failure'|'cancelled'|'skipped'|'action_required'|'unknown'

---@class pipeline.BasePipelineObject
---@field name? string
---@field action? fun()
---@field url? string
---@field status? pipeline.Status
---@field conclusion? pipeline.Conclusion
---@field cancelable? boolean
---@field meta? table
---@package

---A pipeline definition, in Github terms, this would be a workflow.
---@class pipeline.Pipeline: pipeline.BasePipelineObject
---@field kind 'pipeline'
---@field pipeline_id string

---A run of a pipeline, in Github terms, this would be a workflow run.
---@class pipeline.Run: pipeline.BasePipelineObject
---@field kind 'run'
---@field run_id string
---@field pipeline_id string

---A job within a pipeline run.
---@class pipeline.Job: pipeline.BasePipelineObject
---@field kind 'job'
---@field job_id string
---@field run_id string

---A step within a job.
---@class pipeline.Step: pipeline.BasePipelineObject
---@field kind 'step'
---@field step_id string
---@field job_id string

---@alias pipeline.PipelineObject pipeline.Pipeline|pipeline.Run|pipeline.Job|pipeline.Step
