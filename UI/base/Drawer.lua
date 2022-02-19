Drawer = {
	gpu = nil,
}
Drawer.__index = Drawer

function Drawer:new(gpu)
	if type == nil then
		error("Missed gpu on drawer creation")
	end

	local drawer = {}
	setmetatable(drawer, self)

	drawer.gpu = gpu
	drawer.offset = {x = 0, y = 0}

	return drawer
end

function Drawer:increaseOffset(x, y)
	self.offset.x = self.offset.x + x
	self.offset.y = self.offset.y + y
end

function Drawer:decreaseOffset(x, y)
	self.offset.x = self.offset.x - x
	self.offset.y = self.offset.y - y
end

function Drawer:drawBackRect(rect, color)
	local initialColor = self.gpu.getBackground()
	self.gpu.setBackground(color)
	self.gpu.fill(rect.x + self.offset.x, rect.y + self.offset.y, rect.width, rect.height, " ")
	self.gpu.setBackground(initialColor)
end

function Drawer:drawText(x, y, text, backColor, frontColor)
	self.gpu.setBackground(backColor)
	self.gpu.setForeground(frontColor)
	self.gpu.set(x + self.offset.x, y + self.offset.y, text)
end