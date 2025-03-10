---
CROMHⒶ'S HERE
---

NOTE: **This repository is simply for myself so stay out, unless you're interested in my dookie F-15EX.**

This project aims to enhance the already-existing F-15C and D models originally made by Richard Harrison and other various contributors. But, the main aim is to develop the F-15EX model from that already-existing model, only changing the cockpit's model, being extremely different from the F-15C, but also add as much as weapons as the F-16 FlightGear model, develop A/G operations by adding more bombs types, racks and etc. The development of the MPCD (multi-page control display), the TWS radar display (for example use different symbols for unknown objects or missiles etc.), the HUD (adding modes and more useful info). The creation of a very detailed PDF manual is also under development.

For now, what's been done is:

- The creation of the EX variant (cockpit model is still old F-15C)
- The enhancement of the C variant cockpit (added simulation of chaff/flare release and low ammo lights, engine flame out oral warning + lights with a system)
- The implementation of A/G unguided operations (CCIP) and racks as well
- The addition of new A/A missiles: AIM-9M, AIM-9X (only EX variant), and the AIM-120D (only EX variant)
- The addition of new A/G bombs: MK-82, MK-83, MK-84, CBU-87, CBU-105 (only EX variant), and B61-12 (only EX variant)
- The addition of misc weapons: LAU-68C (only EX variant)
- The addition of more aerodynamic effects such as mach cone or strake and G vortex
- The polishing of already-existing effects
- The addition of new real-life and fictional liveries
- The complete overhaul of the in-game F-15 GUI by centralizing controls into the F-15 Eagle Configuration Panel, allow the control of fuel, conformal tanks, different parts' damage, ground services, smoke pods' color, pilot helmet sound proofing, selection of pre-made loads setup or customization of every hardpoint, custom load of gun rounds and flares/chaffs, and useful info on the current F-15 setup
- The polishing of various sound effects (gun, flares etc.)
- Enhanced the no-mode HUD to have clearer calibrated speed shown, as well as ground speed with it, current G load, and its max, AOA, clearer current altitude, using DCS's F-15E HUD design
- For the A/G mode, added the pipper if CCIP is online
- For general attack mode, display the currently selected weapon type
- Fixed liveries whose nose was bugged
- Tweaked some missiles' data to fit more realistic scenarios (or not)
- The addition of custom FlightGear AI scenarios for either strike, target interception or dogfight situations
- Added a dragchute
- Added more payload options, through custom rack count or new stores

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
