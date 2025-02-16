---
CROMHⒶ'S HERE
---

NOTE: **This repository is simply for myself so stay out, unless you're interested in my dookie F-15.**

My project is to add more of nice shit, by inspiring from other flight gear aircraft cuz I ain't very productive at making shit from myself that I don't really know a thing about so it's mainly copying and tweaking. This has for goal to add more effects to the model, and cleaner it (if to cleaner even exists as a word), but mainly add the F-15E (maybe it'll keep the same cockpit model idk) variant so air/ground actually works, add more rounds capacity to the gun (current is 675 and F-15E is 940), make so that MK-84s can be stocked in three, so that the bombs capacity is tripled (from 3 to 9). Probably some other shit too as upgrading the engines.

So what's actually been done for now?

* Added new liveries:
  - 162nd Fighter Wing
  - 162nd Fighter Wing (Black)
  - 162nd Fighter Wing (Zebra)
  - 75th Anniversary
  - 65Th Flanker
  - JASDF 305th Nyutabaru Air Show
  - 55 23rd Flying Tigers
* Added the F-100-PW-229 to the F-15E variant, other variants keep the older F-100-PW-220
* Added mach cone, strake and G vortex vapor effects (taken from the dear flight gear F-16 model) (may be up for some tweaking (some day))
* Updated the flares' effect (using F-16's ones)
* Added some more cool preview screenshots cuz why not
* Made the CFTs a parameter instead of it being controlled by the selected livery.
* Added the ability to change the smoke generator's color and added a keybind to toggle it outside the ground services dialog
* Fixed the gun smoke's offset (was in the nose of the plane, and not actually where the gatling gun is)
* Modified the "reload gun" button in fuel and storage to make it also reload flares and chaffs
* Made the release flare/chaff keybind toggle release instead of just releasing once
* Display the amount of gun rounds and countermeasures in the fuel and payload dialog crap
* Added a gun outta-ammo sound effect
* Replaced the sound effects for the flare, so it's no longer a voice saying "flare", and reused the gun outta-ammo sound effect for the flare outta-ammo sound effect
* On the HUD, cross the selected armament if it's outta ammo
* Added the F-15E variant
* Modified the HUD to contain airpseed in kts and G force
* Added an AIM-120D missile only available for the F-15E (higher range and capabilities than the AIM-120, but can't be used in close range fight cuz of its 5nm minimal range)
* Updated the HUD to display a cannon crosshair
* Simulate all MPCD pages

So I've got in my small mind:

* Develop the F-15E variant (slightly different model cuz it'll have the targeting pod pylons)
* Make triple MK-84s model shit and implementation
* Add some more ground services cuz why not
* Add even more funky and cool liveries
* Make ejection possible
* Simulate the red warnings on the top right (below the red canopy alarm which is already simulated), so it turns on when flares or chaffs have no more ammo.
* Simulate engine fire (a red light warning on the top left only works for now, telling the temperature is too high), so that if one engine's temperature is too high for too long, a fire starts, and make so that the player can estulinguish the fire like in real life.
* Implement A/G mechanics

---
ORIGINAL TEXT
---

Realistic windtunnel based aerodynamic model of an F-15 (C,D) version. See http://zaretto.com/f-15

Models an F-15 with F-100 engines.

Low speed clean should be exactly as an F-15 

The aerodata used is from AFWAL-TR-80-3141, Part I and III. See http://zaretto.com/content/f-14-aerodynamic-data-sources

Richard Harrison rjh@zaretto.com
July 2015

Overview of the model

* F-15C and F-15D variants, including aerodynamic effects.
* Realistic FDM based on windtunnel derived aerodynamic data
* Photorealistic 3d Cockpit with real cockpit textures provided by GeneB from his unique F-15C 80-0007
* Operational weapons and radar
* Full range of sound simulation (buffet, gear, engines, etc..)
* Radar, HUD, VSD, TEWS, MPCD - using Canvas
* Refuelling, stores
* In cockpit engine start (including JFS Startup
* Hydraulics system model
* Electrics system model
* Afterburner flames (with luminosity variance depending on scene brightness)
* External and internal Rembrandt compatible lighting
* ECS pressurisation system model
* Control actuator system model
* Rembrandt ready.
* Tone and voice aural warnings 

V1.2E

Sounds; 

 - Calculation of volumes now in Nasal module, this allows the canopy to have a gradual effect
 - New sounds for GPU
 - Added pilot helment sound proofing to ground services dialog
 - Removed separate external / internal sounds because not needed with new internal volume level calculations
 - Fixed orientation, reference dist, angles and factors for engines, speed brake

Canopy opening now JSBSim model. Opening the canopy will result in loss of cabin pressure.

Added support for walker. This required remapping of certain keys.
   Autothrottle a becomes CTRL-s
   Cycle refuelling switch is now u
   Weapon mode (w) becomes (m)

Added sym switch to HUD, if in symbol reject mode then only show the active target.

Better engine smoke / wing tip contrails

FDM

 - adjusted static friction to better hold with full augmentation on dry surface

- Better wing root anti-collision lights
- Added Correct stall warning audio tones and vocal warnings for OWS, Caution and fuel.
- Canvas optimisations for low frame rates
- Fix weapon selection after load when master arm selected.
- Improved view positioning for front & backseat.
- Rework of lighting, fix halos, rembrandt light points; added lighting dialog to GUI.
- Reinstate comm radio support
- Overload Warning System (OWS) limits added
- Pitch/Roll ratio improvements, takes into account CG% MAC.
- Nose Wheel Steering (two modes; normal and maneuvering )

- New livery for 144FW 84-0014 (Missouri) and Lakenheath

- Added cold and dark to menu (to complement quickstart)

- Use of the refuelling switch on ground (opening the hatch) will make a refuelling tanker appear and cause fuel to be added.
