-- Hub kiosks (GDD 4.1): triggering a kiosk's proximity prompt opens the menu named by its
-- OpensMenu attribute, the same as pressing that HUD button.

local ProximityPromptService = game:GetService("ProximityPromptService")

local KioskController = {}

function KioskController.Start(openers: { [string]: () -> () })
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local menu = prompt:GetAttribute("OpensMenu")
		local open = type(menu) == "string" and openers[menu]
		if open then
			open()
		end
	end)
end

return KioskController
