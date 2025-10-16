local cooldown = false
local cooldownTime = 30000 -- 30 seconds between calls
local activeBlips = {}

-- Wait for ox_lib to be ready
Citizen.CreateThread(function()
    while GetResourceState('ox_lib') ~= 'started' do
        Citizen.Wait(100)
    end
    print("[Corrupt911] ox_lib loaded successfully")
end)

-- Get nearest postal
function GetNearestPostal(coords)
    -- If you have a postal script, integrate it here
    -- Example for nearest-postal resource:
    local success, postal = pcall(function()
        return exports["nearest-postal"]:getPostal()
    end)
    
    if success and postal then
        return postal.code
    end
    
    -- Fallback to coordinates
    return string.format("%.0f, %.0f", coords.x, coords.y)
end

-- Command to call 911
RegisterCommand('911', function(source, args, rawCommand)
    print("[Corrupt911] Command triggered")
    
    if cooldown then
        if lib and lib.notify then
            lib.notify({
                title = 'Corrupt 911',
                description = 'Please wait before making another call.',
                type = 'error',
                position = 'top-right'
            })
        else
            print("[Corrupt911] Error: ox_lib not loaded")
        end
        return
    end
    
    if not lib or not lib.inputDialog then
        print("[Corrupt911] Error: ox_lib inputDialog not available")
        TriggerEvent('chat:addMessage', {
            args = {"^1[Corrupt911]", "Error: ox_lib is not loaded properly. Contact an administrator."}
        })
        return
    end
    
    local input = lib.inputDialog('Corrupt 911 - Emergency Call', {
        {type = 'input', label = 'Your Name', placeholder = 'John Doe', required = true},
        {type = 'textarea', label = 'Emergency Description', placeholder = 'Describe your emergency...', required = true},
        {type = 'input', label = 'Postal', placeholder = 'Postal Of Emergency', required = true}
    })
    
    if not input then 
        print("[Corrupt911] Input cancelled")
        return 
    end
    
    local callerName = input[1]
    local reason = input[2]
    local postal = input[3] -- Use the manual postal input from the dialog
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    print(string.format("[Corrupt911] Sending call: %s - %s - %s", callerName, reason, postal))
    
    -- Send to server
    TriggerServerEvent('Corrupt911:newCall', callerName, reason, coords, postal)
    
    -- Start cooldown
    cooldown = true
    lib.notify({
        title = 'Corrupt 911',
        description = 'Your emergency call has been dispatched to available units.',
        type = 'success',
        position = 'top-right'
    })
    
    SetTimeout(cooldownTime, function()
        cooldown = false
    end)
end, false)

-- Show custom notification for emergency personnel
function Show911Notification(data)
    -- Custom black box notification
    SendNUIMessage({
        type = 'show911',
        data = {
            title = 'Corrupt 911',
            name = data.name,
            reason = data.reason,
            postal = data.postal,
            callerId = data.callerId
        }
    })
end

-- Receive 911 calls (for emergency services)
RegisterNetEvent('Corrupt911:receiveCall')
AddEventHandler('Corrupt911:receiveCall', function(callerName, callerId, reason, coords, postal, department)
    print(string.format("[Corrupt911] Received call from %s [%d]", callerName, callerId))
    
    -- Show custom notification in top right
    Show911Notification({
        name = callerName,
        reason = reason,
        postal = postal,
        callerId = callerId
    })
    
    -- Play sound
    PlaySoundFrontend(-1, "Mission_Pass_Notify", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", 0)
    
    -- Show ox_lib context menu
    lib.registerContext({
        id = 'corrupt911_call_' .. callerId,
        title = 'Corrupt 911',
        options = {
            {
                title = 'Caller Information',
                description = 'Emergency Call Details',
                disabled = true
            },
            {
                title = 'Name',
                description = callerName,
                icon = 'user'
            },
            {
                title = 'Reason',
                description = reason,
                icon = 'message'
            },
            {
                title = 'Postal',
                description = postal,
                icon = 'location-dot'
            },
            {
                title = 'Set GPS Waypoint',
                description = 'Navigate to emergency location',
                icon = 'map-pin',
                onSelect = function()
                    SetNewWaypoint(coords.x, coords.y)
                    lib.notify({
                        title = 'GPS Set',
                        description = 'Waypoint set to emergency location',
                        type = 'success',
                        position = 'top-right'
                    })
                end
            },
            {
                title = 'Acknowledge Call',
                description = 'Let caller know you are responding',
                icon = 'check',
                onSelect = function()
                    TriggerServerEvent('Corrupt911:acknowledgeCall', callerId)
                end
            }
        }
    })
    
    lib.showContext('corrupt911_call_' .. callerId)
    
    -- Create blip on map
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.2)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("911: " .. postal)
    EndTextCommandSetBlipName(blip)
    SetBlipFlashes(blip, true)
    
    -- Store blip reference
    table.insert(activeBlips, {id = blip, callerId = callerId})
    
    -- Remove blip after 5 minutes
    SetTimeout(300000, function()
        RemoveBlip(blip)
    end)
end)

-- Notification when call is acknowledged
RegisterNetEvent('Corrupt911:callAcknowledged')
AddEventHandler('Corrupt911:callAcknowledged', function(responderName, responderCallsign, department)
    local message = string.format("%s (%s) from %s is responding to your emergency call.", 
        responderName, responderCallsign or "Unknown", department or "Emergency Services")
    
    lib.notify({
        title = 'Corrupt 911',
        description = message,
        type = 'success',
        position = 'top-right',
        duration = 7000
    })
    
    PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", 0)
end)
