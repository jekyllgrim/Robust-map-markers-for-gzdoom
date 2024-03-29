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
			if (item && item.owner)
				return;

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
    transient CVar deadCvar;
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
		string spritename = TexMan.GetName(sstate.GetSpriteTexture(0));
		spritename = spritename.Left(4);
		//console.printf("%s spritename: %s - %s", attachTo.GetTag(), spritename, (spritename ~== "TNT1") ? "\c[Red]INVALID" : "\c[Green]VALID");
        if (!ssprite || spritename ~== "TNT1")
		{
			while (sstate && sstate.nextstate)
			{
				sstate = sstate.nextstate;
				spritename = TexMan.GetName(sstate.GetSpriteTexture(0));
				spritename = spritename.Left(4);
				if (!(spritename ~== "TNT1"))
				{
					ssprite = sstate.sprite;
					break;
				}
			}
		}
		//console.printf("%s spritename: %s - %s", attachTo.GetTag(), spritename, (spritename ~== "TNT1") ? "\c[Red]INVALID" : "\c[Green]VALID");
		
		if (!ssprite || spritename ~== "TNT1")
		{
			return null;
		}
		
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
        bool shouldBeVisible = true;

        if (!visCvar && visCvarName != 'none')
        {
            visCvar = CVar.GetCVar(visCvarName, players[consoleplayer]);
        }

        if (!deadCvar)
        {
            deadCvar = CVar.GetCVar('rmm_showcorpses', players[consoleplayer]);
        }

        shouldBeVisible = !attachTo.bNOSECTOR && (visCvar && visCvar.GetBool());        
        if (thingtype == RMM_MONSTER)
            shouldBeVisible = shouldBeVisible && (!attachTo.bKILLED || (deadCvar && deadCvar.GetBool()));

        if (!hidden && !shouldBeVisible)
        {
            hidden = true;
            sprite = GetSpriteIndex("TNT1");
        }

        else if (hidden && shouldBeVisible)
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
            attachToSprite = deathstate.sprite;
            frame = deathstate.frame;
        }

        if (bKILLED && !attachTo.bKILLED)
        {
            bKILLED = false;
            state sspawnstate = attachTo.Spawnstate;
            if (!sspawnstate || !sspawnstate.sprite)
            {
                Destroy();
                return;
            }
            attachToSprite = sspawnstate.sprite;
            frame = sspawnstate.frame;
        }
	}
}