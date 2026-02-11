local function joinIssues(issues)
    if type(issues) ~= "table" or #issues == 0 then
        return ""
    end

    return table.concat(issues, ", ")
end

local function showNativeNotification(message)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

local function showNotification(message)
    if GetResourceState("ox_lib") == "started" and type(lib) == "table" and lib.notify then
        lib.notify({
            title = Config.NotificationTitle,
            description = message,
            type = "error"
        })
        return
    end

    showNativeNotification(message)
end

RegisterNetEvent("imperial_wraith_plate_alert:notify")
AddEventHandler("imperial_wraith_plate_alert:notify", function(payload)
    if type(payload) ~= "table" then
        return
    end

    local plate = tostring(payload.plate or "UNKNOWN")
    local owner = tostring(payload.owner or "Unknown")
    local camera = tostring(payload.camera or "unknown")
    local issues = joinIssues(payload.issues)

    local message = ("%s | %s cam | %s | Owner: %s"):format(plate, camera, issues, owner)

    showNotification(message)
end)
