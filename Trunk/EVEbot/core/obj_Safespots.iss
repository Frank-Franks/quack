objectdef obj_Safespots
{
	variable string SVN_REVISION = "$Rev$"
	variable int Version

	variable index:bookmark SafeSpots
	variable iterator SafeSpotIterator

	method Initialize()
	{
		UI:UpdateConsole["obj_Safespots: Initialized", LOG_MINOR]
	}

	method ResetSafeSpotList()
	{
		SafeSpots:Clear
		EVE:DoGetBookmarks[SafeSpots]
	
		variable int idx
		idx:Set[${SafeSpots.Used}]
		
		while ${idx} > 0
		{
			variable string Prefix
			Prefix:Set[${Config.Labels.SafeSpotPrefix}]
			
			variable string Label
			Label:Set[${SafeSpots.Get[${idx}].Label}]			
			if ${Label.Left[${Prefix.Length}].NotEqual[${Prefix}]}
			{
				SafeSpots:Remove[${idx}]
			}
			elseif ${SafeSpots.Get[${idx}].SolarSystemID} != ${Me.SolarSystemID}
			{
				SafeSpots:Remove[${idx}]
			}
			
			idx:Dec
		}		
		SafeSpots:Collapse
		SafeSpots:GetIterator[SafeSpotIterator]
		
		UI:UpdateConsole["ResetSafeSpotList found ${SafeSpots.Used} safespots in this system."]
	}
	
	function WarpToNextSafeSpot()
	{
		if ${SafeSpots.Used} == 0 
		{
			This:ResetSafeSpotList
		}		
		
		if ${SafeSpots.Get[1](exists)} && ${SafeSpots.Get[1].SolarSystemID} != ${Me.SolarSystemID}
		{
			This:ResetSafeSpotList
		}
		
		if !${SafeSpotIterator:Next(exists)}
		{
			SafeSpotIterator:First
		}
		
		if ${SafeSpotIterator.Value(exists)}
		{
			call Ship.WarpToBookMark ${SafeSpotIterator.Value.ID}
		}
		else
		{
			UI:UpdateConsole["ERROR: obj_Safespots.WarpToNextSafeSpot found an invalid bookmark!"]			
		}
	}

	member:bool IsAtSafespot()
	{
		if ${SafeSpots.Used} == 0 
		{
			This:ResetSafeSpotList
		}
		
		; big debug block to get to the bottom of the "safe spot problem"
		;UI:UpdateConsole["DEBUG: obj_Safespots.IsAtSafespot: ItemID = ${SafeSpotIterator.Value.ItemID}"]
		;UI:UpdateConsole["DEBUG: obj_Safespots.IsAtSafespot: SS_X = ${SafeSpotIterator.Value.X}"]
		;UI:UpdateConsole["DEBUG: obj_Safespots.IsAtSafespot: SS_Y = ${SafeSpotIterator.Value.Y}"]
		;UI:UpdateConsole["DEBUG: obj_Safespots.IsAtSafespot: SS_Z = ${SafeSpotIterator.Value.Z}"]
		;UI:UpdateConsole["DEBUG: obj_Safespots.IsAtSafespot: ME_X = ${Me.ToEntity.X}"]
		;UI:UpdateConsole["DEBUG: obj_Safespots.IsAtSafespot: ME_Y = ${Me.ToEntity.Y}"]
		;UI:UpdateConsole["DEBUG: obj_Safespots.IsAtSafespot: ME_Z = ${Me.ToEntity.Z}"]
		;UI:UpdateConsole["DEBUG: obj_Safespots.IsAtSafespot: DIST = ${Math.Distance[${Me.ToEntity.X}, ${Me.ToEntity.Y}, ${Me.ToEntity.Z}, ${SafeSpotIterator.Value.X}, ${SafeSpotIterator.Value.Y}, ${SafeSpotIterator.Value.Z}]}"]

		; Are we within 150km of the bookmark?
		if ${SafeSpotIterator.Value.ItemID(exists)}
		{
			if ${Me.ToEntity.DistanceTo[${SafeSpotIterator.Value.ItemID}]} < WARP_RANGE
			{
				return TRUE
			}
		}
		elseif ${Math.Distance[${Me.ToEntity.X}, ${Me.ToEntity.Y}, ${Me.ToEntity.Z}, ${SafeSpotIterator.Value.X}, ${SafeSpotIterator.Value.Y}, ${SafeSpotIterator.Value.Z}]} < WARP_RANGE
		{
			return TRUE
		}
		
		return FALSE		
	}
	
	function WarpTo()
	{
		call This.WarpToNextSafeSpot
	}
}

