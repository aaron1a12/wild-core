--
-- Global outfit functionality
--

function W.GetPlayerCurrentOutfit()
    RefreshPlayerData()
    return W.PlayerData["outfits"][W.PlayerData["currentOutfit"]]
end

function W.GetPlayerCurrentOutfitIndex()
    RefreshPlayerData()
    return W.PlayerData["currentOutfit"]
end

function W.GetPlayerOutfitAtIndex(index)
    RefreshPlayerData()
    return W.PlayerData["outfits"][index]
end

function W.ModifyPlayerOutfit(index, outfit)
    local localOutfit = {}
    localOutfit.model = outfit.model
    localOutfit.preset = outfit.preset
    localOutfit.voice = outfit.voice
    localOutfit.loco = outfit.loco

    -- Copy the drawables
    localOutfit.enabledDrawables = {}
    localOutfit.disabledDrawables = {}

    for i, drawable in pairs(outfit.enabledDrawables) do
        localOutfit.enabledDrawables[i] = {drawable[1], drawable[2],  drawable[3],  drawable[4], drawable[5], drawable[6], drawable[7], drawable[8]}
    end
    
    for i, drawable in pairs(outfit.disabledDrawables) do
        localOutfit.disabledDrawables[i] = {drawable[1], drawable[2],  drawable[3],  drawable[4], drawable[5], drawable[6], drawable[7], drawable[8]}
    end

    W.PlayerData["outfits"][index] = localOutfit
    TriggerServerEvent("wild:sv_modifyPlayerOutfit", GetPlayerName(PlayerId()), index, localOutfit)
end

function W.SetPedOutfit(ped, outfit)
    EquipMetaPedOutfitPreset(ped, outfit.preset, false)

    ResetPedComponents(ped)

    for _, enabledDrawable in pairs(outfit.enabledDrawables) do
        SetMetaPedTag(ped, enabledDrawable[1], enabledDrawable[2],  enabledDrawable[3],  enabledDrawable[4], enabledDrawable[5], enabledDrawable[6], enabledDrawable[7], enabledDrawable[8])
    end
    
    for _, disabledDrawable in pairs(outfit.disabledDrawables) do
        RemoveTagFromMetaPed(ped, disabledDrawable[1], 1)
    end

    while not IsPedReadyToRender(ped) do
        Wait(0)
    end
    
    N_0xaab86462966168ce(ped, true)
    UpdatePedVariation(ped, false, true, true, true, false)

    while not IsPedReadyToRender(ped) do
        Wait(0)
    end
    
    -- Voice
    if outfit.voice ~= nil then
        SetAmbientVoiceName(ped, outfit.voice)
        N_0xd47d47efbf103fb8(ped, 3)
    end

    if outfit.loco ~= 0 then
        local locoStr = ""

        if outfit.loco == 1 then locoStr = "algie" end
        if outfit.loco == 2 then locoStr = "angry_female" end
        if outfit.loco == 3 then locoStr = "arthur_healthy" end
        if outfit.loco == 4 then locoStr = "cowboy" end
        if outfit.loco == 5 then locoStr = "cowboy_f" end
        if outfit.loco == 6 then locoStr = "default" end
        if outfit.loco == 7 then locoStr = "default_female" end
        if outfit.loco == 8 then locoStr = "free_slave_01" end
        if outfit.loco == 9 then locoStr = "free_slave_02" end
        if outfit.loco == 10 then locoStr = "gold_panner" end
        if outfit.loco == 11 then locoStr = "guard_lantern" end
        if outfit.loco == 12 then locoStr = "injured_general" end
        if outfit.loco == 13 then locoStr = "john_marston" end
        if outfit.loco == 14 then locoStr = "lilly_millet" end
        if outfit.loco == 15 then locoStr = "lone_prisoner" end
        if outfit.loco == 16 then locoStr = "lost_man" end
        if outfit.loco == 17 then locoStr = "mp_ova_hunter" end
        if outfit.loco == 18 then locoStr = "mp_ova_hunter_female" end
        if outfit.loco == 19 then locoStr = "murfree" end
        if outfit.loco == 20 then locoStr = "old_female" end
        if outfit.loco == 21 then locoStr = "primate" end
        if outfit.loco == 22 then locoStr = "rally" end
        if outfit.loco == 23 then locoStr = "waiter" end
        if outfit.loco == 24 then locoStr = "war_veteran" end

        SetPedDesiredLocoForModel(ped, locoStr)
    end
end

function W.SwitchPlayerOutfitAtIndex(index)
    local outfit = W.GetPlayerOutfitAtIndex(index)

    -- Update player model
    local hash = GetHashKey(outfit.model)

    RequestModel(hash)

    while not HasModelLoaded(hash) do
        RequestModel(hash)
        Wait(0)
    end
    
    SetPlayerModel(PlayerId(), hash, false)
    local newPlayerPed = PlayerPedId()

    SetModelAsNoLongerNeeded(hash)
    --ResetPedWeaponMovementClipset(playerPed)

    W.SetPedOutfit(newPlayerPed, outfit)

    W.PlayerData["currentOutfit"] = index
    TriggerServerEvent("wild:sv_setPlayerKeyValue", GetPlayerName(PlayerId()), "currentOutfit", index)
end


--
-- Outfit Switch Menu
--

local outfitPromptGroup = GetRandomIntInRange(1, 0xFFFFFF)
local outfitPrompts = {}
local bShowOutfitPrompt = false
local outfitPromptTimeOut = 0
local bOutfitLock = false
local cam = 0

local function ChooseCamCoords()
    local ped = PlayerPedId()
    local x1,y1,z1 = table.unpack(GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, 0.5))--table.unpack(GetEntityCoords(ped))
    local x2,y2,z2 = table.unpack(GetOffsetFromEntityInWorldCoords(ped, 1.0, 2.0, 0.5))

    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(StartShapeTestRay(x1, y1, z1, x2, y2, z2, -1, ped, 1))

    if hit == 1 then
        return endCoords
    else
        return vector3(x2, y2, z2)
    end
end

local function CreateOutfitPrompt(controlHash, text)
    local outfitPrompt = PromptRegisterBegin()
    PromptSetControlAction(outfitPrompt, controlHash)
    PromptSetText(outfitPrompt, CreateVarString(10, "LITERAL_STRING", text))
    UiPromptSetHoldMode(outfitPrompt, 500)
    UiPromptSetPriority(outfitPrompt, 3)
    PromptSetGroup(outfitPrompt, outfitPromptGroup, 0) 
    UiPromptSetEnabled(outfitPrompt, false)
    UiPromptSetVisible(outfitPrompt, true)
    UiPromptSetAttribute(outfitPrompt, 10, true)

    for i=10, 40 do
        if i ~= 21 and i~= 29 then
            --UiPromptSetAttribute(outfitPrompt, i, false) 
        end
    end
--[[    UiPromptSetAttribute(outfitPrompt, 1, true) 
    UiPromptSetAttribute(outfitPrompt, 3, true) 
    UiPromptSetAttribute(outfitPrompt, 4, true) 
    UiPromptSetAttribute(outfitPrompt, 9, true) 
    UiPromptSetAttribute(outfitPrompt, 10, true)]]
    PromptRegisterEnd(outfitPrompt)

    table.insert(outfitPrompts, outfitPrompt)
end

local function DeleteAllOutfitPrompts()
    for i=1, #outfitPrompts do
        PromptDelete(outfitPrompts[i])
    end
    outfitPrompts = {}
end

function UpdatePrompts()
    local currentOutfit = W.GetPlayerCurrentOutfitIndex()

    for i=1, #outfitPrompts do
        UiPromptSetEnabled(outfitPrompts[i], (i ~= currentOutfit))
    end
end



function OpenOutfitMenu()
    bOutfitLock = true
    bShowOutfitPrompt = true
    outfitPromptTimeOut = 3000

    ModifyPlayerUiPrompt(PlayerId(), 0, 1, true)

    CreateOutfitPrompt(`INPUT_EMOTE_DANCE`, "Outfit 1")
    CreateOutfitPrompt(`INPUT_EMOTE_GREET`, "Outfit 2")
    CreateOutfitPrompt(`INPUT_EMOTE_COMM`, "Outfit 3")
    CreateOutfitPrompt(`INPUT_EMOTE_TAUNT`, "Outfit 4")
    UpdatePrompts()
    
    W.Prompts.SetActiveGroup(outfitPromptGroup)
    
    Citizen.CreateThread(function() 
        while outfitPromptTimeOut > 0 do
            Wait(50)
            outfitPromptTimeOut = outfitPromptTimeOut - 50

            for i=1, #outfitPrompts do
                if UiPromptGetProgress(outfitPrompts[i]) ~= 0.0 then
                    outfitPromptTimeOut = 3000
                    break
                end
            end
        end

        bShowOutfitPrompt = false
    end)

    Citizen.CreateThread(function()
        while bShowOutfitPrompt do   
            Citizen.Wait(0)  

            PromptSetActiveGroupThisFrame(outfitPromptGroup, CreateVarString(10, "LITERAL_STRING", "Change Outfit"))            
            
            SetControlContext(4, `UI_EMOTES_RADIAL_MENU`)

            for i=1, #outfitPrompts do
                if UiPromptGetProgress(outfitPrompts[i]) == 1.0 then
                    UiPromptRestartModes(outfitPrompts[i])

                    SetEntityVisible(PlayerPedId(), false)
                    W.SwitchPlayerOutfitAtIndex(i)
                    UpdatePrompts()
                    Citizen.Wait(100)
                    SetEntityVisible(PlayerPedId(), true)

                    break
                end
            end

            local x,y,z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 1.0, 0.0))
            DrawLightWithRange(x,y,z,255,255,255, 5.0, 0.1)
        end

        CloseOutfitMenu()
    end)


    local camCoords = ChooseCamCoords()
    local playerCoords = GetEntityCoords(PlayerPedId())+vector3(0,0, 0.1)
    local rot = GetLookAtRotation(camCoords, playerCoords)

    cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", camCoords.x, camCoords.y, camCoords.z, rot[1], rot[2], rot[3], 55.0, false, 0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true, 0)
end

function CloseOutfitMenu()
    W.Prompts.SetActiveGroup(0)
    DeleteAllOutfitPrompts()
    bShowOutfitPrompt = false
    outfitPromptTimeOut = 0

    RenderScriptCams(false, false, 0, true, true, 0)
    SetCamActive(cam, false)
    DestroyCam(cam, true)

    Citizen.Wait(100)
    bOutfitLock = false
end

Citizen.CreateThread(function()
    while true do   
        Citizen.Wait(0)  

        if IsControlJustPressed(0, `INPUT_RADIAL_MENU_NAV_LR`) or IsControlJustPressed(0, `INPUT_RADIAL_MENU_NAV_UD`) or IsControlJustPressed(0, `INPUT_INTERACT_LOCKON`) then
            CloseOutfitMenu()
        end

        if IsControlJustPressed(0, "INPUT_OPEN_JOURNAL") and not bOutfitLock then
            local prompt = 0

            -- Create prompt
            if prompt == 0 then
                prompt = PromptRegisterBegin()
                PromptSetControlAction(prompt, GetHashKey("INPUT_OPEN_JOURNAL")) -- L key
                PromptSetText(prompt, CreateVarString(10, "LITERAL_STRING", "Outfit Menu"))
                UiPromptSetHoldMode(prompt, 750)
                UiPromptSetAttribute(prompt, 2, true) 
                UiPromptSetAttribute(prompt, 4, true) 
                UiPromptSetAttribute(prompt, 9, true) 
                UiPromptSetAttribute(prompt, 10, true) -- kPromptAttrib_NoButtonReleaseCheck. Immediately becomes pressed
                UiPromptSetAttribute(prompt, 17, true) -- kPromptAttrib_NoGroupCheck. Allows to appear in any active group
                PromptRegisterEnd(prompt)

                Citizen.CreateThread(function()
                    Citizen.Wait(100)

                    while UiPromptGetProgress(prompt) ~= 0.0 and UiPromptGetProgress(prompt) ~= 1.0 do   
                        Citizen.Wait(0)
                    end

                    if UiPromptGetProgress(prompt) == 1.0 then
                        OpenOutfitMenu()
                    end

                    PromptDelete(prompt)
                    prompt = 0

                    Citizen.Wait(1000)
                end)
            end
        end
    end
end)