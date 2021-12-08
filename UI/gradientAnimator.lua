require 'gradient'
require 'utils'

GradientAnimator = {}

--[[ Create new gradient animator.
		gradient: Gradient object for animation
		animationDuration: How long whole graient should animate in sec
		timeDisplacement: Define gradient displacement in time
	]]--
function GradientAnimator:new(gradient, animationDuration, timeDisplacement)
	local animator = {}
	setmetatable(animator, self)
	self.__index = self
	
	animator.gradient = gradient
	animator.animationDuration = animationDuration
	animator.timeDisplacement = timeDisplacement
	
	return animator
end

function GradientAnimator:getValue()
	local timestamp = utils:realWorldSeconds() 
	local localTime = (timestamp + self.timeDisplacement) % self.animationDuration
	local position = localTime / self.animationDuration
	return self.gradient:getValue(position)
end