local plateCache = {}
local pendingLookups = {}
local notifyCooldowns = {}
local warnedMissingImperial = false

local function nowSeconds()
    return os.time()
end

local function normalizePlate(plate)
    if type(plate) ~= "string" then
        return ""
    end

    local cleaned = plate:gsub("^%s+", ""):gsub("%s+$", "")
    cleaned = cleaned:gsub("%s+", ""):upper()

    return cleaned
end

local function toBool(value)
    if type(value) == "boolean" then
        return value
    end

    if type(value) == "number" then
        return value ~= 0
    end

    if type(value) == "string" then
        local lowered = value:lower()
        return lowered == "true" or lowered == "1" or lowered == "yes" or lowered == "y"
    end

    return false
end

local function normalizeStatus(value)
    local status = tostring(value or "")
    status = status:gsub("^%s+", ""):gsub("%s+$", "")
    return status:lower()
end

local function mapHasValue(map, key)
    return type(map) == "table" and map[key] == true
end

local function regIsValid(regStatus)
    local key = normalizeStatus(regStatus)
    return key ~= "" and mapHasValue(Config.ValidRegistrationStatuses, key)
end

local function regIsExplicitlyInvalid(regStatus)
    local key = normalizeStatus(regStatus)
    return key ~= "" and mapHasValue(Config.InvalidRegistrationStatuses, key)
end

local function insuranceIsValid(insuranceStatus)
    local key = normalizeStatus(insuranceStatus)
    return key ~= "" and mapHasValue(Config.ValidInsuranceStatuses, key)
end

local function insuranceIsExplicitlyInvalid(insuranceStatus)
    local key = normalizeStatus(insuranceStatus)
    return key ~= "" and mapHasValue(Config.InvalidInsuranceStatuses, key)
end

local function parseImperialResponse(raw)
    if type(raw) == "table" then
        return raw
    end

    if type(raw) ~= "string" or raw == "" then
        return nil
    end

    local decoded = json.decode(raw)
    if type(decoded) ~= "table" then
        return nil
    end

    return decoded
end

local function evaluateIssues(response)
    local issues = {}
    local owner = "Unknown"

    if type(response) ~= "table" then
        if Config.NotifyOn.unknown then
            issues[#issues + 1] = "plate not found in CAD"
        end
        return owner, issues
    end

    local status = tostring(response.status or ""):lower()
    local data = response.response

    if status ~= "" and status ~= "success" then
        if Config.NotifyOn.unknown then
            issues[#issues + 1] = "plate not found in CAD"
        end
        return owner, issues
    end

    if type(data) ~= "table" then
        if Config.NotifyOn.unknown then
            issues[#issues + 1] = "plate not found in CAD"
        end
        return owner, issues
    end

    owner = tostring(data.owner or owner)

    if Config.NotifyOn.stolen and toBool(data.stolen) then
        issues[#issues + 1] = "reported stolen"
    end

    local insuranceIssue = false
    if data.insurance ~= nil and not toBool(data.insurance) then
        insuranceIssue = true
    end
    local insuranceStatus = normalizeStatus(data.insurance_status)
    if insuranceStatus ~= "" and insuranceIsExplicitlyInvalid(insuranceStatus) and not insuranceIsValid(insuranceStatus) then
        insuranceIssue = true
    end

    if Config.NotifyOn.uninsured and insuranceIssue then
        issues[#issues + 1] = "insurance not active"
    end

    local regStatus = tostring(data.reg_status or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local regStatusKey = normalizeStatus(regStatus)
    local regIssue = false

    if regStatusKey ~= "" then
        regIssue = regIsExplicitlyInvalid(regStatusKey) or not regIsValid(regStatusKey)
    end

    if Config.NotifyOn.invalidRegistration and regIssue then
        issues[#issues + 1] = ("registration %s"):format(regStatus)
    end

    return owner, issues
end

local function getCachedResult(plate)
    local cached = plateCache[plate]
    if not cached then
        return nil
    end

    if cached.expiresAt <= nowSeconds() then
        plateCache[plate] = nil
        return nil
    end

    return cached
end

local function setCachedResult(plate, owner, issues)
    plateCache[plate] = {
        owner = owner,
        issues = issues,
        expiresAt = nowSeconds() + Config.LookupCacheSeconds
    }
end

local function canNotifyPlayer(playerId, plate)
    notifyCooldowns[playerId] = notifyCooldowns[playerId] or {}

    local expiresAt = notifyCooldowns[playerId][plate] or 0
    if expiresAt > nowSeconds() then
        return false
    end

    notifyCooldowns[playerId][plate] = nowSeconds() + Config.NotifyCooldownSeconds
    return true
end

local function notifyPlayer(playerId, plate, cam, owner, issues)
    if #issues == 0 then
        return
    end

    if not canNotifyPlayer(playerId, plate) then
        return
    end

    TriggerClientEvent("imperial_wraith_plate_alert:notify", playerId, {
        plate = plate,
        camera = cam,
        owner = owner,
        issues = issues
    })
end

local function flushPending(plate, owner, issues)
    local waiters = pendingLookups[plate] or {}
    pendingLookups[plate] = nil

    for i = 1, #waiters do
        local waiter = waiters[i]
        notifyPlayer(waiter.playerId, plate, waiter.cam, owner, issues)
    end
end

local function ensureImperialStarted()
    local state = GetResourceState(Config.ImperialResource)
    if state == "started" then
        return true
    end

    if not warnedMissingImperial then
        warnedMissingImperial = true
        print(("[imperial_wraith_plate_alert] Resource '%s' is not started."):format(Config.ImperialResource))
    end

    return false
end

local function queueLookup(playerId, cam, plate)
    pendingLookups[plate] = pendingLookups[plate] or {}
    pendingLookups[plate][#pendingLookups[plate] + 1] = {
        playerId = playerId,
        cam = cam
    }
end

local function lookupPlate(playerId, cam, plate)
    local cached = getCachedResult(plate)
    if cached then
        notifyPlayer(playerId, plate, cam, cached.owner, cached.issues)
        return
    end

    if not ensureImperialStarted() then
        return
    end

    queueLookup(playerId, cam, plate)

    if #pendingLookups[plate] > 1 then
        return
    end

    local ok, err = pcall(function()
        exports[Config.ImperialResource]:CheckPlate({ plate = plate }, function(success, res)
            local owner
            local issues

            if success then
                owner, issues = evaluateIssues(parseImperialResponse(res))
            else
                owner, issues = evaluateIssues(nil)
            end

            setCachedResult(plate, owner, issues)
            flushPending(plate, owner, issues)
        end)
    end)

    if not ok then
        print(("[imperial_wraith_plate_alert] CheckPlate call failed: %s"):format(tostring(err)))
        pendingLookups[plate] = nil
    end
end

RegisterNetEvent(Config.WraithScanEvent)
AddEventHandler(Config.WraithScanEvent, function(cam, plate)
    local playerId = source
    local normalizedPlate = normalizePlate(plate)

    if normalizedPlate == "" then
        return
    end

    lookupPlate(playerId, tostring(cam or "unknown"), normalizedPlate)
end)

AddEventHandler("playerDropped", function()
    local playerId = source
    notifyCooldowns[playerId] = nil

    for plate, waiters in pairs(pendingLookups) do
        for i = #waiters, 1, -1 do
            if waiters[i].playerId == playerId then
                table.remove(waiters, i)
            end
        end
        if #waiters == 0 then
            pendingLookups[plate] = nil
        end
    end
end)
