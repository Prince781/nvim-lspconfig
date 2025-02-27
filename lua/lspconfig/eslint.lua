local configs = require 'lspconfig/configs'
local util = require 'lspconfig/util'
local lsp = vim.lsp

local get_eslint_client = function()
  local active_clients = lsp.get_active_clients()
  for _, client in ipairs(active_clients) do
    if client.name == 'eslint' then
      return client
    end
  end
  return nil
end
local function fix_all(opts)
  opts = opts or {}

  local eslint_lsp_client = get_eslint_client()
  if eslint_lsp_client == nil then
    return
  end

  local request
  if opts.sync or false then
    request = function(bufnr, method, params)
      eslint_lsp_client.request(method, params, nil, bufnr)
    end
  else
    request = function(bufnr, method, params)
      eslint_lsp_client.request_sync(method, params, nil, bufnr)
    end
  end

  local bufnr = util.validate_bufnr(opts.bufnr or 0)
  request(0, 'workspace/executeCommand', {
    command = 'eslint.applyAllFixes',
    arguments = {
      {
        uri = vim.uri_from_bufnr(bufnr),
        version = lsp.util.buf_versions[bufnr],
      },
    },
  })
end

local bin_name = 'vscode-eslint-language-server'
configs.eslint = {
  default_config = {
    cmd = { bin_name, '--stdio' },
    filetypes = {
      'javascript',
      'javascriptreact',
      'javascript.jsx',
      'typescript',
      'typescriptreact',
      'typescript.tsx',
      'vue',
    },
    -- https://eslint.org/docs/user-guide/configuring/configuration-files#configuration-file-formats
    root_dir = util.root_pattern(
      '.eslintrc.js',
      '.eslintrc.cjs',
      '.eslintrc.yaml',
      '.eslintrc.yml',
      '.eslintrc.json',
      'package.json'
    ),
    -- Refer to https://github.com/Microsoft/vscode-eslint#settings-options for documentation.
    settings = {
      validate = 'on',
      packageManager = 'npm',
      useESLintClass = false,
      codeActionOnSave = {
        enable = false,
        mode = 'all',
      },
      format = true,
      quiet = false,
      onIgnoredFiles = 'off',
      rulesCustomizations = {},
      run = 'onType',
      -- If nodePath is a non-null/undefined value the eslint LSP runs into runtime exceptions.
      --
      -- It's recommended not to change this.
      nodePath = '',
      -- Automatically determine working directory by locating .eslintrc config files.
      --
      -- It's recommended not to change this.
      workingDirectory = { mode = 'auto' },
      codeAction = {
        disableRuleComment = {
          enable = true,
          location = 'separateLine',
        },
        showDocumentation = {
          enable = true,
        },
      },
    },
    on_new_config = function(config, new_root_dir)
      -- The "workspaceFolder" is a VSCode concept. It limits how far the
      -- server will traverse the file system when locating the ESLint config
      -- file (e.g., .eslintrc).
      config.settings.workspaceFolder = {
        uri = new_root_dir,
        name = vim.fn.fnamemodify(new_root_dir, ':t'),
      }
    end,
    handlers = {
      ['eslint/openDoc'] = function(_, result)
        if not result then
          return
        end
        local sysname = vim.loop.os_uname().sysname
        if sysname:match 'Windows' then
          os.execute(string.format('start %q', result.url))
        else
          os.execute(string.format('open %q', result.url))
        end
      end,
      ['eslint/confirmESLintExecution'] = function(_, result)
        if not result then
          return
        end
        return 4 -- approved
      end,
      ['eslint/probeFailed'] = function()
        vim.notify('ESLint probe failed.', vim.log.levels.WARN)
      end,
      ['eslint/noLibrary'] = function()
        vim.notify('Unable to find ESLint library.', vim.log.levels.WARN)
      end,
    },
  },
  commands = {
    EslintFixAll = {
      function()
        fix_all { sync = true, bufnr = 0 }
      end,
      description = 'Fix all eslint problems for this buffer',
    },
  },
  docs = {
    description = [[
https://github.com/hrsh7th/vscode-langservers-extracted

vscode-eslint-language-server: A linting engine for JavaScript / Typescript

`vscode-eslint-language-server` can be installed via `npm`:
```sh
npm i -g vscode-langservers-extracted
```

vscode-eslint-language-server provides an EslintFixAll command that can be used to format document on save
```vim
autocmd BufWritePre <buffer> <cmd>EslintFixAll<CR>
```

See [vscode-eslint](https://github.com/microsoft/vscode-eslint/blob/55871979d7af184bf09af491b6ea35ebd56822cf/server/src/eslintServer.ts#L216-L229) for configuration options.

Additional messages you can handle: eslint/noConfig
Messages already handled in lspconfig: eslint/openDoc, eslint/confirmESLintExecution, eslint/probeFailed, eslint/noLibrary
]],
  },
}

configs.eslint.fix_all = fix_all
