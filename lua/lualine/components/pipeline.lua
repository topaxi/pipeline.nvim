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

    return component.icons.get_workflow_run_icon(latest_run)
      .. ' '
      .. latest_run.name
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

  self.store = require('pipeline.store')
  self.icons = require('pipeline.utils.icons')

  local pipeline = require('pipeline')
  pipeline.setup_provider()

  if not pipeline.pipeline then
    return
  end

  pipeline.start_polling()

  self.store.on_update(function()
    require('lualine').refresh()
  end)
end

---@override
function Component:update_status()
  return self.options.format(self, self.store.get_state())
end

return Component
