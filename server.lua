-- Get player name (standalone version)
function GetPlayerName(source)
    return GetPlayerName(source)
end

-- New 911 call
RegisterNetEvent('Corrupt911:newCall')
AddEventHandler('Corrupt911:newCall', function(callerName, reason, coords, postal)
    local src = source
    
    -- Validate inputs
    if not callerName or not reason or not coords or not postal then
        return
    end
    
    -- Get all on-duty players from SiriusDuty
    local success, onDutyPlayers = pcall(function()
        return exports["SiriusDuty"]:GetAllOnDutyPlayers()
    end)
    
    if not success or not onDutyPlayers or type(onDutyPlayers) ~= "table" then
        return
    end
    
    local notifiedCount = 0
    
    -- Send to all on-duty personnel (except staff)
    for _, playerData in pairs(onDutyPlayers) do
        if playerData then
            local playerId = nil
            
            if type(playerData) == "table" then
                playerId = playerData.src or playerData.source or playerData.id
            elseif type(playerData) == "number" then
                playerId = playerData
            end
            
            if playerId and type(playerId) == "number" then
                -- Safely check if player is staff
                local isStaff = false
                pcall(function()
                    isStaff = exports["SiriusDuty"]:IsPlayerStaff(playerId)
                end)
                
                if not isStaff then
                    local department = nil
                    pcall(function()
                        department = exports["SiriusDuty"]:GetPlayerDepartment(playerId)
                    end)
                    
                    -- Safely trigger client event
                    pcall(function()
                        TriggerClientEvent('Corrupt911:receiveCall', playerId, callerName, src, reason, coords, postal, department)
                    end)
                    
                    notifiedCount = notifiedCount + 1
                end
            end
        end
    end
    
    -- Optional: Send to Discord webhook
    pcall(function()
        SendToDiscord("Corrupt 911 Emergency Call", string.format(
            "**Caller:** %s [ID: %d]\n**Postal:** %s\n**Reason:** %s\n**Coordinates:** %.2f, %.2f, %.2f\n**Units Notified:** %d",
            callerName, src, postal, reason, coords.x, coords.y, coords.z, notifiedCount
        ))
    end)
end)

-- Acknowledge call
RegisterNetEvent('Corrupt911:acknowledgeCall')
AddEventHandler('Corrupt911:acknowledgeCall', function(callerId)
    local src = source
    
    if not callerId or type(callerId) ~= "number" then
        return
    end
    
    -- Check if player is on duty
    local success, onDutyPlayers = pcall(function()
        return exports["SiriusDuty"]:GetAllOnDutyPlayers()
    end)
    
    local isOnDuty = false
    
    if success and onDutyPlayers and type(onDutyPlayers) == "table" then
        for _, playerData in pairs(onDutyPlayers) do
            if playerData then
                local playerId = nil
                
                if type(playerData) == "table" then
                    playerId = playerData.src or playerData.source or playerData.id
                elseif type(playerData) == "number" then
                    playerId = playerData
                end
                
                if playerId == src then
                    isOnDuty = true
                    break
                end
            end
        end
    end
    
    if not isOnDuty then
        pcall(function()
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Corrupt 911',
                description = 'You must be on duty to acknowledge calls.',
                type = 'error',
                position = 'top-right'
            })
        end)
        return
    end
    
    -- Check if player is staff
    local isStaff = false
    pcall(function()
        isStaff = exports["SiriusDuty"]:IsPlayerStaff(src)
    end)
    
    if isStaff then
        pcall(function()
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Corrupt 911',
                description = 'Staff members cannot acknowledge 911 calls.',
                type = 'error',
                position = 'top-right'
            })
        end)
        return
    end
    
    local responderName = GetPlayerName(src)
    local responderCallsign = nil
    local department = nil
    
    pcall(function()
        responderCallsign = exports["SiriusDuty"]:GetPlayerCallsign(src)
    end)
    
    pcall(function()
        department = exports["SiriusDuty"]:GetPlayerDepartment(src)
    end)
    
    -- Notify the caller
    pcall(function()
        TriggerClientEvent('Corrupt911:callAcknowledged', callerId, responderName, responderCallsign, department)
    end)
    
    -- Notify the responder
    pcall(function()
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Corrupt 911',
            description = string.format('You have acknowledged the call from ID %d', callerId),
            type = 'success',
            position = 'top-right'
        })
    end)
end)

-- Discord webhook function
function SendToDiscord(title, message)
    local webhookURL = "YOUR_DISCORD_WEBHOOK_URL_HERE" -- Replace with your webhook
    
    if webhookURL == "YOUR_DISCORD_WEBHOOK_URL_HERE" then
        return -- Don't send if webhook not configured
    end
    
    local embed = {
        {
            ["color"] = 16711680,
            ["title"] = title,
            ["description"] = message,
            ["footer"] = {
                ["text"] = os.date("%Y-%m-%d %H:%M:%S")
            }
        }
    }
    
    PerformHttpRequest(webhookURL, function(err, text, headers) end, 'POST', 
        json.encode({username = "Corrupt 911 System", embeds = embed}), 
        {['Content-Type'] = 'application/json'})
end
