-- In-process event bus for non-saved happenings (discoveries, captures) that other systems listen to.

local GameEvents = {}

local listeners: { [string]: { (...any) -> () } } = {}

function GameEvents.On(name: string, callback: (...any) -> ()): () -> ()
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	table.insert(list, callback)
	return function()
		local index = table.find(list, callback)
		if index then
			table.remove(list, index)
		end
	end
end

function GameEvents.Fire(name: string, ...: any)
	local list = listeners[name]
	if not list then
		return
	end
	for _, callback in table.clone(list) do
		task.spawn(callback, ...)
	end
end

return GameEvents
