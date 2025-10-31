-- Minimal timer with after/every/update
local Timer = { _tasks = {} }

local function addTask(task)
  table.insert(Timer._tasks, task)
  return function() task.removed = true end
end

function Timer.after(t, func)
  return addTask({ time = t, interval = t, action = func, every = false, removed = false })
end

function Timer.every(t, func)
  return addTask({ time = t, interval = t, action = func, every = true, removed = false })
end

function Timer.update(dt)
  for i = #Timer._tasks, 1, -1 do
    local task = Timer._tasks[i]
    if task.removed then
      table.remove(Timer._tasks, i)
    else
      task.time = task.time - dt
      if task.time <= 0 then
        task.action()
        if task.every and not task.removed then
          task.time = task.time + task.interval
        else
          table.remove(Timer._tasks, i)
        end
      end
    end
  end
end

function Timer.clear()
  Timer._tasks = {}
end

return Timer

