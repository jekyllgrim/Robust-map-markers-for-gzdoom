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
                showdropped = CVar.GetCVar('smm_showdropped', players[consoleplayer]);

            if (e.thing.bISMONSTER)
            {
                valid = true;
                visCvarName = 'smm_showmonsters';
                thingtype = JGP_SafeMapMarker.SMM_MONSTER;
            }

            if (item && (!item.bTOSSED || showdropped.GetBool()))
            {
                if (item is 'Key')
                {
                    valid = true;
                    visCvarName = 'smm_showkeys';
                    thingtype = JGP_SafeMapMarker.SMM_KEY;
                }

                else if (item is 'Weapon')
                {
                    valid = true;
                    visCvarName = 'smm_showweapons';
                    thingtype = JGP_SafeMapMarker.SMM_WEAPON;
                }

                else if (item is 'Ammo')
                {
                    valid = true;
                    visCvarName = 'smm_showammo';
                    thingtype = JGP_SafeMapMarker.SMM_AMMO;
                }

                else if (item is 'PowerupGiver' || item.bBIGPOWERUP)
                {
                    valid = true;
                    visCvarName = 'smm_showartifacts';
                    thingtype = JGP_SafeMapMarker.SMM_ARTIFACT;
                }

                else
                {
                    valid = true;
                    visCvarName = 'smm_showotheritems';
                    thingtype = JGP_SafeMapMarker.SMM_OTHERITEMS;
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
        SMM_MONSTER,
        SMM_KEY,
        SMM_WEAPON,
        SMM_AMMO,
        SMM_ARTIFACT,
        SMM_OTHERITEMS,
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

        JGP_SafeMapMarker smm = JGP_SafeMapMarker(Actor.Spawn("JGP_SafeMapMarker"));
        if (smm)
        {
            smm.attachToSprite = ssprite;
            smm.sprite = ssprite;
            smm.frame = sstate.frame;
            smm.scale = attachTo.scale * 0.25;
            smm.attachTo = attachTo;
            smm.thingtype = thingtype;
            smm.visCvarName = visCvarName;
            if (attachTo is 'Inventory')
                smm.invAttachTo = Inventory(attachTo);
        }

        return smm;
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
            scaleCvar = CVar.GetCVar('smm_markerscale', players[consoleplayer]);
        
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