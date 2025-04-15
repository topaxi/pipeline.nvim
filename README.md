# pipeline.nvim

The pipeline.nvim plugin for Neovim allows developers to easily manage and dispatch their CI/CD Pipelines, like GitHub Actions or Gitlab CI, directly from within the editor.

<p align="center">
  <img src="https://user-images.githubusercontent.com/213788/234685256-e915dc9c-1d79-4d64-b771-be1f736a203b.png" alt="Screenshot of pipeline.nvim">
</p>

## CI/CD Platform Support

- [GitHub Actions](https://github.com/features/actions)
- [Gitlab CI/CD](https://docs.gitlab.com/ee/ci/) (fairly untested, feel free to
  report bugs or open PRs)

## Features

- List pipelines and their runs for the current repository
- Run/dispatch pipelines with `workflow_dispatch`

## ToDo

- Rerun a failed pipeline or job
- Configurable keybindings
- Allow to cycle between inputs on dispatch

## Installation

### Dependencies

Either have the cli [yq](https://github.com/mikefarah/yq) installed or:

- [GNU Make](https://www.gnu.org/software/make/)
- [Cargo](https://doc.rust-lang.org/cargo/)

Additionally, the Gitlab provider needs the [`glab`](https://docs.gitlab.com/ee/editor_extensions/gitlab_cli/) cli to be installed.

### lazy.nvim

Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'topaxi/pipeline.nvim',
  keys = {
    { '<leader>ci', '<cmd>Pipeline<cr>', desc = 'Open pipeline.nvim' },
  },
  -- optional, you can also install and use `yq` instead.
  build = 'make',
  ---@type pipeline.Config
  opts = {},
},
```

## Authentication

### GitHub

The plugin requires authentication with your GitHub account to access your workflows and runs. You can authenticate by running the `gh auth login command` in your terminal and following the prompts.

Alternatively, define a `GITHUB_TOKEN` variable in your environment.

### Gitlab

The plugin interacts with Gitlab via the `glab` cli, all that is needed is being authenticated through `glab auth login`.

## Usage

### Commands

- `:Pipeline` or `:Pipeline toggle` toggles the `pipeline.nvim` split
- `:Pipeline open` opens the `pipeline.nvim` split
- `:Pipeline close` closes the `pipeline.nvim` split

### Keybindings

The following keybindings are provided by the plugin:

- `q` - closes the `pipeline.nvim` the split
- `gp` - open the pipeline below the cursor on GitHub
- `gr` - open the run below the cursor on GitHub
- `gj` - open the job of the workflow run below the cursor on GitHub
- `d` - dispatch a new run for the workflow below the cursor on GitHub

### Options

The default options (as defined in [lua/config.lua](./blob/main/lua/pipeline/config.lua))

````lua
{
  --- The browser executable path to open workflow runs/jobs in
  browser = nil,
  --- Interval to refresh in seconds
  refresh_interval = 10,
  --- How much workflow runs and jobs should be indented
  indent = 2,
  providers = {
    github = {
      default_host = 'github.com',
      --- Mapping of names that should be renamed to resolvable hostnames
      --- names are something that you've used as a repository url,
      --- that can't be resolved by this plugin, like aliases from ssh config
      --- for example to resolve "gh" to "github.com"
      --- ```lua
      --- resolve_host = function(host)
      ---   if host == "gh" then
      ---     return "github.com"
      ---   end
      --- end
      --- ```
      --- Return nil to fallback to the default_host
      ---@param host string
      ---@return string|nil
      resolve_host = function(host)
        return host
      end,
    },
    gitlab = {
      default_host = 'gitlab.com',
      --- Mapping of names that should be renamed to resolvable hostnames
      --- names are something that you've used as a repository url,
      --- that can't be resolved by this plugin, like aliases from ssh config
      --- for example to resolve "gl" to "gitlab.com"
      --- ```lua
      --- resolve_host = function(host)
      ---   if host == "gl" then
      ---     return "gitlab.com"
      ---   end
      --- end
      --- ```
      --- Return nil to fallback to the default_host
      ---@param host string
      ---@return string|nil
      resolve_host = function(host)
        return host
      end,
    },
  },
  --- Allowed hosts to fetch data from, github.com is always allowed
  allowed_hosts = {},
  --- Configure which branch to use to dispatch workflow
  --- set to "default" to use the repository default branch
  --- set to "current" to use the branch you're currently checked out
  --- set to any valid branch name to use that branch
  --- @type string
  dispatch_branch = "default",
  icons = {
    workflow_dispatch = '⚡️',
    conclusion = {
      success = '✓',
      failure = 'X',
      startup_failure = 'X',
      cancelled = '⊘',
      skipped = '◌',
    },
    status = {
      unknown = '?',
      pending = '○',
      queued = '○',
      requested = '○',
      waiting = '○',
      in_progress = '●',
    },
  },
  highlights = {
    PipelineError = { link = 'DiagnosticError' },
    PipelineRunIconSuccess = { link = 'DiagnosticOk' },
    PipelineRunIconFailure = { link = 'DiagnosticError' },
    PipelineRunIconStartup_failure = { link = 'DiagnosticError' },
    PipelineRunIconPending = { link = 'DiagnosticWarn' },
    PipelineRunIconRequested = { link = 'DiagnosticWarn' },
    PipelineRunIconWaiting = { link = 'DiagnosticWarn' },
    PipelineRunIconIn_progress = { link = 'DiagnosticWarn' },
    PipelineRunIconCancelled = { link = 'Comment' },
    PipelineRunIconSkipped = { link = 'Comment' },
    PipelineRunCancelled = { link = 'Comment' },
    PipelineRunSkipped = { link = 'Comment' },
    PipelineJobCancelled = { link = 'Comment' },
    PipelineJobSkipped = { link = 'Comment' },
    PipelineStepCancelled = { link = 'Comment' },
    PipelineStepSkipped = { link = 'Comment' },
  },
  split = {
    relative = 'editor',
    position = 'right',
    size = 60,
    win_options = {
      wrap = false,
      number = false,
      foldlevel = nil,
      foldcolumn = '0',
      cursorcolumn = false,
      signcolumn = 'no',
    },
  },
}
````

## lualine integration

```lua
require('lualine').setup({
  sections = {
    lualine_a = {
      { 'pipeline' },
    },
  }
})
```

or with options:

```lua
require('lualine').setup({
  sections = {
    lualine_a = {
      -- with default options
      { 'pipeline', icon = '' },
    },
  }
})
```

## Credits

- [folke/lazy.nvim](https://github.com/folke/lazy.nvim) for the rendering approach
