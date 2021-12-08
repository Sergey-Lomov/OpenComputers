require 'utils'
require 'gradient_animator'

local event = require 'event'
local component = require 'component'

local setupColor = 0x6666FF
local emptyColor = 0x000000
local pullWaiting = 0.01

local animator = {
	gradient = nil,
	duration = 10,
	lambs = {}
}

function animator:setupLambs()
	if self.gradient == nil then
		print("Please set gradient first")
		return
	end

	local lambs = component.list("thermalexpansion_light")
	local proxies = {}
	for id, _ in pairs(lambs) do
		local proxy = component.proxy(id)
		proxy.setColor(emptyColor)
		table.insert(proxies, proxy)
	end

	self.lambs = {}
	for _, proxy in ipairs(proxies) do
		proxy.setColor(setupColor)
		
		local displacement = nil
		while displacement == nil do
			print("Enter time displacement for selected lamb")
			displacement = tonumber(term.read())
		end

		local gradientAnimator = GradientAnimator:new(self.gradient, self.duration, displacement)
		self.lambs[proxy] = gradientAnimator
		
		proxy.setColor(emptyColor)
	end
end

function animator:updateGradient()
	if self.gradient == nil then
		print("Please set gradient first")
		return
	end

	for lamb, oldAnimator in pairs(self.lambs) do
		self.lambs[lamb] = GradientAnimator:new(self.gradient, self.duration, oldAnimator.timeDisplacement)
	end
end

function animator:start()
	local show = true
	print("Animation started. Press any key to stop.")
	while show do
		show = event.pull(pullWaiting, "key_up") == nil
		for lamb, gradient in pairs(self.lambs) do
			lamb.setColor(gradient:getValue())
		end
	end
end

return animator