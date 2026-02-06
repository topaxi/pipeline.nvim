describe('get_current_repository parsing', function()
  local git = require('pipeline.git')

  local cases = {
    {
      url = 'https://github.com/nvim-org/repo.nvim',
      server = 'github.com',
      repo = 'nvim-org/repo.nvim',
    },
    {
      url = 'git@github.com:some-org/some-repo.git',
      server = 'github.com',
      repo = 'some-org/some-repo',
    },
    {
      url = 'https://git.example.com/org/project/subgroup/app',
      server = 'git.example.com',
      repo = 'org/project/subgroup/app',
    },
    {
      url = 'git@git.example.com:org/project/subgroup/app.git',
      server = 'git.example.com',
      repo = 'org/project/subgroup/app',
    },
    {
      url = 'ssh://git@git.example.com/org/project/subgroup/app.git',
      server = 'git.example.com',
      repo = 'org/project/subgroup/app',
    },
  }

  for _, case in ipairs(cases) do
    it('parses ' .. case.url, function()
      local server, repo = git._parse_origin_url(case.url)

      assert.are.same(case.server, server)
      assert.are.same(case.repo, repo)
    end)
  end
end)
