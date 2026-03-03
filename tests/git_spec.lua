describe('parse_remote_url', function()
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
      local server, repo = git._parse_remote_url(case.url)

      assert.are.same(case.server, server)
      assert.are.same(case.repo, repo)
    end)
  end

  -- backwards-compat alias still works
  it('exposes _parse_origin_url alias', function()
    local server, repo =
      git._parse_origin_url('git@github.com:some-org/some-repo.git')

    assert.are.same('github.com', server)
    assert.are.same('some-org/some-repo', repo)
  end)
end)

describe('get_remotes', function()
  local git = require('pipeline.git')

  it('returns a list of pipeline.Remote entries', function()
    -- get_remotes runs real git commands; in a real repo this returns at
    -- least one entry.  We only validate the shape here since the actual
    -- remote URLs depend on the test environment.
    local remotes = git.get_remotes()
    assert.is_table(remotes)

    for _, remote in ipairs(remotes) do
      assert.is_string(remote.name)
      assert.is_string(remote.server)
      assert.is_string(remote.repo)
    end
  end)
end)
