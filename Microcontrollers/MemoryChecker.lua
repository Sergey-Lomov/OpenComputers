sign = component.proxy(component.list("sign")())

while true do
	computer.pullSignal(1)
	local text = tostring(math.modf(computer.freeMemory() / 1000)) .. " / " .. tostring(math.modf(computer.totalMemory() / 1000))
	sign.setValue(sign)
end