/*
	Cargo Class

	Interacting with Cargo of ship, hangar, and containers, and moving it.

	-- CyberTech

BUGS:


*/

objectdef obj_Cargo
{
	variable index:item CargoToTransfer
	variable bool m_LastTransferComplete
	variable index:string ActiveMiningCrystals
	variable float m_ContainerFreeSpace

	method Initialize()
	{
		UI:UpdateConsole["obj_Cargo: Initialized", LOG_MINOR]
	}

	member:bool LastTransferComplete()
	{
		return ${m_LastTransferComplete}
	}

	member:bool ShipHasContainers()
	{
		variable index:item anItemIndex

		call Inventory.ShipCargo.Activate
		Inventory.ShipCargo:GetItems[anItemIndex, "GroupID == GROUPID_SECURE_CONTAINER"]
		if ${anItemIndex.Used} > 0
			return TRUE

		return FALSE
	}


	method DumpItem(item anItem)
	{
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: BasePrice:         ${anItem.BasePrice}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Capacity:          ${anItem.Capacity}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Category:          ${anItem.Category}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: CategoryID:        ${anItem.CategoryID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Description:       ${anItem.Description}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: GraphicID:         ${anItem.GraphicID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Group:             ${anItem.Group}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: GroupID:           ${anItem.GroupID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: ID:                ${anItem.ID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: IsContraband:      ${anItem.IsContraband}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: IsRepackable:      ${anItem.IsRepackable}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Location:          ${anItem.Location}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: LocationID:        ${anItem.LocationID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: MacroLocation:     ${anItem.MacroLocation}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: MacroLocationID:   ${anItem.MacroLocationID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: MarketGroupID:     ${anItem.MarketGroupID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Name:              ${anItem.Name}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: OwnerID:           ${anItem.OwnerID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: PortionSize:       ${anItem.PortionSize}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Quantity:          ${anItem.Quantity}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: RaceID:            ${anItem.RaceID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Radius:            ${anItem.Radius}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Slot:              ${anItem.Slot}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: SlotID:            ${anItem.SlotID}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Type:              ${anItem.Type}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: Volume:            ${anItem.Volume}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: GivenName:         ${anItem.Name}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: CargoCapacity:     ${anItem.CargoCapacity}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: UsedCargoCapacity: ${anItem.UsedCargoCapacity}"]
		UI:UpdateConsole["DEBUG: obj_Cargo: DumpItem: GetCargo:          ${anItem.GetCargo}"]
		UI:UpdateConsole["========================================================"]

	}

	member:int CargoToTransferCount()
	{
		return ${This.CargoToTransfer.Used}
	}

	function ReplenishCrystals(int64 from=-1)
	{
		variable iterator CargoIterator
		variable iterator HangarIterator
		variable iterator CrystalIterator
		variable collection:int Crystals
		variable int MIN_CRYSTALS = ${Math.Calc[${Ship.ModuleList_MiningLaser.Used} + 1]}

		This.ActiveMiningCrystals:GetIterator[CrystalIterator]

		; Add in any Crystals that were brought in from the laser modules
		if ${CrystalIterator:First(exists)}
		do
		{
			;echo Setting active crystal: ${CrystalIterator.Value} ${CrystalIterator.Value}
			Crystals:Set[${CrystalIterator.Value}, ${Math.Calc[${Crystals.Element[${CrystalIterator.Value}]} + 1]}]
		}
		while ${CrystalIterator:Next(exists)}

		call Inventory.ShipCargo.Activate
		if !${Inventory.ShipCargo.IsCurrent}
		{
			UI:UpdateConsole["ReplenishCrystals: Failed to activate ${Inventory.ShipCargo.EVEWindowParams}"]
			return
		}
		Inventory.Current:GetItems[NULL, "CategoryID == CATEGORYID_CHARGE"]
		Inventory.Current.Items:GetIterator[CargoIterator]

		; Add up the current crystal quantities in the cargo
		if ${CargoIterator:First(exists)}
		do
		{
			variable string crystal
			variable int quantity

			crystal:Set[${CargoIterator.Value.Name}]
			quantity:Set[${CargoIterator.Value.Quantity}]

			Crystals:Set[${crystal}, ${Math.Calc[${Crystals.Element[${crystal}]} + ${quantity} ]}]
		}
		while ${CargoIterator:Next(exists)}

		This.CargoToTransfer:Clear

		; No crystals types found to replenish, just return
		if !${Crystals.FirstKey(exists)}
		{
			return
		}

		if ${from} == -1
		{
			call Inventory.StationHangar.Activate ${Me.Station.ID}
			if !${Inventory.StationHangar.IsCurrent}
			{
				UI:UpdateConsole["ReplenishCrystals: Failed to activate ${Inventory.StationHangar.EVEWindowParams}"]
				return
			}
			Inventory.Current:GetItems[NULL, "CategoryID == CATEGORYID_CHARGE"]
			Inventory.Current.Items:GetIterator[HangarIterator]

			; Cycle thru the Hangar looking for the needed Crystals and move them to the ship
			if ${HangarIterator:First(exists)}
			do
			{
				variable string name
				variable int quant
				variable int needed

				name:Set[${HangarIterator.Value.Name}]
				quant:Set[${HangarIterator.Value.Quantity}]

				if ${Crystals.FirstKey(exists)}
				do
				{
					needed:Set[${Math.Calc[ ${MIN_CRYSTALS} - ${Crystals.CurrentValue}]}]

					;echo "${MIN_CRYSTALS} - ${Crystals.CurrentValue} = ${needed}"
					;echo Hangar: ${name} : ${quant} == ${Crystals.CurrentKey} : Needed: ${needed}

					if (${name.Equal[${Crystals.CurrentKey}]} && ${needed} > 0)
					{
						if ${quant} >= ${needed}
						{
							HangarIterator.Value:MoveTo[MyShip, CargoHold, ${needed}]
							Crystals:Set[${Crystals.CurrentKey}, ${Math.Calc[${Crystals.CurrentValue} + ${needed}]}]
						}
						else
						{
							HangarIterator.Value:MoveTo[MyShip, CargoHold]
							Crystals:Set[${Crystals.CurrentKey}, ${Math.Calc[${Crystals.CurrentValue} + ${quant}]}]
						}
					}
				}
				while ${Crystals.NextKey(exists)}
			}
			while ${HangarIterator:Next(exists)}
		}
		else
		{
			; TODO - Convert to Inventory object after Entity testing is done
			variable index:item HangarCargo
			Entity[${from}]:Open
			wait 30
			Entity[${from}]:GetCorpHangarsCargo[HangarCargo]
			HangarCargo:GetIterator[CargoIterator]

			; Cycle thru the Hangar looking for the needed Crystals and move them to the ship
			if ${CargoIterator:First(exists)}
			do
			{
				if ${CargoIterator.Value.CategoryID} == CATEGORYID_CHARGE
				{

					name:Set[${CargoIterator.Value.Name}]
					quant:Set[${CargoIterator.Value.Quantity}]

					if ${Crystals.FirstKey(exists)}
					do
					{
						needed:Set[${Math.Calc[ ${MIN_CRYSTALS} - ${Crystals.CurrentValue}]}]

						;echo "${MIN_CRYSTALS} - ${Crystals.CurrentValue} = ${needed}"
						;echo Hangar: ${name} : ${quant} == ${Crystals.CurrentKey} : Needed: ${needed}

						if (${name.Equal[${Crystals.CurrentKey}]} && ${needed} > 0)
						{
							if ${quant} >= ${needed}
							{
								CargoIterator.Value:MoveTo[MyShip, CargoHold, ${needed}]
								Crystals:Set[${Crystals.CurrentKey}, ${Math.Calc[${Crystals.CurrentValue} + ${needed}]}]
							}
							else
							{
								CargoIterator.Value:MoveTo[MyShip, CargoHold]
								Crystals:Set[${Crystals.CurrentKey}, ${Math.Calc[${Crystals.CurrentValue} + ${quant}]}]
							}
						}
					}
					while ${Crystals.NextKey(exists)}
				}
			}
			while ${CargoIterator:Next(exists)}
		}

		; Did we get what we needed?
		if ${Crystals.FirstKey(exists)}
		do
		{
			if ${Crystals.CurrentValue} < ${MIN_CRYSTALS}
			{
					 UI:UpdateConsole["Out of ${Crystals.CurrentKey} !!"]
			}
		}
		while ${Crystals.NextKey(exists)}
	}


	function TransferContainerToHangar(item anItem)
	{
		if ${anItem.GroupID} == GROUPID_SECURE_CONTAINER
		{
			anItem:Open
			wait 15

			variable index:item anItemIndex
			variable index:int64  anIntIndex
			variable iterator   anIterator

			anItem:GetCargo[anItemIndex]
			anItemIndex:GetIterator[anIterator]
			anIntIndex:Clear

			if ${anIterator:First(exists)}
			do
			{
				anIntIndex:Insert[${anIterator.Value.ID}]
			}
			while ${anIterator:Next(exists)}

			if ${anIntIndex.Used} > 0
			{
				EVE:MoveItemsTo[anIntIndex, ${Me.Station.ID}, Hangar]
				wait 15
			}

			anItem:Close
		}
		else
		{
			UI:UpdateConsole["TransferContainerToHangar: Not Supported!! ${CargoIterator.Value.Name}"]
		}
	}

	function TransferListToGSC(int64 dest)
	{
		variable index:item ShipCargo
		variable iterator Cargo
		variable int QuantityToMove

		UI:UpdateConsole["DEBUG: Offloading to GSC"]

		MyShip:GetCargo[ShipCargo]
		ShipCargo:GetIterator[Cargo]

		if ${Cargo:First(exists)}
		{
			do
			{
				UI:UpdateConsole["MoveGSC: Found ${Cargo.Value.Quantity} x ${Cargo.Value.Name} - ${Entity[${dest}].CargoCapacity} - ${Entity[${dest}].UsedCargoCapacity}"]
				if (${Cargo.Value.Quantity} * ${Cargo.Value.Volume}) > (${Entity[${dest}].CargoCapacity} - ${Entity[${dest}].UsedCargoCapacity})
				{
					QuantityToMove:Set[${Math.Calc[(${Entity[${dest}].CargoCapacity} - ${Entity[${dest}].UsedCargoCapacity}) / ${Cargo.Value.Volume}]}]
				}
				else
				{
					QuantityToMove:Set[${Cargo.Value.Quantity}]
				}

				UI:UpdateConsole["MoveGSC: Moving ${QuantityToMove} units: ${Math.Calc[${QuantityToMove} * ${Cargo.Value.Volume}]}m3"]
				if ${QuantityToMove} > 0
				{
					Cargo.Value:MoveTo[${dest},CargoHold,${QuantityToMove}]
					wait 30
					if (${Entity[${dest}].CargoCapacity} - ${Entity[${dest}].UsedCargoCapacity}) < 1000
					{
						break
					}
				}

				if (${Entity[${dest}].CargoCapacity} - ${Entity[${dest}].UsedCargoCapacity}) < 1000
				{
					/* TODO - this needs to keep a queue of bookmarks, named for the can ie, "Can CORP hh:mm", of partially looted cans */
					/* Be sure its names, and not ID.  We shouldn't store anything in a bookmark name that we shouldnt know */

					UI:UpdateConsole["MoveGSC: ${Entity[${dest}].CargoCapacity} - ${Entity[${dest}].UsedCargoCapacity} < 1000"]
					break
				}
			}
			while ${Cargo:Next(exists)}
		}

	}

	function TransferListFromShipCorporateHangar(int64 dest)
	{
		variable index:item HangarCargo
		variable iterator CargoIterator
		variable float VolumeToMove=0
		variable index:int64 ListToMove

; TODO - Convert to Inventory object once entity access tested
		Entity[${dest}]:GetFleetHangarCargo[HangarCargo]
		HangarCargo:RemoveByQuery[${LavishScript.CreateQuery[Name =- "Mining Crystal"]}]

		HangarCargo:GetIterator[CargoIterator]

		UI:UpdateConsole["DEBUG: TransferListFromShipCorporateHangar", LOG_DEBUG]

		if ${CargoIterator:First(exists)}
		{
				do
				{
					if (${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}) < ${Math.Calc[${Ship.CargoFreeSpace} - ${VolumeToMove}]}
					{
						ListToMove:Insert[${CargoIterator.Value.ID}]
						VolumeToMove:Inc[${Math.Calc[${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}]}]
					}
					else
					{
						CargoIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${Math.Calc[(${Ship.CargoFreeSpace} - ${VolumeToMove}) / ${CargoIterator.Value.Volume}]}]
						break
					}
				}
				while ${CargoIterator:Next(exists)}
				if ${ListToMove.Used}
				{
					EVE:MoveItemsTo[ListToMove, MyShip, CargoHold]
				}
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferListFromShipCorporateHangar: Nothing found to move"]
			return
		}
	}

	function TransferCargoFromShipCorporateHangarToOreHold()
	{
		variable int QuantityToMove
		variable iterator CargoIterator

		call Inventory.ShipFleetHangar.Activate
		if !${Inventory.ShipFleetHangar.IsCurrent}
		{
			return
		}
		Inventory.Current:GetItems[]
		Inventory.Current.Items:GetIterator[CargoIterator]

		UI:UpdateConsole["DEBUG: TransferCargoFromShipCorporateHangarToOreHold", LOG_DEBUG]

		if ${CargoIterator:First(exists)}
		{
				do
				{
					if ${CargoIterator.Value.CategoryID} == CATEGORYID_ORE
					{
						if (${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}) > ${Ship.OreHoldFreeSpace}
						{
							QuantityToMove:Set[${Math.Calc[${Ship.OreHoldFreeSpace} / ${CargoIterator.Value.Volume}]}]
						}
						else
						{
							QuantityToMove:Set[${CargoIterator.Value.Quantity}]
						}

						UI:UpdateConsole["TransferCargoFromShipCorporateHangarToOreHold: Loading Cargo: ${QuantityToMove} units (${Math.Calc[${QuantityToMove} * ${CargoIterator.Value.Volume}]}m3) of ${CargoIterator.Value.Name}"]
						UI:UpdateConsole["TransferCargoFromShipCorporateHangarToOreHold: Loading Cargo: DEBUG: TypeID = ${CargoIterator.Value.TypeID}, GroupID = ${CargoIterator.Value.GroupID}"]
						if ${QuantityToMove} > 0
						{
							CargoIterator.Value:MoveTo[${MyShip.ID}, OreHold, ${QuantityToMove}]
							wait 15
						}

						if ${Ship.OreHoldFreeSpace} < ${Ship.OreHoldMinimumFreeSpace}
						{
							UI:UpdateConsole["DEBUG: TransferCargoFromShipCorporateHangarToOreHold: Ore Hold: ${Ship.OreHoldFreeSpace} < ${Ship.OreHoldMinimumFreeSpace}"]
							break
						}
					}
				}
				while ${CargoIterator:Next(exists)}
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferCargoFromShipCorporateHangarToOreHold: Nothing found to move"]
		}
	}

	function TransferCargoFromShipOreHoldToStation()
	{
		variable int QuantityToMove
		variable iterator CargoIterator
		if !${MyShip.HasOreHold}
		{
			return
		}

		call Inventory.ShipOreHold.Activate
		if !${Inventory.ShipOreHold.IsCurrent}
		{
			return
		}
		Inventory.Current:GetItems[]
		Inventory.Current.Items:GetIterator[CargoIterator]

		if ${CargoIterator:First(exists)}
		{
				do
				{
					QuantityToMove:Set[${CargoIterator.Value.Quantity}]
					UI:UpdateConsole["TransferCargoFromShipOreHoldToStation: Loading Cargo: ${QuantityToMove} units (${Math.Calc[${QuantityToMove} * ${CargoIterator.Value.Volume}]}m3) of ${CargoIterator.Value.Name}"]
					UI:UpdateConsole["TransferCargoFromShipOreHoldToStation: Loading Cargo: DEBUG: TypeID = ${CargoIterator.Value.TypeID}, GroupID = ${CargoIterator.Value.GroupID}"]
					if ${QuantityToMove} > 0
					{
						CargoIterator.Value:MoveTo[MyStationHangar, Hangar, ${QuantityToMove}]
						wait 15
					}
				}
				while ${CargoIterator:Next(exists)}
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferCargoFromShipOreHoldToStation: Nothing found to move"]
		}
	}

	function TransferCargoFromShipCorporateHangarToStation()
	{
		variable int QuantityToMove
		variable iterator CargoIterator

		call Inventory.ShipFleetHangar.Activate
		if !${Inventory.ShipFleetHangar.IsCurrent}
		{
			return
		}
		Inventory.Current:GetItems[]
		Inventory.Current.Items:GetIterator[CargoIterator]

		if ${CargoIterator:First(exists)}
		{
				do
				{
					QuantityToMove:Set[${CargoIterator.Value.Quantity}]
					UI:UpdateConsole["TransferCargoFromShipCorporateHangarToStation: Loading Cargo: ${QuantityToMove} units (${Math.Calc[${QuantityToMove} * ${CargoIterator.Value.Volume}]}m3) of ${CargoIterator.Value.Name}"]
					UI:UpdateConsole["TransferCargoFromShipCorporateHangarToStation: Loading Cargo: DEBUG: TypeID = ${CargoIterator.Value.TypeID}, GroupID = ${CargoIterator.Value.GroupID}"]
					if ${QuantityToMove} > 0
					{
						CargoIterator.Value:MoveTo[MyStationHangar, Hangar, ${QuantityToMove}]
						wait 15
					}
				}
				while ${CargoIterator:Next(exists)}
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferCargoFromShipCorporateHangarToStation: Nothing found to move"]
		}
	}

	function TransferCargoFromShipCorporateHangarToCargoHold()
	{
		variable int QuantityToMove
		variable iterator CargoIterator

		call Inventory.ShipFleetHangar.Activate
		if !${Inventory.ShipFleetHangar.IsCurrent}
		{
			return
		}
		Inventory.Current:GetItems[]
		Inventory.Current.Items:GetIterator[CargoIterator]

		if ${CargoIterator:First(exists)}
		{
				do
				{
					if (${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}) > ${Ship.CargoFreeSpace}
					{
						QuantityToMove:Set[${Math.Calc[${Ship.CargoFreeSpace} / ${CargoIterator.Value.Volume}]}]
					}
					else
					{
						QuantityToMove:Set[${CargoIterator.Value.Quantity}]
					}

					UI:UpdateConsole["TransferCargoFromShipCorporateHangarToCargoHold: Loading Cargo: ${QuantityToMove} units (${Math.Calc[${QuantityToMove} * ${CargoIterator.Value.Volume}]}m3) of ${CargoIterator.Value.Name}"]
					UI:UpdateConsole["TransferCargoFromShipCorporateHangarToCargoHold: Loading Cargo: DEBUG: TypeID = ${CargoIterator.Value.TypeID}, GroupID = ${CargoIterator.Value.GroupID}"]
					if ${QuantityToMove} > 0
					{
						CargoIterator.Value:MoveTo[${MyShip.ID}, CargoHold, ${QuantityToMove}]
						wait 15
					}

					if ${Ship.CargoFreeSpace} < ${Ship.CargoMinimumFreeSpace}
					{
						UI:UpdateConsole["DEBUG: TransferCargoFromShipCorporateHangarToCargoHold: Ship Cargo: ${Ship.CargoFreeSpace} < ${Ship.CargoMinimumFreeSpace}"]
						break
					}
				}
				while ${CargoIterator:Next(exists)}
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferCargoFromShipCorporateHangarToCargoHold: Nothing found to move"]
		}
	}

	function TransferCargoFromCargoHoldToShipCorporateHangar()
	{
		variable int QuantityToMove
		variable iterator CargoIterator

		call Inventory.ShipCargo.Activate
		if !${Inventory.ShipCargo.IsCurrent}
		{
			return
		}
		Inventory.Current:GetItems[]
		Inventory.Current.Items:GetIterator[CargoIterator]

		if ${CargoIterator:First(exists)}
		{
				do
				{
					if (${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}) > ${Ship.CorpHangarFreeSpace}
					{
						QuantityToMove:Set[${Math.Calc[${Ship.CorpHangarFreeSpace} / ${CargoIterator.Value.Volume}]}]
					}
					else
					{
						QuantityToMove:Set[${CargoIterator.Value.Quantity}]
					}

					UI:UpdateConsole["TransferCargoFromCargoHoldToShipCorporateHangar: Loading Cargo: ${QuantityToMove} units (${Math.Calc[${QuantityToMove} * ${CargoIterator.Value.Volume}]}m3) of ${CargoIterator.Value.Name} (Free Space: ${Ship.CorpHangarFreeSpace}m3"]
					UI:UpdateConsole["TransferCargoFromCargoHoldToShipCorporateHangar: Loading Cargo: DEBUG: TypeID = ${CargoIterator.Value.TypeID}, GroupID = ${CargoIterator.Value.GroupID}"]
					if ${QuantityToMove} > 0
					{
						CargoIterator.Value:MoveTo[${MyShip.ID}, FleetHangar, ${QuantityToMove}]
						wait 15
					}
				}
				while ${CargoIterator:Next(exists)}
		}
		else
		{
			;UI:UpdateConsole["DEBUG: obj_Cargo:TransferCargoFromCargoHoldToShipCorporateHangar: Nothing found to move"]
		}
	}
	; Call TransferListToPOSCorpHangar "LargeShipAssemblyArray"
	; Call TransferListToPOSCorpHangar "XLargeShipAssemblyArray" etc
	; Call TransferListToPOSCorpHangar "CorpHangarArray"
	; CompressionArray
	function TransferListToPOSCorpHangar(string LSAAObject)
	{
		variable float VolumeToMove=0
		variable index:int64 ListToMove
		variable iterator CargoIterator

		This.CargoToTransfer:GetIterator[CargoIterator]

		call ${LSAAObject}.Open ${${LSAAObject}.ActiveCan}
		call Inventory.EntityContainer.Activate ${${LSAAObject}.ActiveCan}

		if ${CargoIterator:First(exists)}
		{
			do
			{
				if (${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}) < ${Math.Calc[${${LSAAObject}.CargoFreeSpace} - ${VolumeToMove}]}
				{
					UI:UpdateConsole["TransferListToPOSCorpHangar(${LSAAObject}): Bulk Transferring Cargo: ${CargoIterator.Value.Name} * ${CargoIterator.Value.Quantity} Free Space: ${${LSAAObject}.CargoFreeSpace}"]
					ListToMove:Insert[${CargoIterator.Value.ID}]
					VolumeToMove:Inc[${Math.Calc[${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}]}]
				}
				else
				{
					UI:UpdateConsole["TransferListToPOSCorpHangar(${LSAAObject}): Transferring Cargo: ${CargoIterator.Value.Name} * ${CargoIterator.Value.Quantity} Free Space: ${${LSAAObject}.CargoFreeSpace}"]
					CargoIterator.Value:MoveTo[${${LSAAObject}.ActiveCan}, CorpHangars, ${Math.Calc[(${${LSAAObject}.CargoFreeSpace} - ${VolumeToMove}) / ${CargoIterator.Value.Volume}]}, "Corporation Folder 1"]
					break
				}
			}
			while ${CargoIterator:Next(exists)}
			if ${ListToMove.Used}
			{
				EVE:MoveItemsTo[ListToMove, ${${LSAAObject}.ActiveCan}, CorpHangars, "Corporation Folder 1"]
			}
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferListToPOSCorpHangar(${LSAAObject}): Nothing found to move"]
			return
		}

		${LSAAObject}:StackAllCargo[${${LSAAObject}.ActiveCan}]
	}

	function TransferListToJetCan()
	{
		variable int QuantityToMove
		variable iterator CargoIterator
		This.CargoToTransfer:GetIterator[CargoIterator]

		if ${CargoIterator:First(exists)}
		{
			do
			{
				if ${JetCan.IsReady[TRUE]}
				{
					call JetCan.Open ${JetCan.ActiveCan}

					if (${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}) > ${JetCan.CargoFreeSpace}
					{
						if ${CargoIterator.Value.Volume} > 1.0
						{
							QuantityToMove:Set[${Math.Calc[${JetCan.CargoFreeSpace} / ${CargoIterator.Value.Volume}]}]
						}
						else
						{
							; Move only what will fit, minus 1 to account for CCP rounding errors.
							QuantityToMove:Set[${Math.Calc[${JetCan.CargoFreeSpace} / ${CargoIterator.Value.Volume} - 1]}]
						}
					}
					else
					{
						QuantityToMove:Set[${CargoIterator.Value.Quantity}]
					}

					UI:UpdateConsole["TransferListToJetCan: Transferring Cargo: ${QuantityToMove} units (${Math.Calc[${QuantityToMove} * ${CargoIterator.Value.Volume}]}m3) of ${CargoIterator.Value.Name} - Jetcan Free Space: ${JetCan.CargoFreeSpace}"]
					CargoIterator.Value:MoveTo[${JetCan.ActiveCan}, CargoHold, ${QuantityToMove}]
				}
				else
				{
					UI:UpdateConsole["TransferListToJetCan: Ejecting Cargo: ${CargoIterator.Value.Quantity} units of ${CargoIterator.Value.Name}"]
					CargoIterator.Value:Jettison
					call JetCan.WaitForCan
					JetCan:Rename
				}
			}
			while ${CargoIterator:Next(exists)}
			JetCan:StackAllCargo
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferListToJetCan: Nothing found to move"]
		}
	}

	member:int QuantityToMove(item src, item dest)
	{
		variable int qty = 0

		UI:UpdateConsole["DEBUG: QuantityToMove: ${src} ${dest}"]

		if ${src(exists)}
		{
			if ${dest(exists)} && ${dest} > 0
			{	/* assume destination is a container */
				if (${src.Quantity} * ${src.Volume}) > ${This.ContainerFreeSpace[${dest}]}
				{
					if ${src.Volume} > 1.0
					{
						qty:Set[${Math.Calc[${This.ContainerFreeSpace[${dest}]} / ${src.Volume}]}]
					}
					else
					{
						; Move only what will fit, minus 1 to account for CCP rounding errors.
						qty:Set[${Math.Calc[${This.ContainerFreeSpace[${dest}]} / ${src.Volume} - 1]}]
					}
				}
				else
				{
					qty:Set[${src.Quantity}]
				}
			}
			else
			{	/* assume destination is ship's cargo hold */
				if (${src.Quantity} * ${src.Volume}) > ${Ship.CargoFreeSpace}
				{
					if ${src.Volume} > 1.0
					{
						qty:Set[${Math.Calc[${Ship.CargoFreeSpace} / ${src.Volume}]}]
					}
					else
					{
						; Move only what will fit, minus 1 to account for CCP rounding errors.
						qty:Set[${Math.Calc[${Ship.CargoFreeSpace} / ${src.Volume} - 1]}]
					}
				}
				else
				{
					qty:Set[${src.Quantity}]
				}
			}
		}

		UI:UpdateConsole["DEBUG: QuantityToMove: returning ${qty}"]

		return ${qty}
	}

	function TransferListToShipWithContainers()
	{
		variable iterator   listItemIterator
		variable index:item shipContainerIndex
		variable iterator   shipContainerIterator
		variable int qty
		variable int cnt
		variable int idx

		if ${This.CargoToTransfer.Used} == 0
		{
			return
		}

		call Inventory.ShipCargo.Activate
		if !${Inventory.ShipCargo.IsCurrent}
		{
			UI:UpdateConsole["TransferListToShipWithContainers: Failed to activate ${Inventory.ShipCargo.EVEWindowParams}"]
			return
		}
		Inventory.Current:GetItems[shipContainerIndex, "CategoryID == GROUPID_SECURE_CONTAINER"]

		/* move the list to containers */
		shipContainerIndex:GetIterator[shipContainerIterator]
		if ${shipContainerIterator:First(exists)}
		do
		{
			shipContainerIterator.Value:Open
			wait 15
			cnt:Set[${This.CargoToTransfer.Used}]
			for (idx:Set[1] ; ${idx}<=${cnt} ; idx:Inc)
			{
				variable float usedSpace
				variable float totalSpace

				do
				{
					usedSpace:Set[${shipContainerIterator.Value.UsedCargoCapacity}]
					wait 2
				}
				while ${usedSpace} < 0
				totalSpace:Set[${shipContainerIterator.Value.Capacity}]
				;;UI:UpdateConsole["DEBUG: TransferListToShipWithContainers: used space = ${usedSpace}"]
				;;UI:UpdateConsole["DEBUG: TransferListToShipWithContainers: total space = ${totalSpace}"]
				if (${This.CargoToTransfer.Get[${idx}].Quantity} * ${This.CargoToTransfer.Get[${idx}].Volume}) > ${Math.Calc[${totalSpace}-${usedSpace}]}
				{
					if ${This.CargoToTransfer.Get[${idx}].Volume} > 1.0
					{
						qty:Set[${Math.Calc[${totalSpace}-${usedSpace} / ${This.CargoToTransfer.Get[${idx}].Volume}]}]
					}
					else
					{
						; Move only what will fit, minus 1 to account for CCP rounding errors.
						qty:Set[${Math.Calc[${totalSpace}-${usedSpace} / ${This.CargoToTransfer.Get[${idx}].Volume} - 1]}]
					}
				}
				else
				{
					qty:Set[${This.CargoToTransfer.Get[${idx}].Quantity}]
				}
				;;UI:UpdateConsole["DEBUG: TransferListToShipWithContainers: quantity = ${qty}"]
				if ${qty} > 0
				{
					UI:UpdateConsole["TransferListToShipWithContainers: Loading Cargo: ${qty} units (${Math.Calc[${qty} * ${This.CargoToTransfer.Get[${idx}].Volume}]}m3) of ${This.CargoToTransfer.Get[${idx}].Name}"]
					This.CargoToTransfer.Get[${idx}]:MoveTo[${shipContainerIterator.Value.ID}, CargoHold, ${qty}]
					wait 15
				}
				if ${qty} == ${This.CargoToTransfer.Get[${idx}].Quantity}
				{
					This.CargoToTransfer:Remove[${idx}]
				}
				do
				{
					usedSpace:Set[${shipContainerIterator.Value.UsedCargoCapacity}]
					wait 2
				}
				while ${usedSpace} < 0
				;;UI:UpdateConsole["DEBUG: TransferListToShipWithContainers: used space = ${usedSpace}"]
				if ${Math.Calc[${totalSpace}-${usedSpace}]} > ${Math.Calc[${totalSpace}*0.98]}
				{
					UI:UpdateConsole["DEBUG: TransferListToShipWithContainers: Container full."]
					break
				}
			}
			This.CargoToTransfer:Collapse
			shipContainerIterator.Value:Close

			if ${This.CargoToTransfer.Used} == 0
			{	/* everything moved */
				break
			}
		}
		while ${shipContainerIterator:Next(exists)}

		/* move the list to the ship */
		cnt:Set[${This.CargoToTransfer.Used}]
		for (idx:Set[1] ; ${idx}<=${cnt} ; idx:Inc)
		{
			qty:Set[${This.QuantityToMove[${This.CargoToTransfer.Get[${idx}]},0]}]
			if ${qty} > 0
			{
				UI:UpdateConsole["TransferListToShipWithContainers: Loading Cargo: ${qty} units (${Math.Calc[${qty} * ${This.CargoToTransfer.Get[${idx}].Volume}]}m3) of ${This.CargoToTransfer.Get[${idx}].Name}"]
				This.CargoToTransfer.Get[${idx}]:MoveTo[MyShip, CargoHold, ${qty}]
				wait 15
			}
			if ${qty} == ${This.CargoToTransfer.Get[${idx}].Quantity}
			{
				This.CargoToTransfer:Remove[${idx}]
			}
			;if ${Ship.CargoFull}
			;{
			;	UI:UpdateConsole["DEBUG: TransferListToShipWithContainers: Ship Cargo: ${Ship.CargoFreeSpace} < ${Ship.CargoMinimumFreeSpace}"]
			;	break
			;}
		}
		This.CargoToTransfer:Collapse
	}

	function TransferListToShip()
	{
		variable int QuantityToMove
		variable iterator CargoIterator
		This.CargoToTransfer:GetIterator[CargoIterator]

		if ${This.CargoToTransfer.Used} == 0
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferListToShip: Nothing found to move"]
			return
		}

		if ${CargoIterator:First(exists)}
		{
			if ${This.ShipHasContainers}
			{
				call This.TransferListToShipWithContainers
			}
			else
			{
				do
				{
					if (${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}) > ${Ship.CargoFreeSpace}
					{
						if ${CargoIterator.Value.Volume} > 1.0
						{
							QuantityToMove:Set[${Math.Calc[${Ship.CargoFreeSpace} / ${CargoIterator.Value.Volume}]}]
						}
						else
						{
							; Move only what will fit, minus 1 to account for CCP rounding errors.
							QuantityToMove:Set[${Math.Calc[${Ship.CargoFreeSpace} / ${CargoIterator.Value.Volume} - 1]}]
						}
					}
					else
					{
						QuantityToMove:Set[${CargoIterator.Value.Quantity}]
					}

					UI:UpdateConsole["TransferListToShip: Loading Cargo: ${QuantityToMove} units (${Math.Calc[${QuantityToMove} * ${CargoIterator.Value.Volume}]}m3) of ${CargoIterator.Value.Name}"]
					UI:UpdateConsole["TransferListToShip: Loading Cargo: DEBUG: TypeID = ${CargoIterator.Value.TypeID}, GroupID = ${CargoIterator.Value.GroupID}"]
					if ${QuantityToMove} > 0
					{
						CargoIterator.Value:MoveTo[MyShip, CargoHold, ${QuantityToMove}]
						wait 15
					}

					if ${Ship.CargoFreeSpace} < ${Ship.CargoMinimumFreeSpace}
					{
						UI:UpdateConsole["DEBUG: TransferListToShip: Ship Cargo: ${Ship.CargoFreeSpace} < ${Ship.CargoMinimumFreeSpace}"]
						break
					}
				}
				while ${CargoIterator:Next(exists)}
			}
			wait 10
		}
	}

	function TransferOreToCorpHangarArray()
	{
		if ${CorpHangarArray.IsReady}
		{
			if ${Entity[${CorpHangarArray.ActiveCan}].Distance} > CORP_HANGAR_LOOT_RANGE
			{
				call Ship.Approach ${CorpHangarArray.ActiveCan} CORP_HANGAR_LOOT_RANGE
			}
		}
		else
		{
			UI:ConsoleUpdate["No Hangar Array found - nothing moved"]
			return
		}

		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToPOSCorpHangar "CorpHangarArray"
		}

		call Inventory.ShipOreHold.Activate
		if ${Inventory.ShipOreHold.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToPOSCorpHangar "CorpHangarArray"
		}

		This.CargoToTransfer:Clear[]
	}

	function TransferOreToLargeShipAssemblyArray()
	{
		if ${LargeShipAssemblyArray.IsReady}
		{
			if ${Entity[${LargeShipAssemblyArray.ActiveCan}].Distance} > CORP_HANGAR_LOOT_RANGE
			{
				call Ship.Approach ${LargeShipAssemblyArray.ActiveCan} CORP_HANGAR_LOOT_RANGE
			}
		}
		else
		{
			UI:ConsoleUpdate["No Large Ship Assembly Array found - nothing moved"]
			return
		}

		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToPOSCorpHangar "LargeShipAssemblyArray"
		}

		call Inventory.ShipOreHold.Activate
		if ${Inventory.ShipOreHold.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToPOSCorpHangar "LargeShipAssemblyArray"
		}

		This.CargoToTransfer:Clear[]
	}

	function TransferOreToCompressionArray()
	{
		if ${CompressionArray.IsReady}
		{
			if ${Entity[${CompressionArray.ActiveCan}].Distance} > CORP_HANGAR_LOOT_RANGE
			{
				call Ship.Approach ${CompressionArray.ActiveCan} CORP_HANGAR_LOOT_RANGE
			}
		}
		else
		{
			UI:ConsoleUpdate["No Compression Array found - nothing moved"]
			return
		}

		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToPOSCorpHangar "CompressionArray"
		}

		call Inventory.ShipOreHold.Activate
		if ${Inventory.ShipOreHold.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToPOSCorpHangar "CompressionArray"
		}

		This.CargoToTransfer:Clear[]
	}

	function TransferCargoToLargeShipAssemblyArray()
	{
		if ${LargeShipAssemblyArray.IsReady}
		{
			if ${Entity[${LargeShipAssemblyArray.ActiveCan}].Distance} > CORP_HANGAR_LOOT_RANGE
			{
				call Ship.Approach ${LargeShipAssemblyArray.ActiveCan} CORP_HANGAR_LOOT_RANGE
			}
		}
		else
		{
			UI:ConsoleUpdate["No Large Ship Assembly Array found - nothing moved"]
			return
		}

		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer]
			call This.TransferListToPOSCorpHangar "LargeShipAssemblyArray"
		}

		This.CargoToTransfer:Clear[]
	}

	function TransferCargoFromLargeShipAssemblyArray()
	{
		if ${LargeShipAssemblyArray.IsReady}
		{
			if ${Entity[${LargeShipAssemblyArray.ActiveCan}].Distance} > CORP_HANGAR_LOOT_RANGE
			{
				call Ship.Approach ${LargeShipAssemblyArray.ActiveCan} CORP_HANGAR_LOOT_RANGE
			}
		}
		else
		{
			UI:ConsoleUpdate["No Large Ship Assembly Array found - nothing moved"]
			return
		}

		variable float VolumeToMove = 0
		variable index:int64 ListToMove
		variable index:item LSAACargo
		variable iterator CargoIterator

		call Inventory.ShipCargo.Activate
		call LargeShipAssemblyArray.Open ${LargeShipAssemblyArray.ActiveCan}

		Entity[${LargeShipAssemblyArray.ActiveCan}]:GetCorpHangarsCargo[LSAACargo]
		LSAACargo:GetIterator[CargoIterator]

		if ${CargoIterator:First(exists)}
		{
				do
				{
						if (${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}) < ${Math.Calc[${Ship.CargoFreeSpace} - ${VolumeToMove}]}
						{
							ListToMove:Insert[${CargoIterator.Value.ID}]
							VolumeToMove:Inc[${Math.Calc[${CargoIterator.Value.Quantity} * ${CargoIterator.Value.Volume}]}]
						}
						else
						{
							CargoIterator.Value:MoveTo[MyShip, CargoHold, ${Math.Calc[(${Ship.CargoFreeSpace} - ${VolumeToMove}) / ${CargoIterator.Value.Volume}]}]
							break
						}
				}
				while ${CargoIterator:Next(exists)}
				if ${ListToMove.Used}
				{
					EVE:MoveItemsTo[ListToMove, MyShip, CargoHold]
				}
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferCargoFromLargeShipAssemblyArray: Nothing found to move"]
			return
		}
	}

	function TransferOreToXLargeShipAssemblyArray()
	{
		if ${XLargeShipAssemblyArray.IsReady}
		{
			if ${Entity[${XLargeShipAssemblyArray.ActiveCan}].Distance} > CORP_HANGAR_LOOT_RANGE
			{
				call Ship.Approach ${XLargeShipAssemblyArray.ActiveCan} CORP_HANGAR_LOOT_RANGE
			}
		}
		else
		{
			UI:ConsoleUpdate["No Extra Large Ship Assembly Array found - nothing moved"]
			return
		}

		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToPOSCorpHangar "XLargeShipAssemblyArray"
		}

		call Inventory.ShipOreHold.Activate
		if ${Inventory.ShipOreHold.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToPOSCorpHangar "XLargeShipAssemblyArray"
		}

		This.CargoToTransfer:Clear[]
	}

	function TransferOreToJetCan()
	{
		UI:UpdateConsole["Transferring Ore to JetCan"]

		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToJetCan
		}

		call Inventory.ShipOreHold.Activate
		if ${Inventory.ShipOreHold.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToJetCan
		}

		This.CargoToTransfer:Clear[]
	}

	function TransferOreToStationHangar()
	{
		while !${Station.Docked}
		{
			UI:UpdateConsole["obj_Cargo: Waiting for dock..."]
			wait 10
		}

		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToStationHangar
		}

		call Inventory.ShipOreHold.Activate
		if ${Inventory.ShipOreHold.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToStationHangar
		}

		This.CargoToTransfer:Clear[]
		Ship:UpdateBaselineUsedCargo[]
		call This.ReplenishCrystals
	}

	; Transfer ALL items in MyCargo index
	function TransferListToStationHangar()
	{
		variable index:int64 ListToMove
		variable iterator CargoIterator
		This.CargoToTransfer:GetIterator[CargoIterator]

		if ${CargoIterator:First(exists)}
		{
			do
			{
				UI:UpdateConsole["TransferListToStationHangar: Unloading Cargo: ${CargoIterator.Value.Name} x ${CargoIterator.Value.Quantity}"]
				UI:UpdateConsole["TransferListToStationHangar: Unloading Cargo: DEBUG: TypeID = ${CargoIterator.Value.TypeID}, GroupID = ${CargoIterator.Value.GroupID}", LOG_DEBUG]
				if ${CargoIterator.Value.GroupID} == GROUPID_SECURE_CONTAINER
				{
					call This.TransferContainerToHangar ${CargoIterator.Value.ID}
				}
				else
				{
					ListToMove:Insert[${CargoIterator.Value.ID}]
				}
			}
			while ${CargoIterator:Next(exists)}
			if ${ListToMove.Used}
			{
				UI:UpdateConsole["Moving ${ListToMove.Used} items to hangar."]
				EVE:MoveItemsTo[ListToMove, MyStationHangar, Hangar]
				wait 10
			}
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferListToStationHangar: Nothing found to move"]
		}
		EVE:StackItems[MyStationHangar,Hangar]

		EVEWindow[ByItemID, ${MyShip.ID}]:StackAll
	}

	function TransferListToShipCorporateHangar(int64 dest)
	{
		variable index:int64 ListToMove
		variable iterator CargoIterator
		This.CargoToTransfer:GetIterator[CargoIterator]

		if ${CargoIterator:First(exists)}
		{
			do
			{
				UI:UpdateConsole["TransferListToShipCorporateHangar: Unloading Cargo: ${CargoIterator.Value.Name} x ${CargoIterator.Value.Quantity}"]
				UI:UpdateConsole["TransferListToShipCorporateHangar: Unloading Cargo: DEBUG: TypeID = ${CargoIterator.Value.TypeID}, GroupID = ${CargoIterator.Value.GroupID}", LOG_DEBUG]

				ListToMove:Insert[${CargoIterator.Value.ID}]
				if ${ListToMove.Used}
				{
					UI:UpdateConsole["Moving ${ListToMove.Used} items to hangar."]
					CargoIterator.Value:MoveTo[${dest}, FleetHangar, ${CargoIterator.Value.Quantity}]
					wait 10
				}
			}
			while ${CargoIterator:Next(exists)}
		}
		else
		{
			UI:UpdateConsole["DEBUG: obj_Cargo:TransferListToShipCorporateHangar: Nothing found to move"]
		}
	}

	function TransferOreToShipCorpHangar(int64 dest)
	{
		UI:UpdateConsole["Transferring Ore to Corp Hangar"]

		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToShipCorporateHangar ${dest}
		}

		call Inventory.ShipOreHold.Activate
		if ${Inventory.ShipOreHold.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "CategoryID == CATEGORYID_ORE"]
			call This.TransferListToShipCorporateHangar ${dest}
		}

		This.CargoToTransfer:Clear[]
	}

	function TransferCargoToStationHangar()
	{
		while !${Station.Docked}
		{
			UI:UpdateConsole["obj_Cargo: Waiting for dock..."]
			wait 10
		}

		UI:UpdateConsole["Transferring Cargo to Station Hangar"]
		
		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer]
			call This.TransferListToStationHangar
		}

		This.CargoToTransfer:Clear[]
		Ship:UpdateBaselineUsedCargo[]
	}

	function TransferCargoToCorpHangarArray()
	{
		UI:UpdateConsole["Transferring Cargo to Corp Hangar Array"]

		call Inventory.ShipCargo.Activate
		if ${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer]
			call This.TransferListToPOSCorpHangar "CorpHangarArray"
		}

		This.CargoToTransfer:Clear[]
		EVEWindow[ByName, "hangarFloor"]:StackAll
		Ship:UpdateBaselineUsedCargo[]
	}

	function TransferHangarItemToShip(int typeID = -1)
	{
		variable string querystr

		if !${Station.Docked}
		{
			m_LastTransferComplete:Set[TRUE]
		}
		else
		{
			if ${typeID == -1}
			{
				UI:UpdateConsole["Transferring all items from Station Hangar"]
			}
			else
			{
				UI:UpdateConsole["Transferring Item (${typeID}) from Station Hangar"]
				querystr:Set["TypeID == ${typeID}"]
			}

			call Inventory.StationHangar.Activate ${Me.Station.ID}
			if ${Inventory.StationHangar.IsCurrent}
			{
				Inventory.Current:GetItems[This.CargoToTransfer, ${querystr}]
				if ${This.CargoToTransfer.Used} > 0
				{
					call This.TransferListToShip
					EVEWindow[ByItemID, ${MyShip.ID}]:StackAll
					Ship:UpdateBaselineUsedCargo[]

					Inventory.Current:GetItems[This.CargoToTransfer, ${querystr}]
					if ${This.CargoToTransfer.Used} > 0
					{
						UI:UpdateConsole["Could not carry all the cargo from the station hangar"]
						m_LastTransferComplete:Set[FALSE]
					}
					else
					{
						UI:UpdateConsole["Transfered all cargo from the station hangar"]
						m_LastTransferComplete:Set[TRUE]
					}
				}
				else
				{	/* Only set m_LastTransferComplete if we actually transfered something */
					UI:UpdateConsole["Couldn't find any cargo in the station hangar"]
					m_LastTransferComplete:Set[FALSE]
				}
			}
		}
	}

	function TransferItemTypeToHangar(int typeID)
   {
	  if !${Station.Docked}
	  {
		 	UI:UpdateConsole["ERROR: obj_Cargo.TransferItemTypeToHangar: Must be docked!"]
		 	return
	  }

	  UI:UpdateConsole["Transferring Cargo to Station Hangar"]

		call Inventory.ShipCargo.Activate
		if !${Inventory.ShipCargo.IsCurrent}
		{
			Inventory.Current:GetItems[This.CargoToTransfer, "TypeID == ${typeID}"]
		  call This.TransferListToStationHangar
		}

	  This.CargoToTransfer:Clear[]
	  Ship:UpdateBaselineUsedCargo[]
   }

	function TransferSpawnContainerCargoToShip()
	{
	}
}
