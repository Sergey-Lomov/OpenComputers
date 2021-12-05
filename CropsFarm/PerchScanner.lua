component = require("component")
term = require("term")

Colors = {
    critical = 0xFF0000,
    gain = 0xAAAA00,
    growth = 0x00AA00,
    resistance = 0x00AAAA,
}

scanner = {}

function scanner:scan()
    term.clear()
    
    local gpu = term.gpu()
    gpu.setResolution(7, 3)
    
    while true do
        local haveCrop = false
        for k,_ in pairs(component) do
            if k == "tecrop" then
                haveCrop = true
            end
        end
        
        if not haveCrop then
            term.clear()
            gpu.setForeground(Colors.critical)  
            print("")
            print("  NONE")
        else
            local crop = component.tecrop
            local gain = crop.getGain()
            local growth = crop.getGrowth()
            local resistance = crop.getResistance()
            
            gpu.setForeground(Colors.gain)    
            print("Ga: " .. tostring(gain))
            gpu.setForeground(Colors.growth)    
            print("Gr: " .. tostring(growth))
            gpu.setForeground(Colors.resistance)    
            print("Res: " .. tostring(resistance))
        end
        
        os.sleep(1)
    end
end

return scanner