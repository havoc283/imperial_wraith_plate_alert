Config = {}

-- Event emitted by Wraith ARS 2X when a plate is scanned.
Config.WraithScanEvent = "wk:onPlateScanned"

-- Resource name that exposes exports["ImperialCAD"]:CheckPlate(...)
Config.ImperialResource = "ImperialCAD"

-- Reduce API load by caching plate responses for this many seconds.
Config.LookupCacheSeconds = 45

-- Prevent repeated notifications for the same plate to the same player.
Config.NotifyCooldownSeconds = 30

Config.NotificationTitle = "Imperial ALPR"

Config.NotifyOn = {
    stolen = true,
    uninsured = true,
    invalidRegistration = true,
    unknown = false
}

-- Insurance statuses considered valid/active.
Config.ValidInsuranceStatuses = {
    active = true,
    valid = true
}

-- Explicit insurance statuses that should alert.
Config.InvalidInsuranceStatuses = {
    inactive = true,
    expired = true,
    lapsed = true,
    canceled = true,
    cancelled = true,
    invalid = true,
    none = true
}

-- Registration statuses considered valid.
Config.ValidRegistrationStatuses = {
    valid = true,
    active = true
}

-- Explicit registration statuses that should alert.
Config.InvalidRegistrationStatuses = {
    expired = true,
    suspended = true,
    revoked = true,
    invalid = true,
    none = true,
    unregistered = true
}
