local objective = Neurologics.RoleManager.Objectives.Repair:new()

objective.Name = "RepairElectrical"
objective.AmountPoints = 300
objective.ItemIdentifier = {"junctionbox", "statusmonitor", "sonarmonitor", "shuttlenavterminal", "navterminal", "shuttlenavterminal", "battery", "shuttlebattery", "supercapacitor", "reactor1", "outpostreactor"}
objective.ItemText = Neurologics.Language.ElectricalDevices
objective.Job = {"staff","crewmember"}
return objective
