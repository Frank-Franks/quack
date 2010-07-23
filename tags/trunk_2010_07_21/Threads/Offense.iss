#include ..\core\defines.iss
/*
	Offense Thread

	This thread handles shooting targets (rats, players, structures, etc...)

	-- GliderPro

*/
objectdef obj_Offense
{
	variable string SVN_REVISION = "$Rev$"
	variable int Version

	variable bool Running = TRUE

	variable time NextPulse
	variable time NextAmmoCheck
	variable int PulseIntervalInSeconds = 1
	variable int AmmoCheckIntervalInSeconds = 10
	variable bool Warned_LowAmmo = FALSE
	variable collection:bool TurretNeedsAmmo
	variable index:module LauncherIndex
	variable index:module TurretIndex
	variable int LastTurretTypeID = 0
	variable int LastChargeTypeID = 0
	
	variable int MinRange = 0
	variable int MaxRange = 0

	method Initialize()
	{
		Event[EVENT_ONFRAME]:AttachAtom[This:Pulse]
		UI:UpdateConsole["Thread: obj_Offense: Initialized", LOG_MINOR]

	}

	method Pulse()
	{
		if !${Script[EVEBot](exists)}
		{
			Script:End
		}

		if ${Time.Timestamp} >= ${This.NextPulse.Timestamp}
		{
			if ${This.Running} && !${EVEBot.Paused}
			{
				This:TakeOffensiveAction
				This:CheckAmmo[]
				if ${This.TurretIndex.Used} == 0 && ${This.LauncherIndex.Used} == 0 && ${Ship.ModuleList_Weapon.Used} > 0
				{
					This:BuildIndices
				}
			}

			This.NextPulse:Set[${Time.Timestamp}]
			This.NextPulse.Second:Inc[${This.PulseIntervalInSeconds}]
			This.NextPulse:Update
		}
	}

	/* void BuildIndices():
	Split ModuleList_Weapon into turrets and launchers so that the two may BOTH work at the same time. */
	method BuildIndices()
	{
		variable iterator ModuleIterator
		Ship.ModuleList_Weapon:GetIterator[ModuleIterator]
		
		if ${ModuleIterator:First(exists)}
		{
			do
			{
				switch ${ModuleIterator.Value.ToItem.GroupID}
				{
					case GROUP_MISSILELAUNCHER
					case GROUP_MISSILELAUNCHERASSAULT
					case GROUP_MISSILELAUNCHERBOMB
					case GROUP_MISSILELAUNCHERCITADEL
					case GROUP_MISSILELAUNCHERCRUISE
					case GROUP_MISSILELAUNCHERHEAVY
					case GROUP_MISSILELAUNCHERHEAVYASSAULT
					case GROUP_MISSILELAUNCHERROCKET
					case GROUP_MISSILELAUNCHERSIEGE
					case GROUP_MISSILELAUNCHERSTANDARD
						LauncherIndex:Insert[${ModuleIterator.Value}]
						break
					case GROUP_HYBRIDWEAPON
					case GROUP_PROJECTILEWEAPON
					case GROUP_ENERGYWEAPON
						TurretIndex:Insert[${ModuleIterator.Value}]
						break
					default
						UI:UpdateConsole["Offense:BuildIndices[]: Cannot insert ${ModuleIterator.Value.ToItem.Name} ${ModuleIterator.Value.ToItem.Group} ${ModuleIterator.Value.ToItem.GroupID} - no matching case!",LOG_CRITICAL]
						break
				}
			}
			while ${ModuleIterator:Next(exists)}
		}
	}

	method TakeOffensiveAction()
	{
		if ${Me.ActiveTarget(exists)} && !${Me.ActiveTarget.IsPC}
		{
			if !${This.IsConcordTarget[${Me.ActiveTarget.GroupID}]}
			{
				if ${Ship.IsCloaked}
				{
					Ship:Deactivate_Cloak
					; Need to give it time to uncloak
					return
				}

				Ship:Activate_StasisWebs
				Ship:Activate_WeaponEnhance
				
				variable iterator TargetPainter
				Ship.ModuleList_TargetPainter:GetIterator[TargetPainter]
				if ${TargetPainter:First(exists)}
				{
					do
					{
						if !${TargetPainter.Value.IsActive} && ${Me.ActiveTarget.Distance} < ${Math.Calc[${TargetPainter.Value.OptimalRange} * 2]}
						{
							TargetPainter.Value:Click
							break
						}
					}
					while ${TargetPainter:Next(exists)}
				}

				if ${This.LauncherIndex.Used} > 0
				{
					variable iterator Launcher
					This.LauncherIndex:GetIterator[Launcher]
					if ${Me.ActiveTarget.Distance} < ${Ship.OptimalWeaponRange}
					{
						;Turn on any launchers that are within range, not active, not reloading, and not changing ammo, and that have ammo
						if ${Launcher:First(exists)}
						{
							do
							{
								if !${Launcher.Value.IsActive} && !${Launcher.Value.IsReloadingAmmo} && !${Launcher.Value.IsChangingAmmo}
								{
									Launcher.Value:Click
									break
								}
							}
							while ${Launcher:Next(exists)}
						}
					}
					else
					{
						if ${Launcher:First(exists)}
						{
							do
							{
								if ${Launcher.Value.IsActive}
								{
									Launcher.Value:Click
									break
								}
							}
							while ${Launcher:Next(exists)}
						}
					}
				}
				
				if ${This.TurretIndex.Used} > 0
				{
					variable int idx
					variable string slot
					This.LastTurretTypeID:Set[0]
					This.LastChargeTypeID:Set[0]
					
					; iterate through every turret and determine if it needs an ammo change.
					if ${Time.Timestamp} >= ${This.NextAmmoCheck.Timestamp}
					{
						variable int tempInt = -1
						for ( idx:Set[1]; ${idx} <= ${This.TurretIndex.Used}; idx:Inc )
						{
							slot:Set[${Ship.TurretSlots.Element[${idx}]}]
							tempInt:Inc
							
							if ${MyShip.Module[${slot}].ToItem.TypeID} == ${This.LastTurretTypeID} && \
								${MyShip.Module[${slot}].Charge.TypeID} == ${This.LastChargeTypeID}
							{
								;if the previous turret needed ammo...
								if ${This.TurretNeedsAmmo.Element[${tempInt}]} == TRUE
								{
									;this one probably does too
									This.TurretNeedsAmmo:Set[${idx},TRUE]
								}
								else
								{
									;if it didn't, we probably don't either.
									This.TurretNeedsAmmo:Set[${idx},FALSE]
								}
							}
							else
							{
								This.LastTurretTypeID:Set[${MyShip.Module[${slot}].ToItem.TypeID}]
								This.LastChargeTypeID:Set[${MyShip.Module[${slot}].Charge.TypeID}]
								if ${Ship.NeedAmmoChange[${Me.ActiveTarget.Distance},${idx}]}
								{
									This.TurretNeedsAmmo:Set[${idx},TRUE]
								}
								else
								{
									This.TurretNeedsAmmo:Set[${idx},FALSE]
								}
							}
						}
						This.LastTurretTypeID:Set[0]
						This.LastChargeTypeID:Set[0]
						This.NextAmmoCheck:Set[${Time.Timestamp}]
						This.NextAmmoCheck.Second:Inc[${This.AmmoCheckIntervalInSeconds}]
						This.NextAmmoCheck:Update
					}

					for ( idx:Set[1]; ${idx} <= ${TurretIndex.Used}; idx:Inc )
					{
						slot:Set[${Ship.TurretSlots.Element[${idx}]}]
						variable bool ChargeExists = FALSE
						if ${MyShip.Module[${slot}].Charge(exists)}
						{
							ChargeExists:Set[TRUE]
						}
						;If a module's reloading, or changing ammo, continue on.
						if ${MyShip.Module[${slot}].IsChangingAmmo} || ${MyShip.Module[${slot}].IsReloadingAmmo} || !${ChargeExists}
						{
							This.TurretNeedsAmmo:Set[${idx},FALSE]
							continue
						}
						
						;Awesome, our guns are ready for ammo checks. Does our gun need an ammo change?
						if ${This.TurretNeedsAmmo.Element[${idx}]}
						{
							;ok, if our Turret needs ammo change, make sure IT IS OFF.
							;We can't change ammo 'til it's inactive so just continue after deactivating.
							if ${MyShip.Module[${slot}].IsActive}
							{
								UI:UpdateConsole["Offense: Turret ${idx}: active during ammo change, deactivating and continuing.",LOG_DEBUG]
								MyShip.Module[${slot}]:Click
								break
							}
							else
							{
								;If the weapon's off, go ahead and change ammo.
								UI:UpdateConsole["Offense: Turret ${idx}: Loading optimal ammo and breaking. Active? ${MyShip.Module[${slot}].IsActive}",LOG_DEBUG]
								Ship:LoadOptimalAmmo[${Me.ActiveTarget.Distance},${idx}]
								This.TurretNeedsAmmo:Set[${idx},FALSE]
								;Break after loading a turret's ammo, because chaging too much ammo too fast will REALLY fuck things up and make ammo disappear
								break
							}
						}
						else
						{
							if ${This.LastTurretTypeID} == 0 || ${This.LastTurretTypeID} != ${MyShip.Module[${slot}].ToItem.TypeID} || \
								${This.LastChargeTypeID} == 0 || ${This.LastChargeTypeID} != ${MyShip.Module[${slot}].ToItem.TypeID}
							{
								This.LastTurretTypeID:Set[${MyShip.Module[${slot}].ToItem.TypeID}]
								This.LastTurretTypeID:Set[${MyShip.Module[${slot}].Charge.TypeID}]
								This.MinRange:Set[${Ship.GetMinimumTurretRange[${idx}]}]
								This.MaxRange:Set[${Ship.GetMaximumTurretRange[${idx}]}]
							}
							
							;If we didn't need an ammo change, check if we need to activate or deactivate the weapon.
							;Account for some falloff in our ammo checks. EFT shows we can maintain about 75% of our dps
							;at about 1.5* our range, so assume skills suck and we're going for 1.3. The only real problem
							;with overshooting is tracking speed, and we need some sort of entity.rad/s member to check that.
							UI:UpdateConsole["Offense: Turret ${idx}: IsActive? ${MyShip.Module[${slot}].IsActive}, Distance? ${Me.ActiveTarget.Distance}, Min? ${Math.Calc[${This.MinRange}]}, Max? ${Math.Calc[${This.MaxRange}]}",LOG_DEBUG]
							if ${MyShip.Module[${slot}].IsActive}
							{
								if ${Me.ActiveTarget.Distance} > ${This.MaxRange} || \
									${Me.ActiveTarget.Distance} < ${This.MinRange}
								{
									UI:UpdateConsole["Offense: Turret ${idx}: Turret on but we're either below or above range, deactivating",LOG_DEBUG]
									MyShip.Module[${slot}]:Click
									break
								}
							}
							else
							{
								if ${Me.ActiveTarget.Distance} <= ${This.MaxRange} && \
									${Me.ActiveTarget.Distance} >= ${This.MinRange}
								{
									UI:UpdateConsole["Offense: Turret ${idx}: Turret off but we're within range, activating",LOG_DEBUG]
									MyShip.Module[${slot}]:Click
									break
								}
							}
						}
					}
				}

				if ${Config.Combat.LaunchCombatDrones}
				{
					variable bool ShouldLaunchCombatDrones = ${Ship.Drones.ShouldLaunchCombatDrones}
					if ${Ship.Drones.CombatDroneShortage}
					{
						; TODO - This should pick up drones from station instead of just docking
						Defense:RunAway["Offense: Drone shortage detected"]
						return
					}
					if ${Me.ActiveTarget.Distance} < ${Math.Calc[${Me.DroneControlDistance} * 0.975]} && \
						${Me.ActiveTarget.Distance} < ${Config.Combat.MaxDroneRange}
					{
						if ${ShouldLaunchCombatDrones}
						{
							if ${Ship.Drones.DeployedDroneCount} < 5 && ${Ship.Drones.DeployedDroneCount} < ${MyShip.GetDrones}
							{
								Ship.Drones:LaunchAll
							}
							else
							{
								Ship.Drones:SendDrones
							}
						}
						else
						{
							if ${Ship.Drones.DronesInSpace} > 0
							{
								UI:UpdateConsole["Offense: Shouldn't have combat drones out but we do, recalling!"]
								Ship.Drones:QuickReturnAllToDroneBay
							}
						}
					}
					elseif ${Ship.Drones.DeployedDroneCount} > 0
					{
						UI:UpdateConsole["Offense: Active target is out of range but we have drones out; recalling to orbit if they aren't already here.",LOG_DEBUG]
						Ship.Drones:QuickReturnAllToOrbit
					}
				}
			}
		}
		else
		{
			Ship:Deactivate_Weapons
			Ship:Deactivate_StasisWebs
			Ship:Deactivate_TargetPainters
			Ship:Deactivate_WeaponEnhance
		}
	}
	
	/* bool HaveFullAggro:
	Using the correct entity cache for a given bot mode, determine if we have aggro from all aggroing entities.
	This will account for non-aggressing spawns such as hauler spawns. */
	member:bool HaveFullAggro()
	{
		variable bool HaveAggro = FALSE
		
		switch ${Config.Common.BotMode}
		{
			case Ratter
				HaveAggro:Set[${Targets.HaveFullAggro["Ratter.RatCache"]}]
				break
			case Missioneer
				HaveAggro:Set[${Targets.HaveFullAggro["Missions.missionCombat.MissionCommands.EntityCache"]}]
				break
		}
		return ${HaveAggro}
	}

	method CheckAmmo()
	{
		if !${Script[EVEBot](exists)}
		{
			return
		}

		if ${Ship.IsCloaked} || !${Me.InSpace}
		{
			return
		}

		if !${Ship.IsAmmoAvailable}
		{
			if ${Config.Combat.RunOnLowAmmo}
			{
				Defense:RunAway["Offense - Out of ammo!"]
			}
			elseif !${This.Warned_LowAmmo}
			{
				This.Warned_LowAmmo:Set[TRUE]
				UI:UpdateConsole["Offense: Warning - Out of ammo!"]
			}
		}
		else
		{
			This.Warned_LowAmmo:Set[FALSE]
		}
	}

	member:bool IsConcordTarget(int GroupID)
	{
		switch ${GroupID}
		{
			case GROUP_LARGECOLLIDABLEOBJECT
			case GROUP_LARGECOLLIDABLESHIP
			case GROUP_SENTRYGUN
			case GROUP_CONCORDDRONE
			case GROUP_CUSTOMSOFFICIAL
			case GROUP_POLICEDRONE
			case GROUP_CONVOYDRONE
			case GROUP_FACTIONDRONE
			case GROUP_BILLBOARD
				return TRUE
		}

		return FALSE
	}

	method Enable()
	{
#if EVEBOT_DEBUG
		UI:UpdateConsole["Offense: Enabled"]
#endif
		This.Running:Set[TRUE]
	}

	method Disable()
	{
#if EVEBOT_DEBUG
		UI:UpdateConsole["Offense: Disabled"]
#endif
		This.Running:Set[FALSE]
	}
}

variable(global) obj_Offense Offense

function main()
{
	EVEBot.Threads:Insert[${Script.Filename}]
	while ${Script[EVEBot](exists)}
	{
		waitframe
	}
	echo "EVEBot exited, unloading ${Script.Filename}"
}