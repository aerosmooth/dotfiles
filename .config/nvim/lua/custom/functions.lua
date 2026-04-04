-- Function to run code and display results in a notification
function RunCode()
  -- Set autochdir option
  vim.opt.autochdir = true

  -- Write the current buffer
  vim.cmd("write")

  -- Get the current file type and file name
  local filetype = vim.bo.filetype
  local current_file = vim.fn.expand("%:t")
  local py_command
  local command

  -- Function to check if Makefile exists
  local function makefile_exists()
    return vim.fn.filereadable("Makefile") == 1
  end

  -- Function to notify the user
  local function my_notify(message, level)
    vim.notify(message, level or vim.log.levels.INFO, { title = filetype:upper() .. " Execution" })
  end

  -- Function to append data to the buffer
  local output_data = {}
  local function my_append_to_buffer(data)
    if data then
      for _, line in ipairs(data) do
        table.insert(output_data, line)
      end
    end
  end

  if makefile_exists() then
    vim.cmd("make test")
    return
  else
    if filetype == "java" then
      command = string.format("javac %s && java %s", current_file, current_file:gsub("%.java$", ""))
    elseif filetype == "python" then
      if vim.fn.has("macunix") then
        py_command = "python"
      else
        py_command = "python3"
      end
      command = string.format("%s %s", py_command, current_file)
    elseif filetype == "c" then
      command = string.format(
        "gcc %s -o %s && ./%s",
        current_file,
        current_file:gsub("%.c$", ""),
        current_file:gsub("%.c$", "")
      )
    elseif filetype == "cpp" then
      command = string.format(
        "g++ %s -o %s && ./%s",
        current_file,
        current_file:gsub("%.cpp$", ""),
        current_file:gsub("%.cpp$", "")
      )
    elseif filetype == "javascript" then
      command = string.format("node %s", current_file)
    elseif filetype == "lua" then
      command = string.format("lua %s", current_file)
    elseif filetype == "sh" then
      command = string.format("zsh %s", current_file)
    elseif filetype == "rust" then
      command = string.format("rustc %s && ./%s", current_file, current_file:gsub("%.rs$", ""))
    else
      vim.notify("No run command configured for filetype: " .. filetype, vim.log.levels.ERROR)
      return
    end
  end

  -- Start the command as a job
  vim.fn.jobstart(command, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      my_append_to_buffer(data)
    end,
    on_stderr = function(_, data)
      my_append_to_buffer(data)
    end,
    on_exit = function(_, exit_code)
      local result_message = table.concat(output_data, "\n")
      if result_message:sub(-1) == "\n" then
        result_message = result_message:sub(1, -2)
      end
      if exit_code == 0 then
        my_notify(result_message)
      else
        my_notify(result_message .. "\nExecution failed with exit code: " .. exit_code, vim.log.levels.ERROR)
      end
    end,
  })

  -- Display the command being run
  my_notify("% " .. command)
end
