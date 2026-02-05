---@class pipeline.lualine.Component
---@field protected super { init: fun(self: table, options: table) }
local Component = require('lualine.component'):extend()

---@class pipeline.lualine.ComponentOptions
local default_options = {
  icon = '',
  ---@param component pipeline.lualine.Component
  ---@param state pipeline.State
  ---@return string
  format = function(component, state)
    local latest_run = state.latest_run

    if not latest_run or not latest_run.status then
      return ''
    end

    return table.concat {
      -- TODO: Can't reuse normal hls, need to create them specifically for
      --       lualine first.
      --component:format_hl(PipelineRender.get_status_highlight(latest_run, 'run')),
      component:get_default_hl(),
      component.icons().get_workflow_run_icon(latest_run),
      component:get_default_hl(),
      ' ',
      latest_run.name,
    }
  end,

  on_click = function()
    require('pipeline').toggle()
  end,
}

---@override
---@param options pipeline.lualine.ComponentOptions
function Component:init(options)
  self.options = vim.tbl_deep_extend('force', default_options, options or {})

  Component.super.init(self, self.options)

  require('pipeline').start_polling()

  self.store().on_update(require('lualine').refresh)
end

---@package
function Component.store()
  return require('pipeline.store')
end

function Component.icons()
  return require('pipeline.utils.icons')
end

---@override
function Component:update_status()
  return self.options.format(self, self.store().get_state())
end

return Component
