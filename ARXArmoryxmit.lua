-------------------------- DEFINE USER SLASH COMMANDS ------------------------

SLASH_ARXARMCAL1  = "/ARXArmorycalibrate"	-- used to place calibration pattern on the screen for 30 seconds
SLASH_ARXARMCAL2  = "/ARXArmorycal"

SLASH_ARXARMGO1 = "/ARXArmory"				-- show target's armory page

SLASH_ARXARMVERBOSE1 = "/ARXArmoryverbose"	-- echo each playor or NPC sent, follow with yes or no

-------------------------- ADD-ON GLOBALS ------------------------

ARXArmInCalibrationMode = 0					--  flag to suspend event processing (and update user message)
ARXArmCalCountdown = 0
ARXArmNeedToPlayDoneSound = false
--ARXArmoryVerboseMode	is defined as a Saved Variable in the .toc

-------------------------- THE SLASH COMMANDS EXECUTE CODE HERE ------------------------

SlashCmdList["ARXARMCAL"] = function(msg, theEditFrame)		--  calibrate
	ChatFrame1:AddMessage( "Calibration pattern set. Be sure WoW is in \"Windowed (fullscreen)\" mode.")
	ARXArmSetupGuardPixels()
	ARXArmGuardPixels(0)
	ARXArmoryxmitA1Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\04")	-- calibration pattern
	ARXArmoryxmitA2Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\05")
	ARXArmoryxmitA3Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\06")
	ARXArmoryxmitA4Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\07")
	ARXArmoryxmitA5Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\01")
	ARXArmoryxmitA6Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\02")
	ARXArmoryxmitA7Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\03")
	ARXArmoryxmitA8Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\04")
end

SlashCmdList["ARXARMVERBOSE"] = function(msg, theEditFrame)		-- control user feedback
	if msg == "off" then
		ARXArmoryVerboseMode = 0
		ChatFrame1:AddMessage("ARX Armory set to quiet mode.")
	elseif msg == "on" then
		ARXArmoryVerboseMode = 1
		ChatFrame1:AddMessage("ARX Armory set to verbose mode.")
	else
		local feedback = "ARX Armory is currently "
		if ARXArmoryVerboseMode ~= 1 then
			feedback = feedback.."not "
		end
		feedback = feedback.."in verbose mode. Follow with 'on' or 'off' to change."
		ChatFrame1:AddMessage(feedback)
	end
end

SlashCmdList["ARXARMGO"] = function(msg, theEditFrame)			-- the main routine (/ArxArmory)
	if UnitExists("target") then
		if (UnitIsPlayer("target")) then					-- IF THIS IS A PLAYER TARGET:
			local targetName = GetUnitName("target", true)		-- get name & realm
			
			if string.find(targetName, "-") then				-- if player NOT on same realm, then realm appears after dash
				-- do nothing, we have the realm name included
			else
				targetName = targetName.."-"..GetRealmName()  	-- append realm to local player name
			end
			if ARXArmoryVerboseMode == 1 then
				ChatFrame1:AddMessage("ARX Armory: Sending "..targetName.." to the app")
			end
			ARXArmSendMessage(targetName..string.char(7)..string.char(8))  		-- append ASCII 7 & 8 to indicate end of name
		else												-- IF THIS IS NOT A PLAYER TARGET:
			local guid = UnitGUID("target")
			local type, _, _, _, _, npc_id = strsplit("-",guid) -- type can be Player, Pet, Creature, and other stuff
			if type == "Creature" then							-- all NPCs are Creatures
				local targetName = "NPC"..npc_id
				if ARXArmoryVerboseMode == 1 then
					ChatFrame1:AddMessage("ARX Armory: Sending "..targetName.." to the app")
				end
				ARXArmSendMessage(targetName..string.char(7)..string.char(8))   -- append ASCII 7 & 8 to indicate end of name
			else 
				ChatFrame1:AddMessage("ARX Armory: Target only players or NPCs (not pets).")  -- NOT A PLAYER OR NPC TARGETTED
			end
		end
	else 
		ChatFrame1:AddMessage("ARX Armory: Target a player or NPC.") -- NOTHING TARGETTED
	end
end

-------------------------- EVENT ROUTINES CALLED BY WOW ------------------------

function ARXArmoryxmit_OnLoad(frame)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")	-- environment ready
	ARXArmXmitPhase = 0
	ARXArmPendingMessage = ""
	C_Timer.NewTicker(0.13, ARXArmoryTimer)			-- call infinite # of times. 7.5x/sec
													-- slowed down from 0.11 (9x) in vers 1.6
					-- C-ticker provides more stable timing for the texture updates
end

function ARXArmoryxmit_OnEvent(frame, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then		-- set stuff up
		ARXArmoryxmit:Show()
		ARXArmSetupGuardPixels()
		ARXArmGuardPixels(0)
	end
end

-------------------------- CUSTOM CODE TO TAP OUT THE BITS ------------------------

function ARXArmoryTimer()			-- called by C_Timer 7.5x/sec
	if ARXArmXmitPhase == 1 then			-- means we're sending a character (byte)
		ARXArmGuardPixels(1)
		ARXArmXmitPhase = 0
	elseif string.len(ARXArmPendingMessage) > 0 then				--else, if there's at least 1 character waiting to go
		nextMessage = string.sub(ARXArmPendingMessage,1,1)		--    grab the next byte
		--print("-- just picked off <"..nextMessage.."> as next byte")
		-- NOTE: Names use UTF8 encoding so non-ASCII characters are more than 1 byte long and will appear broken in above print
		ARXArmoryPutMsgOnPixels(nextMessage)					--    post it
		ARXArmGuardPixels(0)
		ARXArmPendingMessage = string.sub(ARXArmPendingMessage,2,-1)	-- remove leading byte from string
		ARXArmXmitPhase = 1
	elseif ARXArmNeedToPlayDoneSound then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION, "SFX")
		ARXArmNeedToPlayDoneSound = false
	end
end

function ARXArmoryPutMsgOnPixels(msg)
	bitmask = 1
	theCode = string.byte(msg)
	--print("encoding plain byte " .. theCode)
	for i = 1,8 do
		if bit.band(theCode,bitmask) > 0 then		-- uses C library that Blizzard included
			_G["ARXArmoryxmitA"..i.."Texture"]:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\07")
		else
			_G["ARXArmoryxmitA"..i.."Texture"]:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\00")
		end	
		bitmask = bitmask * 2						-- proven faster than bit shifting
	end
end

function ARXArmSendMessage(message)
	ARXArmPendingMessage = ARXArmPendingMessage .. message
	ARXArmNeedToPlayDoneSound = true
end

function ARXArmGuardPixels(state)
	if state == 0 then
		ARXArmoryxmitR2Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\00")
		ARXArmoryxmitL2Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\00")
	else
		ARXArmoryxmitR2Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\05")
		ARXArmoryxmitL2Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\06")
	end	
end
	
function ARXArmSetupGuardPixels()		
	ARXArmoryxmitR1Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\05")
	ARXArmoryxmitL1Texture:SetTexture("Interface\\AddOns\\ARXArmoryxmit\\06")
end
