require "items_config_fingerprint"

local core = require "me_manager_core"
local term = require "term"

local managercl = {}

function managercl:selectChestItems()
	local views = core:chestItems()
		term.clear()
		for index, view in ipairs(views) do
			print(tostring(index) .. "\t" .. view.amount .. "\t" .. view.title)
		end
		print("Enter 0 to cancel item adding")
		local selected = tonumber(term.read())
		if selected == 0 then return end
		managercl:addItem(selected)
end

function managercl:addItem(index)
	if index == nil then managercl:selectChestItems() return end

	local item = core:chestItem(index)
	local fingerprint = ItemsConfigFingerprint:new(item.id,item. damage, item.nbtHash, item.title)
	local config = {}

	print("Enter critical level (may be empty)")
	local criticalLevel = tonumber(term.read())
	if criticalLevel ~= nil and criticalLevel >= 0 then 
		config.problem = criticalLevel
	end

	::enter_warning::
	print("Enter warning level (may be empty)")
	local warningLevel = tonumber(term.read())
	if warningLevel ~= nil and warningLevel >= 0 then 
		if warningLevel <= criticalLevel then
			print("Warning level should be biger then critical")
			goto enter_warning
		else
			config.warning = warningLevel
		end
	end

	print("Enter DESTROY level (may be empty)")
	local destroyLevel = tonumber(term.read())
	if destroyLevel ~= nil and destroyLevel >= 0 then 
		print("Please enter \'destroy\' to aaprove destory level")
		local code = term.read():sub(1, -2)
		if code == "destroy" then
			config.destroy = destroyLevel
		end
	end

	print("Would you add autocrafting? (y/n)")
	local addAutocraft = term.read():sub(1, -2)
	if addAutocraft == "y" or addAutocraft == "Y" then
		local craft = {}
		print("Enter item autocraft limit")
		craft.limit = tonumber(term.read())
		print("Autocraft priority. 1(lower) is default")
		craft.priority = tonumber(term.read()) or 1
		print("Enter autocraft max portion (may be empty)")
		craft.portion = tonumber(term.read())

		config.craft = craft
	end

	core:setItemConfig(fingerprint, config)
end

return managercl