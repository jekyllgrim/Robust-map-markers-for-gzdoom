version "4.8"

class JGP_SafeMapMarkerHandler : EventHandler
{
    transient CVar showdropped;

    override void WorldThingSpawned(worldEvent e)
    {
        if (e.thing && PlayerInGame[consoleplayer])
        {
            bool valid;
            int thingtype;
            name visCvarName;
            Inventory item = Inventory(e.thing);

            if (!showdropped)
                showdropped = CVar.GetCVar('rmm_showdropped', players[consoleplayer]);

            if (e.thing.bISMONSTER)
            {
                valid = true;
                visCvarName = 'rmm_showmonsters';
                thingtype = JGP_SafeMapMarker.rmm_MONSTER;
            }

            if (item && (!item.bTOSSED || showdropped.GetBool()))
            {
                if (item is 'Key')
                {
                    valid = true;
                    visCvarName = 'rmm_showkeys';
                    thingtype = JGP_SafeMapMarker.rmm_KEY;
                }

                else if (item is 'Weapon')
                {
                    valid = true;
                    visCvarName = 'rmm_showweapons';
                    thingtype = JGP_SafeMapMarker.rmm_WEAPON;
                }

                else if (item is 'Ammo')
                {
                    valid = true;
                    visCvarName = 'rmm_showammo';
                    thingtype = JGP_SafeMapMarker.rmm_AMMO;
                }

                else if (item is 'Health')
                {
                    valid = true;
                    visCvarName = 'rmm_showhealth';
                    thingtype = JGP_SafeMapMarker.rmm_AMMO;
                }

                else if (item is 'PowerupGiver' || item.bBIGPOWERUP)
                {
                    valid = true;
                    visCvarName = 'rmm_showartifacts';
                    thingtype = JGP_SafeMapMarker.rmm_ARTIFACT;
                }

                else
                {
                    valid = true;
                    visCvarName = 'rmm_showotheritems';
                    thingtype = JGP_SafeMapMarker.rmm_OTHERITEMS;
                }
            }

            if (valid)
            {
                JGP_SafeMapMarker.Create(e.thing, thingtype, visCvarName);
            }
        }
    }
}

// A version of map marker than can be safely spawned per player
// and won't desync the game:
class JGP_SafeMapMarker : MapMarker 
{
	Actor attachTo;
	Inventory invAttachTo;
    SpriteID attachToSprite;
    bool hidden;
    int thingtype;
    transient CVar scaleCvar;
    transient CVar visCvar;
    name visCvarName;

	Default 
	{
		+NOINTERACTION
		+NOBLOCKMAP
		+SYNCHRONIZED
		+DONTBLAST
		FloatBobPhase 0;
	}

    enum ItemTypes
    {
        rmm_MONSTER,
        rmm_KEY,
        rmm_WEAPON,
        rmm_AMMO,
        rmm_ARTIFACT,
        rmm_OTHERITEMS,
    }

	state GetFinalDeathState()
    {
		if (!attachTo)
			return null;		
		
		state targetstate = attachTo.ResolveState("Death");
		if (!targetstate)
			targetstate = attachTo.ResolveState("XDeath");
		if (!targetstate)
			return null;
		
		while (targetstate && targetstate.nextstate && targetstate.tics != -1)
        {
			targetstate = targetstate.nextstate;
		}

		return targetstate;
	}

    static JGP_SafeMapMarker Create(Actor attachTo, int thingtype = -1, name visCvarName = 'none')
    {
        if (!attachTo)
            return null;

        let sstate = attachTo.spawnState;
        if (!sstate)
            return null;
        
        let ssprite = sstate.sprite;
        if (!ssprite)
            return null;

        JGP_SafeMapMarker rmm = JGP_SafeMapMarker(Actor.Spawn("JGP_SafeMapMarker"));
        if (rmm)
        {
            rmm.attachToSprite = ssprite;
            rmm.sprite = ssprite;
            rmm.frame = sstate.frame;
            rmm.scale = attachTo.scale * 0.25;
            rmm.attachTo = attachTo;
            rmm.thingtype = thingtype;
            rmm.visCvarName = visCvarName;
            if (attachTo is 'Inventory')
                rmm.invAttachTo = Inventory(attachTo);
        }

        return rmm;
    }

    void ShowHide()
    {
        bool vis = true;
        if (!visCvar && visCvarName != 'none') {
            visCvar = CVar.GetCVar(visCvarName, players[consoleplayer]);
        }

        if (visCvar)            
            vis = visCvar.GetBool();

        if (!hidden && (!vis || attachTo.bNOSECTOR))
        {
            hidden = true;
            sprite = GetSpriteIndex("TNT1");
            return;
        }

        if (hidden && !attachTo.bNOSECTOR && vis)
        {
            hidden = false;
            sprite = attachToSprite;
        }
    }

	override void Tick()
	{
		if (!attachTo || (invAttachTo && invAttachTo.owner))
		{
			Destroy();
			return;
		}

        ShowHide();

        if (!scaleCvar)
            scaleCvar = CVar.GetCVar('rmm_markerscale', players[consoleplayer]);
        
        scale = attachTo.scale * scaleCvar.GetFloat();
        
        if (!bNOSECTOR)
        {
		    SetOrigin(attachTo.pos, true);
        }

        if (!bKILLED && attachTo.bKILLED)
        {
            bKILLED = true;
            state deathstate = GetFinalDeathState();
            if (!deathstate || !deathstate.sprite)
            {
                Destroy();
                return;
            }
            sprite = deathstate.sprite;
            frame = deathstate.frame;
        }
	}
}