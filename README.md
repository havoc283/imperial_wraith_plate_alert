# Imperial Wraith Plate Alert

Standalone FiveM resource that listens to Wraith ARS 2X scans and checks each plate with `ImperialCAD:CheckPlate`.

## Features

- Hooks Wraith scan event: `wk:onPlateScanned`
- Calls:
  ```lua
  exports["ImperialCAD"]:CheckPlate({ plate = "XYZ123" }, cb)
  ```
- Notifies the scanning player when configured alert conditions are found:
  - stolen vehicle
  - explicit uninsured/expired insurance status
  - explicit invalid registration status
  - plate missing from CAD (optional)
- Includes cache + cooldown logic to reduce API calls and notification spam
- Clean plate responses produce no notification

## Install

1. Put `imperial_wraith_plate_alert` in your FiveM `resources` folder.
2. Ensure resource order in `server.cfg`:
   ```cfg
   ensure ImperialCAD
   ensure wk_wars2x
   ensure imperial_wraith_plate_alert
   ```
3. Edit `imperial_wraith_plate_alert/config.lua` if needed.

## Config

- `Config.WraithScanEvent`: Wraith scan event name (default: `wk:onPlateScanned`)
- `Config.ImperialResource`: resource exposing `CheckPlate` export (default: `ImperialCAD`)
- `Config.LookupCacheSeconds`: cache lifetime for lookup results
- `Config.NotifyCooldownSeconds`: per-player cooldown per plate
- `Config.NotifyOn`: toggles for each alert type
- `Config.ValidInsuranceStatuses`: insurance statuses treated as valid
- `Config.InvalidInsuranceStatuses`: insurance statuses treated as alert-worthy
- `Config.ValidRegistrationStatuses`: statuses considered valid
- `Config.InvalidRegistrationStatuses`: statuses treated as alert-worthy
