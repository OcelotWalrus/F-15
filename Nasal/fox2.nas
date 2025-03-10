#########################################################################################
#######
####### Guided/Cruise missiles, rockets and dumb/glide bombs code for Flightgear.
#######
####### License: GPL 2.0
#######
####### Authors:
#######  Alexis Bory, Fabien Barbier, Richard Harrison, Justin Nicholson, Nikolai V. Chr.
#######
####### The file vector.nas needs to be available in namespace 'vector'.
#######
####### In addition, some code is derived from work by:
#######  David Culp, Vivian Meazza, M. Franz
#######
#########################################################################################

# Some notes about making weapons:
#
# Firstly make sure you read the comments (line 190+) below for the properties.
# For laser/gps guided gravity bombs make sure to set the max G very low, like 0.5G, to simulate them slowly adjusting to hit the target.
# Remember for air to air missiles the speed quoted in literature is normally the speed above the launch platform. I usually fly at the typical max usage
#   regime for that missile, so for example for AIM-7M it would be at 40000 ft,
#   there I make sure it can reach approx the max relative speed. For older missiles the max speed quoted is sometimes absolute speed though, so beware.
#   If it quotes aerodynamic speed then its the absolute speed. Speeds quoted in in unofficial sources can be any of them,
#   but if its around mach 5 for A/A its a good bet its absolute, only very few A/A missiles are likely hypersonic. (probably due to heat or fuel limitations)
# If you cannot find fuel weight in literature, you probably wont go far off with a value that is 1/4 to 1/3 of total launch weight for a A/A missile.
# Stage durations is allowed to be 0, so can thrust values. If there is no second stage, instead of just setting stage 2 thrust to 0,
#   set stage 2 duration to 0 also. For unpowered munitions, set all thrusts to 0.
# For very low sea skimming missiles, be sure to set terrain following to false, you cannot have it both ways.
#   Since if it goes very low (below 100ft), it cannot navigate terrain reliable.
# The property terrain following only goes into effect, if a cruise altitude is set below 10000ft and not set to 0.
#   Cruise missiles against ground targets will always terrain follow, no matter that property.
# If literature quotes a max distance for a weapon, its a good bet it is under the condition that the target
#   is approaching the launch platform with high speed and does not evade, and also if the launch platform is an aircraft,
#   that it also is approaching the target with high speed. In other words, high closing rate. For example the AIM-7M, which can hit bombers out at 32 NM,
#   will often have to be within 3 NM of an escaping target to hit it (source). Missiles typically have significantly less range against an evading
#   or escaping target than what is commonly believed. I typically fly at 40000 ft at mach 2, approach a target flying head-on with same speed and altitude,
#   to test max range. Its typically drag that I adjust for that.
# When you test missiles against aircraft, be sure to do it with a framerate of 25+, else they will not hit very good, especially high speed missiles like
#   Amraam or Phoenix. Also notice they generally not hit so close against Scenario/AI objects compared to MP aircraft due to the way these are updated.
# Laser and semi-radar guided munitions need the target to be painted to keep lock. Notice gps guided munition that are all aspect will never lose lock,
#   whether they can 'see' the target or not.
# Remotely controlled guidance is not implemented, but the way it flies can be simulated by setting direct navigation with semi-radar or laser guidance.
#
#
# Usage:
#
# To create a weapon call AIM.new(pylon, type, description). The pylon is an integer from 0 or higher. When its launched it will read the pylon position in
#   controls/armament/station[pylon+1]/offsets, where the position properties must be x-m, y-m and z-m. The type is just a string, the description is a string
#   that is exposed in its radar properties under AI/models during flight.
# The model that is loaded and shown is located in the aircraft folder at the value of property payload/armament/models in a subfolder with same name as type.
#   Inside the subfolder the xml file is called [lowercase type]-[pylon].xml
# To start making the missile try to get a lock, set its status to MISSILE_SEARCH and call search(), the missile will then keep trying to get a lock on 'contact'.
#   'contact' can be set to nil at any time or changed. To stop the search, just set its status to MISSILE_STANDBY. To resume the search you again have to set
#   the status and call search().
# To release the munition at a target call release(), do this only after the missile has set its own status to MISSILE_LOCK.
# When using weapons without target, call releaseAtNothing() instead of release(), search() does not need to have been called beforehand.
#   To then find out where it hit the ground check the impact report in AI/models. The impact report will contain warhead weight, but that will be zero if
#   the weapon did not have time to arm before hitting ground.
# To drop the munition, without arming it nor igniting its engine, call eject().
#
#
# Limitations:
#
# The weapons use a simplified flight model that does not have AoA or sideslip. Mass balance, rotational inertia, wind is also not implemented. They also do not roll.
# If you fire a weapon and have HoT enabled in flightgear, they likely will not hit very precise.
# The weapons are highly dependent on framerate, so low frame rate will make them hit imprecise.
# APN does not take target sideslip and AoA into account when considering the targets acceleration. It assumes the target flies in the direction its pointed.
# The drag curves are tailored for sizable munitions, so it does not work well will bullet or cannon sized munition, submodels are better suited for that.
#
#
# Future features:
#
# Make ground hitting weapons hit all nearby targets, not just what its locked on.
# ECM disturbance of getting radar lock.
# Lock on jam. (advanced feature)
# After FG gets HLA: stop using MP chat for hit messages.
# Allow firing only if certain conditions are met. Like not being inverted when firing ejected weapons.
# Remote controlled guidance (advanced feature and probably not very practical in FG..yet)
# Ground launched rails/tubes that rotate towards target before firing.
# Sub munitions that have their own guidance/FDM. (advanced)
# GPS guided munitions could have waypoints added.
# Specify terminal manouvres and preferred impact aspect.
# Limit guiding if needed so that the missile don't lose sight of target?
# Consider to average the closing speed in proportional navigation. So get it between second last positions and current, instead of last to current.
# Drag coeff reduction due to exhaust plume.
# Proportional navigation should use vector math instead decomposition horizontal/vertical navigation.
# If closing speed is negative, consider to switch to pure pursuit from proportional navigation, the target might turn back into missile.
# Bleeding speed due to high G turning should depend on drag-area, with AIM-120s as reference. (that would mean recalibrate all cruise-missiles so they don't crash)
# Make semi-self-radar guided weapons that is semi guided until terminal phase where they switch on own radar. (AIM-120, AIM-54)
# Make anti-radiation guided feature. (HARM, SHRIKE)
# Max-g should be seperated into max structural G that it will never exceed, and max-g for certain mach. Should still depend also on altitude of course. This way it needs a certain speed to perform certain G.
# Real rocket thrust does not necesarily cutoff instantly. Make an optional fadeout. (use the aim-9 new variant paper page as guide)
# Support for seeker FOV that is smaller than FCS FOV. (ASRAAM)
#
# Please report bugs and features to Nikolai V. Chr. | ForumUser: Necolatis | Callsign: Leto

var AcModel        = props.globals.getNode("payload");
var OurHdg         = props.globals.getNode("orientation/heading-deg");
var OurRoll        = props.globals.getNode("orientation/roll-deg");
var OurPitch       = props.globals.getNode("orientation/pitch-deg");
var OurAlpha       = props.globals.getNode("orientation/alpha-deg");
var OurBeta        = props.globals.getNode("orientation/side-slip-deg");
var ourAlt         = props.globals.getNode("position/altitude-ft");
var deltaSec       = props.globals.getNode("sim/time/delta-sec");
var speedUp        = props.globals.getNode("sim/speed-up");
var noseAir        = props.globals.getNode("velocities/uBody-fps");
var belowAir       = props.globals.getNode("velocities/wBody-fps");
var HudReticleDev  = props.globals.getNode("payload/armament/hud/reticle-total-deviation", 1);#polar coords
var HudReticleDeg  = props.globals.getNode("payload/armament/hud/reticle-total-angle", 1);
var update_loop_time = 0.000;

var SIM_TIME = 0;
var REAL_TIME = 1;

var TRUE = 1;
var FALSE = 0;

var use_fg_default_hud = FALSE;

var MISSILE_STANDBY = -1;
var MISSILE_SEARCH = 0;
var MISSILE_LOCK = 1;
var MISSILE_FLYING = 2;

var AIR = 0;
var MARINE = 1;
var SURFACE = 2;
var ORDNANCE = 3;

var g_fps        = 9.80665 * M2FT;
var slugs_to_lbm = 32.1740485564;
var const_e      = 2.71828183;

var g_fps        = 9.80665 * M2FT;
var SLUGS2LBM = 32.1740485564;
var LBM2SLUGS = 1/SLUGS2LBM;
var slugs_to_lbm = SLUGS2LBM;# since various aircraft use this from outside missile, leaving it for backwards combat.

var first_in_air = FALSE;# first missile is in the air, other missiles should not write to MP.

var versionString = getprop("sim/version/flightgear");
var version = split(".", versionString);
var major = num(version[0]);
var minor = num(version[1]);
var pica  = num(version[2]);
var pickingMethod = FALSE;
if ((major == 2017 and minor == 2 and pica >= 1) or (major == 2017 and minor > 2) or major > 2017) {
	pickingMethod = TRUE;
}
var offsetMethod = FALSE;
if ((major == 2017 and minor == 2 and pica >= 1) or (major == 2017 and minor > 2) or major > 2017) {
	offsetMethod = TRUE;
}

#
# The radar will make sure to keep this variable updated.
# Whatever is targeted and ready to be fired upon, should be set here.
#
var contact = nil;
#
# Contact should implement the following interface:
#
# get_type()      - (AIR, MARINE, SURFACE or ORDNANCE)
# getUnique()     - Used when comparing 2 targets to each other and determining if they are the same target.
# isValid()       - If this target is valid
# getElevation()
# get_bearing()
# get_Callsign()
# get_range()
# get_Coord()
# get_Latitude()
# get_Longitude()
# get_altitude()
# get_Pitch()
# get_Speed()
# get_heading()
# getFlareNode()  - Used for flares.
# getChaffNode()  - Used for chaff.
# isPainted()     - Tells if this target is still being tracked by the launch platform, only used in semi-radar and laser guided missiles.

var AIM = {
	#done
	new : func (p, type = "AIM-9L", sign = "Sidewinder") {
		if(AIM.active[p] != nil) {
			#do not make new missile logic if one exist for this pylon.
			return -1;
		}
		var m = { parents : [AIM]};
		# Args: p = Pylon.

        if (type == "AIM-9L")
            m.type_lc = "aim-9";
        elsif (type == "AIM-9X")
            m.type_lc = "aim-9x";
        elsif (type == "AIM-9M")
            m.type_lc = "aim-9m";
        else if (type == "AIM-7M")
            m.type_lc = "aim-7";
        else if (type == "MK-82")
            m.type_lc = "mk-82";
        else if (type == "MK-83")
            m.type_lc = "mk-83";
        else if (type == "MK-84")
            m.type_lc = "mk-84";
        else if (type == "CBU-105")
            m.type_lc = "cbu-105";
        else if (type == "B61-12")
            m.type_lc = "b61-12";
        else if (type == "3 X CBU-87")
            m.type_lc = "cbu-87";
		else if (type == "2 X AIM-9X")
	        m.type_lc = "aim-9x";
        else if (type == "3 X MK-83")
            m.type_lc = "mk-83";
        else if (type == "LAU-68C")
            m.type_lc = "lau-68";
        else if (type == "AIM-120C")
            m.type_lc = "aim-120c";
        else if (type == "AIM-120D")
            m.type_lc = "aim-120d";
		m.type = type;

		m.deleted = FALSE;

		m.status            = MISSILE_STANDBY; # -1 = stand-by, 0 = searching, 1 = locked, 2 = fired.
		m.free              = 0; # 0 = status fired with lock, 1 = status fired but having lost lock.
		m.trackWeak         = 1;
		m.prop              = AcModel.getNode("armament/"~m.type_lc~"/");#.getChild("msl", 0, 1);
		m.SwSoundOnOff      = AcModel.getNode("armament/"~m.type_lc~"/sound-on-off",1);
		m.SwSoundFireOnOff  = AcModel.getNode("armament/"~m.type_lc~"/sound-fire-on-off",1);
        m.SwSoundVol        = AcModel.getNode("armament/"~m.type_lc~"/sound-volume",1);
        if (m.SwSoundOnOff.getValue() == nil) {
        	m.SwSoundOnOff.setBoolValue(0);
        }
        if (m.SwSoundFireOnOff.getValue() == nil) {
        	m.SwSoundFireOnOff.setBoolValue(0);
        }
        if (m.SwSoundVol.getValue() == nil) {
        	m.SwSoundVol.setDoubleValue(0);
        }
        m.useHitInterpolation   = getprop("payload/armament/hit-interpolation");#false to use 5H1N0B1 trigonometry, true to use Leto interpolation.
		m.PylonIndex        = m.prop.getNode("pylon-index", 1).setValue(p);
		m.ID                = p;
		m.stationName       = AcModel.getNode("armament/station-name").getValue();
		m.pylon_prop        = props.globals.getNode(AcModel.getNode("armament/pylon-stations").getValue()).getChild(m.stationName, p+AcModel.getNode("armament/pylon-offset").getValue());
		m.Tgt               = nil;
		m.callsign          = "Unknown";
		m.update_track_time = 0;
		m.direct_dist_m     = nil;
		m.speed_m           = 0;

		m.nodeString = "payload/armament/"~m.type_lc~"/";

		###############
		# Weapon specs:
		###############

		# detection and firing
		m.max_fire_range_nm     = getprop(m.nodeString~"max-fire-range-nm");          # max range that the FCS allows firing
		m.min_fire_range_nm     = getprop(m.nodeString~"min-fire-range-nm");          # it wont get solid lock before the target has this range
		m.fcs_fov               = getprop(m.nodeString~"FCS-field-deg") / 2;          # fire control system total field of view diameter for when searching and getting lock before launch.
		m.class                 = getprop(m.nodeString~"class");                      # put in letters here that represent the types the missile can fire at. A=air, M=marine, G=ground
        m.brevity               = getprop(m.nodeString~"fire-msg");                   # what the pilot will call out over the comm when he fires this weapon
		# navigation, guiding and seekerhead
		m.max_seeker_dev        = getprop(m.nodeString~"seeker-field-deg") / 2;       # missiles own seekers total FOV diameter.
		m.guidance              = getprop(m.nodeString~"guidance");                   # heat/radar/semi-radar/laser/gps/vision/unguided
		m.navigation            = getprop(m.nodeString~"navigation");                 # direct/PN/APN/PNxx/APNxx (use direct for gravity bombs, use PN for very old missiles, use APN for modern missiles, use PNxx/APNxx for surface to air where xx is degrees to aim above target)
		m.pro_constant          = getprop(m.nodeString~"proportionality-constant");   # Constant for how sensitive proportional navigation is to target speed/acc. Normally between 3-6. [optional]
		m.all_aspect            = getprop(m.nodeString~"all-aspect");                 # set to false if missile only locks on reliably to rear of target aircraft
		m.angular_speed         = getprop(m.nodeString~"seeker-angular-speed-dps");   # only for heat/vision seeking missiles. Max angular speed that the target can move as seen from seeker, before seeker loses lock.
		m.sun_lock              = getprop(m.nodeString~"lock-on-sun-deg");            # only for heat seeking missiles. If it looks at sun within this angle, it will lose lock on target.
		m.loft_alt              = getprop(m.nodeString~"loft-altitude");              # if 0 then no snap up. Below 10000 then cruise altitude above ground. Above 10000 max altitude it will snap up to.
        m.follow                = getprop(m.nodeString~"terrain-follow");             # used for anti-ship missiles that should be able to terrain follow instead of purely sea skimming.
		# engine
		m.force_lbf_1           = getprop(m.nodeString~"thrust-lbf-stage-1");         # stage 1 thrust
		m.force_lbf_2           = getprop(m.nodeString~"thrust-lbf-stage-2");         # stage 2 thrust [optional]
		m.stage_1_duration      = getprop(m.nodeString~"stage-1-duration-sec");       # stage 1 duration
		m.stage_2_duration      = getprop(m.nodeString~"stage-2-duration-sec");       # stage 2 duration [optional]
		m.weight_fuel_lbm       = getprop(m.nodeString~"weight-fuel-lbm");            # fuel weight [optional]. If this property is not present, it won't lose weight as the fuel is used.
		m.vector_thrust         = getprop(m.nodeString~"vector-thrust");              # Boolean. [optional]
		# aerodynamic
		m.weight_launch_lbm     = getprop(m.nodeString~"weight-launch-lbs");          # total weight of armament, including fuel and warhead.
		m.Cd_base               = getprop(m.nodeString~"drag-coeff");                 # drag coefficient
		m.ref_area_sqft         = getprop(m.nodeString~"cross-section-sqft");         # normally is crosssection area of munition (without fins)
		m.max_g                 = getprop(m.nodeString~"max-g");                      # max G-force the missile can pull at sealevel
		m.min_speed_for_guiding = getprop(m.nodeString~"min-speed-for-guiding-mach"); # minimum speed before the missile steers, before it reaches this speed it will fly ballistic.
		# detonation
		m.weight_whead_lbm      = getprop(m.nodeString~"weight-warhead-lbs");         # warhead weight
		m.arming_time           = getprop(m.nodeString~"arming-time-sec");            # time for weapon to arm
		m.selfdestruct_time     = getprop(m.nodeString~"self-destruct-time-sec");     # time before selfdestruct
		m.destruct_when_free    = getprop(m.nodeString~"self-destruct-at-lock-lost"); # selfdestruct if lose target
		m.reportDist            = getprop(m.nodeString~"max-report-distance");        # Interpolation hit: max distance from target it report it exploded, not passed. Trig hit: Distance where it will trigger.
		# avionics sounds
		m.vol_search            = getprop(m.nodeString~"vol-search");                 # sound volume when searcing
		m.vol_track             = getprop(m.nodeString~"vol-track");                  # sound volume when having lock
		m.vol_track_weak        = getprop(m.nodeString~"vol-track-weak");             # sound volume before getting solid lock
		# launching conditions
        m.rail                  = getprop(m.nodeString~"rail");                       # if the weapon is rail or tube fired set to true. If dropped 7ft before ignited set to false.
        m.rail_dist_m           = getprop(m.nodeString~"rail-length-m");              # length of tube/rail
        m.rail_forward          = getprop(m.nodeString~"rail-point-forward");         # true for rail, false for rail/tube with a pitch
        m.rail_pitch_deg        = getprop(m.nodeString~"rail-pitch-deg");             # Only used when rail is not forward. 90 for vertical tube.
        # counter-measures
        m.chaffResistance       = getprop(m.nodeString~"chaff-resistance");           # Float 0-1. Amount of resistance to chaff. Default 0.950. [optional]
        m.flareResistance       = getprop(m.nodeString~"flare-resistance");           # Float 0-1. Amount of resistance to flare. Default 0.950. [optional]
        # data-link to launch platform
        m.data                  = getprop(m.nodeString~"telemetry");                  # Boolean. Data link back to aircraft when missile is flying. [optional]
        m.dlz_enabled           = getprop(m.nodeString~"DLZ");                        # Supports dynamic launch zone info. For now only works with A/A. [optional]
        m.dlz_opt_alt           = getprop(m.nodeString~"DLZ-optimal-alt-feet");       # Minimum altitude required to hit the target at max range.
        m.dlz_opt_mach          = getprop(m.nodeString~"DLZ-optimal-closing-mach");   # Closing speed required to hit the target at max range at minimum altitude.


        # three variables used for trigonometry hit calc:
		m.vApproch       = 1;
        m.tpsApproch     = 0;
        m.usedChance     = FALSE;

        if (m.weight_fuel_lbm == nil) {
			m.weight_fuel_lbm = 0;
		}
		if (m.data == nil) {
        	m.data = FALSE;
        }
        if (m.vector_thrust == nil) {
        	m.vector_thrust = FALSE;
        }
        if (m.flareResistance == nil) {
        	m.flareResistance = 0.95;
        }
        if (m.chaffResistance == nil) {
        	m.chaffResistance = 0.95;
        }
        if (m.navigation == nil) {
			m.navigation = "APN";
		}
        if (m.pro_constant == nil) {
        	if (find("APN", m.navigation)!=-1) {
        		m.pro_constant = 3;
        	} else {
	        	m.pro_constant = 3;
	        }
        }
        if (m.force_lbf_1 == nil or m.force_lbf_1 == 0) {
        	m.force_lbf_1 = 0;
        	m.stage_1_duration = 0;
        }
        if (m.force_lbf_2 == nil or m.force_lbf_2 == 0) {
        	m.force_lbf_2 = 0;
        	m.stage_2_duration = 0;
        }
		if (m.destruct_when_free == nil) {
			m.destruct_when_free = FALSE;
		}

        m.useModelCase          = getprop("payload/armament/modelsUseCase");
        m.useModelUpperCase     = getprop("payload/armament/modelsUpperCase");
        m.weapon_model_type     = type;
        if (m.useModelCase == TRUE) {
        	if (m.useModelUpperCase == TRUE) {
        		m.weapon_model_type     = string.uc(type);
    		} else {
    			m.weapon_model_type     = m.type_lc;
    		}
        }
		m.weapon_model          = getprop("payload/armament/models")~m.weapon_model_type~"/"~m.type_lc~"-";

		m.mpLat          = getprop("payload/armament/MP-lat");# properties to be used for showing missile over MP.
		m.mpLon          = getprop("payload/armament/MP-lon");
		m.mpAlt          = getprop("payload/armament/MP-alt");
		m.mpShow = FALSE;
		if (m.mpLat != nil and m.mpLon != nil and m.mpAlt != nil) {
			m.mpLat          = props.globals.getNode(m.mpLat, FALSE);
			m.mpLon          = props.globals.getNode(m.mpLon, FALSE);
			m.mpAlt          = props.globals.getNode(m.mpAlt, FALSE);
			if (m.mpLat != nil and m.mpLon != nil and m.mpAlt != nil) {
				m.mpShow = TRUE;
			}
		}

		m.elapsed_last          = 0;

		m.target_air = find("A", m.class)==-1?FALSE:TRUE;
		m.target_sea = find("M", m.class)==-1?FALSE:TRUE;#use M for marine, since S can be confused with surface.
		m.target_gnd = find("G", m.class)==-1?FALSE:TRUE;

		# Find the next index for "models/model" and create property node.
		# Find the next index for "ai/models/aim-9" and create property node.
		# (M. Franz, see Nasal/tanker.nas)
		var n = props.globals.getNode("models", 1);
		var i = 0;
		for (i = 0; 1==1; i += 1) {
			if (n.getChild("model", i, 0) == nil) {
				break;
			}
		}
		m.model = n.getChild("model", i, 1);

		n = props.globals.getNode("ai/models", 1);
		for (i = 0; 1==1; i += 1) {
			if (n.getChild(m.type_lc, i, 0) == nil) {
				break;
			}
		}
		m.ai = n.getChild(m.type_lc, i, 1);
		if(m.data == TRUE) {
			m.ai.getNode("ETA", 1).setIntValue(-1);
			m.ai.getNode("hit", 1).setIntValue(-1);
		}
		m.ai.getNode("valid", 1).setBoolValue(0);
		m.ai.getNode("name", 1).setValue(type);
		m.ai.getNode("sign", 1).setValue(sign);
		m.ai.getNode("callsign", 1).setValue(type);
		m.ai.getNode("missile", 1).setBoolValue(1);
		#m.model.getNode("collision", 1).setBoolValue(0);
		#m.model.getNode("impact", 1).setBoolValue(0);
		var id_model = m.weapon_model ~ m.ID ~ ".xml";
		m.model.getNode("path", 1).setValue(id_model);
		m.life_time = 0;

		# Create the AI position and orientation properties.
		m.latN   = m.ai.getNode("position/latitude-deg", 1);
		m.lonN   = m.ai.getNode("position/longitude-deg", 1);
		m.altN   = m.ai.getNode("position/altitude-ft", 1);
		m.hdgN   = m.ai.getNode("orientation/true-heading-deg", 1);
		m.pitchN = m.ai.getNode("orientation/pitch-deg", 1);
		m.rollN  = m.ai.getNode("orientation/roll-deg", 1);

		m.ac      = nil;

		m.coord               = geo.Coord.new().set_latlon(0, 0, 0);
		m.last_coord          = nil;
		m.before_last_coord   = nil;
		m.t_coord             = nil;
		m.last_t_coord        = m.t_coord;
		m.before_last_t_coord = nil;

		m.speed_down_fps  = nil;
		m.speed_east_fps  = nil;
		m.speed_north_fps = nil;
		m.alt_ft          = nil;
		m.pitch           = nil;
		m.hdg             = nil;

		# Nikolai V. Chr.
		# The more variables here instead of declared locally, the better for performance.
		# Due to garbage collector.
		#


		m.density_alt_diff   = 0;
		m.max_g_current      = m.max_g;
		m.old_speed_horz_fps = nil;
		m.paused             = 0;
		m.old_speed_fps	     = 0;
		m.dt                 = 0;
		m.g                  = 0;
		m.limitGs            = FALSE;

		# navigation and guidance
		m.last_deviation_e       = nil;
		m.last_deviation_h       = nil;
		m.last_track_e           = 0;
		m.last_track_h           = 0;
		m.guiding                = TRUE;
		m.t_alt                  = 0;
		m.dist_curr              = 0;
		m.dist_curr_direct       = 0;
		m.t_elev_deg             = 0;
		m.t_course               = 0;
		m.t_heading              = nil;
		m.t_pitch                = nil;
		m.t_speed_fps            = nil;
		m.dist_last              = nil;
		m.dist_direct_last       = nil;
		m.last_t_course          = nil;
		m.last_t_elev_deg        = nil;
		m.last_cruise_or_loft    = FALSE;
		m.last_t_norm_speed      = nil;
		m.last_t_elev_norm_speed = nil;
		m.last_dt                = 0;
		m.dive_token             = FALSE;
		m.raw_steer_signal_elev  = 0;
		m.raw_steer_signal_head  = 0;
		m.cruise_or_loft         = FALSE;
		m.curr_deviation_e       = 0;
		m.curr_deviation_h       = 0;
		m.track_signal_e         = 0;
		m.track_signal_h         = 0;

		# cruise-missiles
		m.nextGroundElevation = 0; # next Ground Elevation
		m.nextGroundElevationMem = [-10000, -1];

		#rail
		m.drop_time = 0;
		m.rail_passed = FALSE;
		m.x = 0;
		m.y = 0;
		m.z = 0;
		m.rail_pos = 0;
		m.rail_speed_into_wind = 0;

		# stats
		m.maxFPS       = 0;
		m.maxMach      = 0;
		m.maxMach1     = 0;#stage 1
		m.maxMach2     = 0;#stage 2
		m.maxMach3     = 0;#stage 2 end
		m.energyBleedKt = 0;

		m.flareLast = 0;
		m.flareTime = 0;
		m.flareLock = FALSE;
		m.chaffLast = 0;
		m.chaffTime = 0;
		m.chaffLock = FALSE;
		m.flarespeed_fps = nil;

		m.explodeSound = TRUE;
		m.first = FALSE;

		# these 4 is used for limiting spam to console:
		m.heatLostLock = FALSE;
		m.semiLostLock = FALSE;
		m.tooLowSpeed  = FALSE;
		m.lostLOS      = FALSE;

		m.SwSoundOnOff.setBoolValue(FALSE);
		#m.SwSoundFireOnOff.setBoolValue(FALSE);
		m.SwSoundVol.setDoubleValue(m.vol_search);
		#me.trackWeak = 1;

		m.horz_closing_rate_fps = -1;

		return AIM.active[m.ID] = m;
	},

	del: func {#GCD (garbage collection optimization done)
		#print("deleted");
		if (me.first == TRUE) {
			me.resetFirst();
		}
		me.model.remove();
		me.ai.remove();
		if (me.status == MISSILE_FLYING) {
			delete(AIM.flying, me.flyID);
		} else {
			delete(AIM.active, me.ID);
		}
		me.SwSoundVol.setDoubleValue(0);
		me.deleted = TRUE;
	},

	getDLZ: func {#GCD (garbage collection optimization done)
		if (me.dlz_enabled != TRUE) {
			return nil;
		} elsif (contact == nil or me.status != MISSILE_LOCK) {
			return [];
		}
		me.dlz_t_alt = contact.get_altitude();
		me.dlz_o_alt = ourAlt.getValue();
		me.dlz_t_rs = me.rho_sndspeed(me.dlz_t_alt);
		me.dlz_t_rho = me.dlz_t_rs[0];
		me.dlz_t_sound_fps = me.dlz_t_rs[1];
		me.dlz_tG    = me.maxG(me.dlz_t_rho, me.max_g);
		me.dlz_t_mach = contact.get_Speed()*KT2FPS/me.dlz_t_sound_fps;
		me.dlz_o_mach = getprop("velocities/mach");
		me.contactCoord = contact.get_Coord();
		me.vectorToEcho   = vector.Math.eulerToCartesian2(contact.get_bearing(), vector.Math.getPitch(geo.aircraft_position(), me.contactCoord));
    	me.vectorEchoNose = vector.Math.eulerToCartesian3X(contact.get_heading(), contact.get_Pitch(), contact.get_Roll());
    	me.angleToRear    = geo.normdeg180(vector.Math.angleBetweenVectors(me.vectorToEcho, me.vectorEchoNose));
    	me.abso           = math.abs(me.angleToRear)-90;
    	me.mach_factor    = math.sin(me.abso*D2R);

    	me.dlz_CS         = me.mach_factor*me.dlz_t_mach+me.dlz_o_mach;

    	me.dlz_opt   = me.clamp(me.max_fire_range_nm *0.3* (me.dlz_o_alt/me.dlz_opt_alt) + me.max_fire_range_nm *0.2* (me.dlz_t_alt/me.dlz_opt_alt) + me.max_fire_range_nm *0.5* (me.dlz_CS/me.dlz_opt_mach),me.min_fire_range_nm,me.max_fire_range_nm);
    	me.dlz_nez   = me.clamp(me.dlz_opt * (me.dlz_tG/45), me.min_fire_range_nm, me.dlz_opt);
    	#printf("Dynamic Launch Zone (NM): Maximum=%0.1f Optimistic=%0.1f NEZ=%0.1f Minimum=%0.1f",me.max_fire_range_nm,me.dlz_opt,me.dlz_nez,me.min_fire_range_nm);
    	return [me.max_fire_range_nm,me.dlz_opt,me.dlz_nez,me.min_fire_range_nm,geo.aircraft_position().direct_distance_to(me.contactCoord)*M2NM];
	},

	getGPS: func(x, y, z, pitch) {#GCD
		#
		# get Coord from body position. x,y,z must be in meters.
		# derived from Vivian's code in AIModel/submodel.cxx.
		#
		me.ac = geo.aircraft_position();

		if(x == 0 and y==0 and z==0) {
			return geo.Coord.new(me.ac);
		}

		me.ac_roll = OurRoll.getValue();
		me.ac_pitch = pitch;
		me.ac_hdg   = OurHdg.getValue();

		me.in    = [0,0,0];
		me.trans = [[0,0,0],[0,0,0],[0,0,0]];
		me.out   = [0,0,0];

		me.in[0] =  -x * M2FT;
		me.in[1] =   y * M2FT;
		me.in[2] =   z * M2FT;
		# Pre-process trig functions:
		me.cosRx = math.cos(-me.ac_roll * D2R);
		me.sinRx = math.sin(-me.ac_roll * D2R);
		me.cosRy = math.cos(-me.ac_pitch * D2R);
		me.sinRy = math.sin(-me.ac_pitch * D2R);
		me.cosRz = math.cos(me.ac_hdg * D2R);
		me.sinRz = math.sin(me.ac_hdg * D2R);
		# Set up the transform matrix:
		me.trans[0][0] =  me.cosRy * me.cosRz;
		me.trans[0][1] =  -1 * me.cosRx * me.sinRz + me.sinRx * me.sinRy * me.cosRz ;
		me.trans[0][2] =  me.sinRx * me.sinRz + me.cosRx * me.sinRy * me.cosRz;
		me.trans[1][0] =  me.cosRy * me.sinRz;
		me.trans[1][1] =  me.cosRx * me.cosRz + me.sinRx * me.sinRy * me.sinRz;
		me.trans[1][2] =  -1 * me.sinRx * me.cosRx + me.cosRx * me.sinRy * me.sinRz;
		me.trans[2][0] =  -1 * me.sinRy;
		me.trans[2][1] =  me.sinRx * me.cosRy;
		me.trans[2][2] =  me.cosRx * me.cosRy;
		# Multiply the input and transform matrices:
		me.out[0] = me.in[0] * me.trans[0][0] + me.in[1] * me.trans[0][1] + me.in[2] * me.trans[0][2];
		me.out[1] = me.in[0] * me.trans[1][0] + me.in[1] * me.trans[1][1] + me.in[2] * me.trans[1][2];
		me.out[2] = me.in[0] * me.trans[2][0] + me.in[1] * me.trans[2][1] + me.in[2] * me.trans[2][2];
		# Convert ft to degrees of latitude:
		me.out[0] = me.out[0] / (366468.96 - 3717.12 * math.cos(me.ac.lat() * D2R));
		# Convert ft to degrees of longitude:
		me.out[1] = me.out[1] / (365228.16 * math.cos(me.ac.lat() * D2R));
		# Set submodel initial position:
		me.mlat = me.ac.lat() + me.out[0];
		me.mlon = me.ac.lon() + me.out[1];
		me.malt = (me.ac.alt() * M2FT) + me.out[2];

		me.c = geo.Coord.new();
		me.c.set_latlon(me.mlat, me.mlon, me.malt * FT2M);

		return me.c;
	},

	eject: func () {#GCD
		me.stage_1_duration = 0;
		me.force_lbf_1      = 0;
		me.stage_2_duration = 0;
		me.force_lbf_2      = 0;
		me.arming_time      = 5000;
		me.rail             = FALSE;
		me.releaseAtNothing();
	},

	releaseAtNothing: func() {#GCD
		me.Tgt = nil;
		me.release();
	},

	release: func() {#GCn
		# Release missile/bomb from its pylon/rail/tube and send it away.
		#
		if(me.arming_time == 5000) {
			me.SwSoundFireOnOff.setBoolValue(FALSE);
		} else {
			me.SwSoundFireOnOff.setBoolValue(TRUE);
		}
		me.status = MISSILE_FLYING;
		me.flyID = rand();
		AIM.flying[me.flyID] = me;
		delete(AIM.active, me.ID);
		me.animation_flags_props();

		# Get the A/C position and orientation values.
		me.ac = geo.aircraft_position();
		me.ac_init = geo.Coord.new(me.ac);
		var ac_roll = OurRoll.getValue();# positive is banking right
		var ac_pitch = OurPitch.getValue();
		var ac_hdg   = OurHdg.getValue();

		if (me.rail == TRUE) {
			if (me.rail_forward == FALSE) {
				ac_pitch = ac_pitch + me.rail_pitch_deg;
			}
		}

		# Compute missile initial position relative to A/C center
		me.x = me.pylon_prop.getNode("offsets/x-m").getValue();
		me.y = me.pylon_prop.getNode("offsets/y-m").getValue();
		me.z = me.pylon_prop.getNode("offsets/z-m").getValue();
		var init_coord = nil;
		if (offsetMethod == TRUE) {
			var pos = aircraftToCart({x:-me.x, y:me.y, z: -me.z});
			init_coord = geo.Coord.new();
			init_coord.set_xyz(pos.x, pos.y, pos.z);
		} else {
			init_coord = me.getGPS(me.x, me.y, me.z, ac_pitch);
		}


		# Set submodel initial position:
		var mlat = init_coord.lat();
		var mlon = init_coord.lon();
		var malt = init_coord.alt() * M2FT;
		me.latN.setDoubleValue(mlat);
		me.lonN.setDoubleValue(mlon);
		me.altN.setDoubleValue(malt);
		me.hdgN.setDoubleValue(ac_hdg);

		if (me.rail == FALSE) {
			# drop distance in time
			me.drop_time = math.sqrt(2*7/g_fps);# time to fall 7 ft to clear aircraft
		}

		me.pitchN.setDoubleValue(ac_pitch);
		me.rollN.setDoubleValue(0);

		me.coord = geo.Coord.new(init_coord);
		# Get target position.
		if (me.Tgt != nil) {
			me.t_coord = me.Tgt.get_Coord();
		}

		me.model.getNode("latitude-deg-prop", 1).setValue(me.latN.getPath());
		me.model.getNode("longitude-deg-prop", 1).setValue(me.lonN.getPath());
		me.model.getNode("elevation-ft-prop", 1).setValue(me.altN.getPath());
		me.model.getNode("heading-deg-prop", 1).setValue(me.hdgN.getPath());
		me.model.getNode("pitch-deg-prop", 1).setValue(me.pitchN.getPath());
		me.model.getNode("roll-deg-prop", 1).setValue(me.rollN.getPath());
		var loadNode = me.model.getNode("load", 1);
		loadNode.setBoolValue(1);

		# Get initial velocity vector (aircraft):
		me.speed_down_fps = getprop("velocities/speed-down-fps");
		me.speed_east_fps = getprop("velocities/speed-east-fps");
		me.speed_north_fps = getprop("velocities/speed-north-fps");
		if (me.rail == TRUE) {
			if (me.rail_forward == FALSE) {
				if (me.rail_pitch_deg == 90) {
					# rail is actually a tube pointing upward
					me.rail_speed_into_wind = -getprop("velocities/wBody-fps");# wind from below
				} else {
					#does not account for incoming airstream, yet.
					me.rail_speed_into_wind = 0;
				}
			} else {
				# rail is pointing forward
				me.rail_speed_into_wind = getprop("velocities/uBody-fps");# wind from nose
			}
		}

		me.alt_ft = malt;
		me.pitch = ac_pitch;
		me.hdg = ac_hdg;

		if (getprop("sim/flight-model") == "jsb") {
			# currently not supported in Yasim
			me.density_alt_diff = getprop("fdm/jsbsim/atmosphere/density-altitude") - me.ac.alt()*M2FT;
		}

		# setup lofting and cruising
		me.snapUp = me.loft_alt > 10000;
		me.rotate_token = FALSE;
		#if (me.Tgt != nil and me.snapUp == TRUE) {
			#var dst = me.coord.distance_to(me.Tgt.get_Coord()) * M2NM;
			#
			#f(x) = y1 + ((x - x1) / (x2 - x1)) * (y2 - y1)
#				me.loft_alt = me.loft_alt - ((me.max_fire_range_nm - 10) - (dst - 10))*500; original code
#				me.loft_alt = 0+((dst-38)/(me.max_fire_range_nm-38))*(me.loft_alt-36000);   originally for phoenix missile
#			me.loft_alt = 0+((dst-10)/(me.max_fire_range_nm-10))*(me.loft_alt-0);           also doesn't really work
#			me.loft_alt = me.clamp(me.loft_alt, 0, 200000);
			#printf("Loft to max %5d ft.", me.loft_alt);
		#}


		me.SwSoundVol.setDoubleValue(0);
		me.trackWeak = 1;
		#settimer(func { HudReticleDeg.setValue(0) }, 2);
		#interpolate(HudReticleDev, 0, 2);

		me.startMach = getprop("velocities/mach");
		me.startFPS = getprop("velocities/groundspeed-kt")*KT2FPS;
		me.startAlt  = getprop("position/altitude-ft");
		me.startDist = 0;
		me.maxAlt = me.startAlt;
		if (me.Tgt != nil) {
			me.startDist = me.ac_init.direct_distance_to(me.Tgt.get_Coord());
		}
		printf("Launch %s at %s.", me.type, me.callsign);

		me.weight_current = me.weight_launch_lbm;
		me.mass = me.weight_launch_lbm / slugs_to_lbm;

		# find the fuel consumption - lbm/sec
		var impulse1 = me.force_lbf_1 * me.stage_1_duration; # lbf*s
		var impulse2 = me.force_lbf_2 * me.stage_2_duration; # lbf*s
		var impulseT = impulse1 + impulse2;                  # lbf*s
		var fuel_per_impulse = me.weight_fuel_lbm / impulseT;# lbm/(lbf*s)
		me.fuel_per_sec_1  = (fuel_per_impulse * impulse1) / me.stage_1_duration;# lbm/s
		me.fuel_per_sec_2  = (fuel_per_impulse * impulse2) / me.stage_2_duration;# lbm/s

		# uncomment this line to see how much energy/fuel the missile have. For solid fuel rockets, it is normally 200-280. Lower for smokeless, higher for smoke.
		#printf("Specific Impulse: %s has %0.2f (lbf*s)/lbm. Total impulse: %.2f lbf*s.", me.type, 1/fuel_per_impulse, impulseT);

		# find the sun:
		if(me.guidance == "heat") {
			var sun_x = getprop("ephemeris/sun/local/x");
			var sun_y = getprop("ephemeris/sun/local/y");# unit vector pointing to sun in geocentric coords
			var sun_z = getprop("ephemeris/sun/local/z");
			if (sun_x != nil) {
				me.sun_enabled = TRUE;
				me.sun = geo.Coord.new();
				me.sun.set_xyz(me.ac_init.x()+sun_x*200000, me.ac_init.y()+sun_y*200000, me.ac_init.z()+sun_z*200000);#heat seeking missiles don't fly far, so setting it 200Km away is fine.
			} else {
				# old FG versions does not supply location of sun. So this feature gets disabled.
				me.sun_enabled = FALSE;
			}
		}
		me.lock_on_sun = FALSE;

		me.flight();
		loadNode.remove();
		me.ai.getNode("valid").setBoolValue(1);
	},

	drag: func (mach) {#GCD
		# Nikolai V. Chr.: Made the drag calc more in line with big missiles as opposed to small bullets.
		#
		# The old equations were based on curves for a conventional shell/bullet (no boat-tail),
		# and derived from Davic Culps code in AIBallistic.
		me.Cd = 0;
		if (mach < 0.7) {
			me.Cd = (0.0125 * mach + 0.20) * 5 * me.Cd_base;
		} elsif (mach < 1.2 ) {
			me.Cd = (0.3742 * math.pow(mach, 2) - 0.252 * mach + 0.0021 + 0.2 ) * 5 * me.Cd_base;
		} else {
			me.Cd = (0.2965 * math.pow(mach, -1.1506) + 0.2) * 5 * me.Cd_base;
		}

		return me.Cd;
	},

	maxG: func (rho, max_g_sealevel) {#GCD
		# Nikolai V. Chr.: A function to determine max G-force depending on air density.
		#
		# density for 0ft and 50kft:
		#print("0:"~rho_sndspeed(0)[0]);       = 0.0023769
		#print("50k:"~rho_sndspeed(50000)[0]); = 0.00036159
		#
		# Fact: An aim-9j can do 22G at sealevel, 13G at 50Kft
		# 13G = 22G * 0.5909
		#
		# extra/inter-polation:
		# f(x) = y1 + ((x - x1) / (x2 - x1)) * (y2 - y1)
		# calculate its performance at current air density:
		return me.clamp(max_g_sealevel+((rho-0.0023769)/(0.00036159-0.0023769))*(max_g_sealevel*0.5909-max_g_sealevel),0.25,100);
	},

	extrapolate: func (x, x1, x2, y1, y2) {
    	return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
	},

	thrust: func () {#GCD
		# Determine the thrust at this moment.
		#
		# If dropped, then ignited after fall time of what is the equivalent of 7ft.
		# If the rocket is 2 stage, then ignite the second stage when 1st has burned out.
		#
		me.thrust_lbf = 0;# pounds force (lbf)
		if (me.life_time > (me.drop_time + me.stage_1_duration + me.stage_2_duration)) {
			me.thrust_lbf = 0;
		} elsif (me.life_time > me.stage_1_duration + me.drop_time) {
			me.thrust_lbf = me.force_lbf_2;
		} elsif (me.life_time > me.drop_time) {
			me.thrust_lbf = me.force_lbf_1;
		}

		#me.force_cutoff_s = 0;# seen charts of real (aim9m) that thrust dont stop instantly, but fades out. This term would say hwo long it takes to fade out. Need to rework fuel consumption first. Maybe in future.
		#if (me.life_time > (me.drop_time + me.stage_1_duration + me.stage_2_duration-me.force_cutoff_s) and me.life_time < (me.drop_time + me.stage_1_duration + me.stage_2_duration)) {
		#	me.thrust_lbf = me.extrapolate(me.life_time - (me.drop_time + me.stage_1_duration + me.stage_2_duration - me.force_cutoff_s),0,me.force_cutoff_s,me.thrust_lbf,0);
		#}

		if (me.thrust_lbf < 1) {
			me.smoke_prop.setBoolValue(0);
		} else {
			me.smoke_prop.setBoolValue(1);
		}
		return me.thrust_lbf;
	},

	speedChange: func (thrust_lbf, rho, Cd) {#GCD
		# Calculate speed change from last update.
		#
		# Acceleration = thrust/mass - drag/mass;

		me.acc = thrust_lbf / me.mass;
		me.q = 0.5 * rho * me.old_speed_fps * me.old_speed_fps;# dynamic pressure
		me.drag_acc = (me.Cd * me.q * me.ref_area_sqft) / me.mass;

		# get total new speed change (minus gravity)
		return me.acc*me.dt - me.drag_acc*me.dt;
	},

    energyBleed: func (gForce, altitude) {#GCD
        # Bleed of energy from pulling Gs.
        # This is very inaccurate, but better than nothing.
        #
        # First we get the speedloss due to normal drag:
        me.b300 = me.bleed32800at0g();
        me.b000 = me.bleed0at0g();
        #
        # We then subtract the normal drag from the loss due to G and normal drag.
        me.b325 = me.bleed32800at25g()-me.b300;
        me.b025 = me.bleed0at25g()-me.b000;
        me.b300 = 0;
        me.b000 = 0;
        #
        # We now find what the speedloss will be at sealevel and 32800 ft.
        me.speedLoss32800 = me.b300 + ((gForce-0)/(25-0))*(me.b325 - me.b300);
        me.speedLoss0 = me.b000 + ((gForce-0)/(25-0))*(me.b025 - me.b000);
        #
        # We then inter/extra-polate that to the currect density-altitude.
        me.speedLoss = me.speedLoss0 + ((altitude-0)/(32800-0))*(me.speedLoss32800-me.speedLoss0);
        #
        # For good measure the result is clamped to below zero.
        me.speedLoss = me.clamp(me.speedLoss, -100000, 0);
        me.energyBleedKt += me.speedLoss * FPS2KT;
        me.speedLoss = me.speedLoss-me.vector_thrust*me.speedLoss*0.66;# vector thrust will only bleed 1/3 of the calculated loss.
        return me.speedLoss;
    },

	bleed32800at0g: func () {#GCD
		me.loss_fps = 0 + ((me.last_dt - 0)/(15 - 0))*(-330 - 0);
		return me.loss_fps*M2FT;
	},

	bleed32800at25g: func () {#GCD
		me.loss_fps = 0 + ((me.last_dt - 0)/(3.5 - 0))*(-240 - 0);
		return me.loss_fps*M2FT;
	},

	bleed0at0g: func () {#GCD
		me.loss_fps = 0 + ((me.last_dt - 0)/(22 - 0))*(-950 - 0);
		return me.loss_fps*M2FT;
	},

	bleed0at25g: func () {#GCD
		me.loss_fps = 0 + ((me.last_dt - 0)/(7 - 0))*(-750 - 0);
		return me.loss_fps*M2FT;
	},

	flight: func {#GCD
		if (me.Tgt != nil and me.Tgt.isValid() == FALSE) {
			print(me.type~": Target went away, deleting missile.");
			me.sendMessage(me.type~" missed "~me.callsign~": Target logged off.");
			me.del();
			return;
		}
		me.dt = deltaSec.getValue();#TODO: time since last time nasal timers were called
		if (me.dt == 0) {
			#FG is likely paused
			me.paused = 1;
			settimer(func me.flight(), 0.00);
			return;
		}
		#if just called from release() then dt is almost 0 (cannot be zero as we use it to divide with)
		# It can also not be too small, then the missile will lag behind aircraft and seem to be fired from behind the aircraft.
		#dt = dt/2;
		me.elapsed = systime();
		if (me.paused == 1) {
			# sim has been unpaused lets make sure dt becomes very small to let elapsed time catch up.
			me.paused = 0;
			me.elapsed_last = me.elapsed-0.02;
		}
		me.init_launch = 0;
		if (me.elapsed_last != 0) {
			#if (getprop("sim/speed-up") == 1) {
				me.dt = (me.elapsed - me.elapsed_last)*speedUp.getValue();
			#} else {
			#	dt = getprop("sim/time/delta-sec")*getprop("sim/speed-up");
			#}
			me.init_launch = 1;
			if(me.dt <= 0) {
				# to prevent pow floating point error in line:cdm = 0.2965 * math.pow(me.speed_m, -1.1506) + me.cd;
				# could happen if the OS adjusts the clock backwards
				me.dt = 0.00001;
			}
		}
		me.elapsed_last = me.elapsed;


		me.life_time += me.dt;

		if(me.life_time > 8) {# todo: make this duration configurable
			me.SwSoundFireOnOff.setBoolValue(FALSE);
		}

		me.thrust_lbf = me.thrust();# pounds force (lbf)


		# Get total old speed, thats what we will use in next loop.
		me.old_speed_horz_fps = math.sqrt((me.speed_east_fps*me.speed_east_fps)+(me.speed_north_fps*me.speed_north_fps));
		me.old_speed_fps = math.sqrt((me.old_speed_horz_fps*me.old_speed_horz_fps)+(me.speed_down_fps*me.speed_down_fps));

		me.setRadarProperties(me.old_speed_fps);



		# Get air density and speed of sound (fps):
		me.rs = me.rho_sndspeed(me.altN.getValue() + me.density_alt_diff);
		me.rho = me.rs[0];
		me.sound_fps = me.rs[1];

		me.max_g_current = me.maxG(me.rho, me.max_g);

		me.speed_m = me.old_speed_fps / me.sound_fps;

		if (me.old_speed_fps > me.maxFPS) {
			me.maxFPS = me.old_speed_fps;
		}
		if (me.speed_m > me.maxMach) {
			me.maxMach = me.speed_m;
		}
		if (me.speed_m > me.maxMach1 and me.life_time > me.drop_time and me.life_time <= (me.drop_time + me.stage_1_duration)) {
			me.maxMach1 = me.speed_m;
		}
		if (me.speed_m > me.maxMach2 and me.life_time > (me.drop_time + me.stage_1_duration) and me.life_time <= (me.drop_time + me.stage_1_duration + me.stage_2_duration)) {
			me.maxMach2 = me.speed_m;
		}
		if (me.maxMach3 == 0 and me.life_time > (me.drop_time + me.stage_1_duration + me.stage_2_duration)) {
			me.maxMach3 = me.speed_m;
		}

		me.Cd = me.drag(me.speed_m);

		me.speed_change_fps = me.speedChange(me.thrust_lbf, me.rho, me.Cd);


		if (me.last_dt != 0) {
			me.speed_change_fps = me.speed_change_fps + me.energyBleed(me.g, me.altN.getValue() + me.density_alt_diff);
		}

		# Get target position.
		if (me.Tgt != nil) {
#			me.t_coord = me.Tgt.get_Coord();
		}

		###################
		#### Guidance.#####
		###################
		if (me.Tgt != nil and me.free == FALSE and me.guidance != "unguided"
			and (me.rail == FALSE or me.rail_passed == TRUE)) {
				#
				# Here we figure out how to guide, navigate and steer.
				#
				me.guide();
				me.limitG();

	            me.pitch      += me.track_signal_e;
            	me.hdg        += me.track_signal_h;
	            #printf("%.1f deg elevation command done, new pitch: %.1f deg", me.track_signal_e, pitch_deg);
	            #printf("%.1f deg bearing command done, new heading: %.1f", me.last_track_h, hdg_deg);
		} else {
			me.track_signal_e = 0;
			me.track_signal_h = 0;
			#printf("not guiding %d %d %d %d %d",me.Tgt != nil,me.free == FALSE,me.guidance != "unguided",me.rail == FALSE,me.rail_passed == TRUE);
		}
       	me.last_track_e = me.track_signal_e;
		me.last_track_h = me.track_signal_h;

		me.new_speed_fps        = me.speed_change_fps + me.old_speed_fps;
		if (me.new_speed_fps < 0) {
			# drag and bleed can theoretically make the speed less than 0, this will prevent that from happening.
			me.new_speed_fps = 0.001;
		}

		# Break speed change down total speed to North, East and Down components.
		me.speed_down_fps       = -math.sin(me.pitch * D2R) * me.new_speed_fps;
		me.speed_horizontal_fps = math.cos(me.pitch * D2R) * me.new_speed_fps;
		me.speed_north_fps      = math.cos(me.hdg * D2R) * me.speed_horizontal_fps;
		me.speed_east_fps       = math.sin(me.hdg * D2R) * me.speed_horizontal_fps;
		me.speed_down_fps      += g_fps * me.dt;

		if (me.rail == TRUE and me.rail_passed == FALSE) {
			# missile still on rail, lets calculate its speed relative to the wind coming in from the aircraft nose.
			me.rail_speed_into_wind = me.rail_speed_into_wind + me.speed_change_fps;
		} else {
			# gravity acc makes the weapon pitch down
			me.pitch = math.atan2(-me.speed_down_fps, me.speed_horizontal_fps ) * R2D;
		}



		#printf("down_s=%.1f grav=%.1f", me.speed_down_fps*me.dt, g_fps * me.dt * !grav_bomb * me.dt);

		if (me.rail == TRUE and me.rail_passed == FALSE) {
			me.u = noseAir.getValue();# airstream from nose
			#var v = getprop("velocities/vBody-fps");# airstream from side
			me.w = belowAir.getValue();# airstream from below

			if (me.rail_forward == TRUE) {
				me.pitch = OurPitch.getValue();
				me.opposing_wind = me.u;
				me.hdg = OurHdg.getValue();
			} else {
				me.pitch = OurPitch.getValue() + me.rail_pitch_deg;
				if (me.rail_pitch_deg == 90) {
					me.opposing_wind = -me.w;
				} else {
					# no incoming airstream if not vertical tube
					me.opposing_wind = 0;
				}
				me.hdg = me.Tgt.get_bearing();
			}

			me.speed_on_rail = me.clamp(me.rail_speed_into_wind - me.opposing_wind, 0, 1000000);
			me.movement_on_rail = me.speed_on_rail * me.dt;

			me.rail_pos = me.rail_pos + me.movement_on_rail;
			if (me.rail_forward == TRUE) {
				me.x = me.x - (me.movement_on_rail * FT2M);# negative cause positive is rear in body coordinates
			} elsif (me.rail_pitch_deg == 90) {
				me.z = me.z + (me.movement_on_rail * FT2M);# positive cause positive is up in body coordinates
			} else {
				me.x = me.x - (me.movement_on_rail * FT2M);
			}
		}

		if (me.rail == FALSE or me.rail_passed == TRUE) {
			# misssile not on rail, lets move it to next waypoint
			me.alt_ft = me.alt_ft - (me.speed_down_fps * me.dt);
			me.dist_h_m = me.speed_horizontal_fps * me.dt * FT2M;
			me.coord.apply_course_distance(me.hdg, me.dist_h_m);
			me.coord.set_alt(me.alt_ft * FT2M);
		} else {
			# missile on rail, lets move it on the rail
			if (me.rail_pitch_deg == 90 or me.rail_forward == TRUE) {
				var init_coord = nil;
				if (offsetMethod == TRUE) {
					me.geodPos = aircraftToCart({x:-me.x, y:me.y, z: -me.z});
					me.coord.set_xyz(me.geodPos.x, me.geodPos.y, me.geodPos.z);
				} else {
					me.coord = me.getGPS(me.x, me.y, me.z, OurPitch.getValue());
				}
			} else {
				# kind of a hack, but work
				me.coord = me.getGPS(me.x, me.y, me.z, OurPitch.getValue()+me.rail_pitch_deg);
			}
			me.alt_ft = me.coord.alt() * M2FT;
			# find its speed, for used in calc old speed
			me.speed_down_fps       = -math.sin(me.pitch * D2R) * me.rail_speed_into_wind;
			me.speed_horizontal_fps = math.cos(me.pitch * D2R) * me.rail_speed_into_wind;
			me.speed_north_fps      = math.cos(me.hdg * D2R) * me.speed_horizontal_fps;
			me.speed_east_fps       = math.sin(me.hdg * D2R) * me.speed_horizontal_fps;
		}
		if (me.alt_ft > me.maxAlt) {
			me.maxAlt = me.alt_ft;
		}
		# Get target position.
		if (me.Tgt != nil) {
			if (me.flareLock == FALSE and me.chaffLock == FALSE) {
				me.t_coord = me.Tgt.get_Coord();
			} else {
				# we are chasing a flare, lets update the flares position.
				if (me.flareLock == TRUE) {
					me.flarespeed_fps = me.flarespeed_fps - (25 * me.dt);#flare deacc. 15 kt per second.
				} else {
					me.flarespeed_fps = me.flarespeed_fps - (50 * me.dt);#chaff deacc. 30 kt per second.
				}
				if (me.flarespeed_fps < 0) {
					me.flarespeed_fps = 0;
				}
				me.flare_speed_down_fps       = -math.sin(me.flare_pitch * D2R) * me.flarespeed_fps;
				me.flare_speed_horizontal_fps = math.cos(me.flare_pitch * D2R) * me.flarespeed_fps;
				me.flare_alt_ft = me.t_coord.alt()*M2FT - (me.flare_speed_down_fps * me.dt);
				me.flare_dist_h_m = me.flare_speed_horizontal_fps * me.dt * FT2M;
				me.t_coord.apply_course_distance(me.flare_hdg, me.flare_dist_h_m);
				me.t_coord.set_alt(me.flare_alt_ft * FT2M);
			}
		}
		# record coords so we can give the latest nearest position for impact.
		me.before_last_coord   = geo.Coord.new(me.last_coord);
		me.last_coord          = geo.Coord.new(me.coord);
		if (me.Tgt != nil) {
			me.before_last_t_coord = geo.Coord.new(me.last_t_coord);
			me.last_t_coord        = geo.Coord.new(me.t_coord);
		}

		# performance logging:
		#
		#var q = 0.5 * rho * me.old_speed_fps * me.old_speed_fps;
		#setprop("logging/missile/dist-nm", me.ac_init.distance_to(me.coord)*M2NM);
		#setprop("logging/missile/alt-m", me.alt_ft * FT2M);
		#setprop("logging/missile/speed-m", me.speed_m*1000);
		#setprop("logging/missile/drag-lbf", Cd * q * me.ref_area_sqft);
		#setprop("logging/missile/thrust-lbf", thrust_lbf);

		me.setFirst();

		me.latN.setDoubleValue(me.coord.lat());
		me.lonN.setDoubleValue(me.coord.lon());
		me.altN.setDoubleValue(me.alt_ft);
		me.pitchN.setDoubleValue(me.pitch);
		me.hdgN.setDoubleValue(me.hdg);
		#printf("pitch %d", me.pitch);
		# log missiles to unicsv for visualizing flightpath in Google Earth
		#
		#setprop("/logging/missile/latitude-deg", me.coord.lat());
		#setprop("/logging/missile/longitude-deg", me.coord.lon());
		#setprop("/logging/missile/altitude-ft", alt_ft);
		#setprop("/logging/missile/t-latitude-deg", me.t_coord.lat());
		#setprop("/logging/missile/t-longitude-deg", me.t_coord.lon());
		#setprop("/logging/missile/t-altitude-ft", me.t_coord.alt()*M2FT);

		##############################
		#### Proximity detection.#####
		##############################
		if (me.rail == FALSE or me.rail_passed == TRUE) {
 			if ( me.free == FALSE ) {
 				# check if the missile overloaded with G force.
				me.g = me.steering_speed_G(me.track_signal_e, me.track_signal_h, me.old_speed_fps, me.dt);

				if ( me.g > me.max_g_current and me.init_launch != 0) {
					me.free = TRUE;
					printf("%s: Missile attempted to pull too many G, it broke.", me.type);
				}
			} else {
				me.g = 0;
			}

			me.exploded = me.proximity_detection();

#
# Uncomment the following lines to check stats while flying:
#
#printf("Mach %02.2f , time %03.1f s , thrust %03.1f lbf , G-force %02.2f", me.speed_m, me.life_time, me.thrust_lbf, me.g);
#printf("Alt %05.1f ft , distance to target %02.1f NM", me.alt_ft, me.direct_dist_m*M2NM);

			if (me.exploded == TRUE) {
				printf("%s max absolute %.2f Mach. Max relative %.2f Mach. Max alt %6d ft. Terminal %.2f mach.", me.type, me.maxMach, me.maxMach-me.startMach, me.maxAlt, me.speed_m);
				printf("%s max relative %d ft/s.", me.type, me.maxFPS-me.startFPS);
				printf(" Absolute %.2f Mach in stage 1. Absolute %.2f Mach in stage 2. Absolute %.2f mach propulsion end.", me.maxMach1, me.maxMach2, me.maxMach3);
				printf(" Fired at %s from %.1f Mach, %5d ft at %3d NM distance. Flew %0.1f NM.", me.callsign, me.startMach, me.startAlt, me.startDist * M2NM, me.ac_init.direct_distance_to(me.coord)*M2NM);
				# We exploded, and start the sound propagation towards the plane
				me.sndSpeed = me.sound_fps;
				me.sndDistance = 0;
				me.elapsed_last = systime();
				if (me.explodeSound == TRUE) {
					me.sndPropagate();
				} else {
					settimer( func me.del(), 10);
				}
				return;
			}
		} else {
			me.g = 0;
		}

		if (me.rail_passed == FALSE and (me.rail == FALSE or me.rail_pos > me.rail_dist_m * M2FT)) {
			me.rail_passed = TRUE;
			#print("rail passed");
		}

		# consume fuel
		if (me.life_time > (me.drop_time + me.stage_1_duration + me.stage_2_duration)) {
			me.weight_current = me.weight_launch_lbm - me.weight_fuel_lbm;
		} elsif (me.life_time > (me.drop_time + me.stage_1_duration)) {
			me.weight_current = me.weight_current - me.fuel_per_sec_2 * me.dt;
		} elsif (me.life_time > me.drop_time) {
			me.weight_current = me.weight_current - me.fuel_per_sec_1 * me.dt;
		}
		#printf("weight %0.1f", me.weight_current);
		me.mass = me.weight_current / slugs_to_lbm;

		# telemetry
		if (me.data == TRUE) {
			me.eta = me.free == TRUE or me.horz_closing_rate_fps == -1?-1:(me.dist_curr*M2FT)/me.horz_closing_rate_fps;
			me.hit = 50;# in percent
			if (me.life_time > me.drop_time+me.stage_1_duration) {
				# little less optimistic after reaching topspeed
				if (me.selfdestruct_time-me.life_time < me.eta) {
					# reduce alot if eta later than lifespan
					me.hit -= 75;
				} elsif (me.eta != -1 and (me.selfdestruct_time-me.life_time) != 0) {
					# if its hitting late in life, then reduce
					me.hit -= (me.eta / (me.selfdestruct_time-me.life_time)) * 25;
				}
				if (me.eta > 0) {
					# penalty if eta is high
					me.hit -= me.clamp(40*me.eta/(me.life_time*0.85), 0, 40);
				}
			}
			if (me.curr_deviation_h != nil and me.dist_curr > 50) {
				# penalty for target being off-bore
				me.hit -= math.abs(me.curr_deviation_h)/2.5;
			}
			if (me.guiding == TRUE and me.t_speed_fps != nil and me.old_speed_fps > me.t_speed_fps and me.t_speed_fps != 0) {
				# bonus for traveling faster than target
				me.hit += me.clamp((me.old_speed_fps / me.t_speed_fps)*15,-25,50);
			}
			if (me.free == TRUE) {
				# penalty for not longer guiding
				me.hit -= 75;
			}
			me.hit = int(me.clamp(me.hit, 0, 90));
			me.ai.getNode("ETA").setIntValue(me.eta);
			me.ai.getNode("hit").setIntValue(me.hit);
		}

		me.last_dt = me.dt;
		settimer(func me.flight(), update_loop_time, SIM_TIME);
	},

	setFirst: func() {#GCD
		if (me.smoke_prop.getValue() == TRUE) {
			if (me.first == TRUE or first_in_air == FALSE) {
				# report position over MP for MP animation of smoke trail.
				me.first = TRUE;
				first_in_air = TRUE;
				if (me.mpShow == TRUE) {
					me.mpLat.setDoubleValue(me.coord.lat());
					me.mpLon.setDoubleValue(me.coord.lon());
					me.mpAlt.setDoubleValue(me.coord.alt());
				}
			}
		} elsif (me.first == TRUE and me.life_time > me.drop_time + me.stage_1_duration + me.stage_2_duration) {
			# this weapon was reporting its position over MP, but now its fuel has used up. So allow for another to do that.
			me.resetFirst();
		}
	},

	resetFirst: func() {#GCD
		first_in_air = FALSE;
		me.first = FALSE;
		if (me.mpShow == TRUE) {
			me.mpLat.setDoubleValue(0.0);
			me.mpLon.setDoubleValue(0.0);
			me.mpAlt.setDoubleValue(0.0);
		}
	},

	limitG: func () {#GCD
		#
		# Here will be set the max angle of pitch and the max angle of heading to avoid G overload
		#
        me.myG = me.steering_speed_G(me.track_signal_e, me.track_signal_h, me.old_speed_fps, me.dt);
        if(me.max_g_current < me.myG)
        {
            me.MyCoef = me.max_G_Rotation(me.track_signal_e, me.track_signal_h, me.old_speed_fps, me.dt, me.max_g_current);
            me.track_signal_e =  me.track_signal_e * me.MyCoef;
            me.track_signal_h =  me.track_signal_h * me.MyCoef;
            #print(sprintf("G1 %.2f", myG));
            me.myG = me.steering_speed_G(me.track_signal_e, me.track_signal_h, me.old_speed_fps, me.dt);
            #print(sprintf("G2 %.2f", myG)~sprintf(" - Coeff %.2f", MyCoef));
            if (me.limitGs == FALSE) {
            	printf("%s: Missile pulling almost max G: %.1f G", me.type, me.myG);
            }
        }
        if (me.limitGs == TRUE and me.myG > me.max_g_current/2) {
        	# Save the high performance manouving for later
        	me.track_signal_e = me.track_signal_e /2;
        }
	},

	setRadarProperties: func (new_speed_fps) {#GCD
		#
		# Set missile radar properties for use in selection view, radar and HUD.
		#
		me.self = geo.aircraft_position();
		me.ai.getNode("radar/bearing-deg", 1).setDoubleValue(me.self.course_to(me.coord));
		me.ai.getNode("radar/elevation-deg", 1).setDoubleValue(me.getPitch(me.self, me.coord));
		me.ai.getNode("radar/range-nm", 1).setDoubleValue(me.self.distance_to(me.coord)*M2NM);
		me.ai.getNode("velocities/true-airspeed-kt",1).setDoubleValue(new_speed_fps * FPS2KT);
		me.ai.getNode("velocities/vertical-speed-fps",1).setDoubleValue(-me.speed_down_fps);
	},

	rear_aspect: func () {#GCD
		#
		# If is heat-seeking rear-aspect-only missile, check if it has good view on engine(s) and can keep lock.
		#
		me.offset = me.aspectToExhaust();

		if (me.offset < 45) {
			# clear view of engine heat, keep the lock
			me.rearAspect = 1;
		} else {
			# the greater angle away from clear engine view the greater chance of losing lock.
			me.offset_away = me.offset - 45;
			me.probability = me.offset_away/135;
			me.probability = me.probability*2.5;# The higher the factor, the less chance to keep lock.
			me.rearAspect = rand() > me.probability;
		}

		#print ("RB-24J deviation from full rear-aspect: "~sprintf("%01.1f", offset)~" deg, keep IR lock on engine: "~rearAspect);

		return me.rearAspect;# 1: keep lock, 0: lose lock
	},

	aspectToExhaust: func () {#GCD
		# return angle to viewing rear of target
		me.vectorToEcho   = vector.Math.eulerToCartesian2(me.coord.course_to(me.t_coord), vector.Math.getPitch(me.coord, me.t_coord));
    	me.vectorEchoNose = vector.Math.eulerToCartesian3X(me.Tgt.get_heading(), me.Tgt.get_Pitch(), me.Tgt.get_Roll());
    	me.angleToRear    = geo.normdeg180(vector.Math.angleBetweenVectors(me.vectorToEcho, me.vectorEchoNose));
    	#printf("Angle to rear %d degs.", math.abs(me.angleToRear));
    	return math.abs(me.angleToRear);
    },

    aspectToTop: func () {#GCD
    	# WIP: not used, and might never be
    	me.vectorEchoTop  = vector.Math.eulerToCartesian3Z(echoHeading, echoPitch, echoRoll);
    	me.view2D         = vector.Math.projVectorOnPlane(me.vectorEchoTop, me.vectorToEcho);
		me.angleToNose    = geo.normdeg180(vector.Math.angleBetweenVectors(me.vectorEchoNose, me.view2D)+180);
		me.angleToBelly   = geo.normdeg180(vector.Math.angleBetweenVectors(me.vectorEchoTop, me.vectorToEcho));
	},

	guide: func() {#GCD
		#
		# navigation and guidance
		#
		me.raw_steer_signal_elev = 0;
		me.raw_steer_signal_head = 0;

		me.guiding = TRUE;

		# Calculate current target elevation and azimut deviation.
		me.t_alt            = me.t_coord.alt()*M2FT;
		#var t_alt_delta_m   = (me.t_alt - me.alt_ft) * FT2M;
		me.dist_curr        = me.coord.distance_to(me.t_coord);
		me.dist_curr_direct = me.coord.direct_distance_to(me.t_coord);
		me.dist_curr_hypo   = math.sqrt(me.dist_curr_direct*me.dist_curr_direct+math.pow(me.t_coord.alt()-me.coord.alt(),2));
		me.t_elev_deg       = me.getPitch(me.coord, me.t_coord);
		me.t_course         = me.coord.course_to(me.t_coord);
		me.curr_deviation_e = me.t_elev_deg - me.pitch;
		me.curr_deviation_h = me.t_course - me.hdg;

		#var (t_course, me.dist_curr) = courseAndDistance(me.coord, me.t_coord);
		#me.dist_curr = me.dist_curr * NM2M;

		#printf("Elevation to target %0.2f degs, pitch deviation %0.2f degs, pitch %.2f degs", me.t_elev_deg, me.curr_deviation_e, me.pitch);
		#printf("Bearing to target %0.2f degs, heading deviation %0.2f degs, heading %.2f degs", me.t_course, me.curr_deviation_h, me.hdg);
		#printf("Altitude above launch platform = %.1f ft", M2FT * (me.coord.alt()-me.ac.alt()));
		#printf("Altitude. Target %.1f. Missile %.1f. Atan2 %.1f", me.t_coord.alt()*M2FT, me.coord.alt()*M2FT, math.atan2( me.t_coord.alt()-me.coord.alt(), me.dist_curr ) * R2D);

		me.curr_deviation_h = geo.normdeg180(me.curr_deviation_h);

		me.checkForFlare();

		me.checkForChaff();

		me.checkForSun();

		me.checkForLOS();

		me.checkForGuidance();

		me.canSeekerKeepUp();

		me.cruiseAndLoft();

		me.APN();# Proportional navigation

		me.track_signal_e = me.raw_steer_signal_elev * !me.free * me.guiding;
		me.track_signal_h = me.raw_steer_signal_head * !me.free * me.guiding;

		#printf("%.1f deg elevate command desired", me.track_signal_e);
		#printf("%.1f deg heading command desired", me.track_signal_h);

		# record some variables for next loop:
		me.dist_last           = me.dist_curr;
		me.dist_direct_last    = me.dist_curr_direct;
		me.dist_last_hypo      = me.dist_curr_hypo;
		me.last_t_course       = me.t_course;
		me.last_t_elev_deg     = me.t_elev_deg;
		me.last_cruise_or_loft = me.cruise_or_loft;
	},

	checkForFlare: func () {#GCD
		#
		# Check for being fooled by flare.
		#
		if (me.guidance == "heat" and me.flareLock == FALSE and (getprop("sim/time/elapsed-sec")-me.flareTime) > 1) {
			#
			# TODO: Use Richards Emissary for this.
			#
			me.flareNode = me.Tgt.getFlareNode();
			if (me.flareNode != nil) {
				me.flareNumber = me.flareNode.getValue();
				if (me.flareNumber != nil and me.flareNumber != 0) {
					if (me.flareNumber != me.flareLast) {
						# target has released a new flare, lets check if it fools us
						me.flareTime = getprop("sim/time/elapsed-sec");
						me.flareLast = me.flareNumber;
						me.aspectDeg = me.aspectToExhaust() / 180;
						me.flareLock = rand() < (1-me.flareResistance + ((1-me.flareResistance) * 0.5 * me.aspectDeg));# 50% extra chance to be fooled if front aspect
						#printf("Lock on flare probability: %d%%", (1-me.flareResistance + ((1-me.flareResistance) * 0.5 * me.aspectDeg))*100);
						if (me.flareLock == TRUE) {
							# fooled by the flare
							print(me.type~": Missile locked on flare from "~me.callsign);
							me.flarespeed_fps = me.Tgt.get_Speed()*KT2FPS;
							me.flare_hdg      = me.Tgt.get_heading();
							me.flare_pitch    = me.Tgt.get_Pitch();
						} else {
							print(me.type~": Missile ignored flare from "~me.callsign);
						}
					}
				}
			}
		}
	},

	checkForChaff: func () {#GCD
		#
		# Check for being fooled by chaff.
		#
		if ((me.guidance == "radar" or me.guidance == "semi-radar") and me.chaffLock == FALSE and (getprop("sim/time/elapsed-sec")-me.chaffTime) > 1) {
			#
			# TODO: Use Richards Emissary for this.
			#
			me.chaffNode = me.Tgt.getChaffNode();
			if (me.chaffNode != nil) {
				me.chaffNumber = me.chaffNode.getValue();
				if (me.chaffNumber != nil and me.chaffNumber != 0) {
					if (me.chaffNumber != me.chaffLast) {# problem here is MP interpolates to new values. Hence the timer.
						# target has released a new chaff, lets check if it blinds us
						me.chaffLast = me.chaffNumber;
						me.chaffTime = getprop("sim/time/elapsed-sec");
						#me.aspectNorm = math.abs(geo.normdeg180(me.aspectToExhaust() * 2))/180;# 0 = viewing engine or front, 1 = viewing side, belly or top.

						# chance to lock on chaff when viewing engine or nose, less if viewing other aspects
						#me.chaffLock = rand() > (me.chaffResistance + (1-me.chaffResistance) * 0.5 * me.aspectNorm);

						me.chaffLock = rand() > me.chaffResistance;
						#printf("Lock on chaff probability: %d%%", (1-me.chaffResistance)*100);

						if (me.chaffLock == TRUE) {
							print(me.type~": Missile locked on chaff from "~me.callsign);
							me.flarespeed_fps = me.Tgt.get_Speed()*KT2FPS;
							me.flare_hdg      = me.Tgt.get_heading();
							me.flare_pitch    = me.Tgt.get_Pitch();
						} else {
							print(me.type~": Missile ignored chaff from "~me.callsign);
						}
					}
				}
			}
		}
	},

	checkForSun: func () {
		if (me.guidance == "heat" and me.sun_enabled == TRUE and getprop("/rendering/scene/diffuse/red") > 0.6) {
			# test for heat seeker locked on to sun
			me.sun_dev_e = me.getPitch(me.coord, me.sun) - me.pitch;
			me.sun_dev_h = me.coord.course_to(me.sun) - me.hdg;
			me.sun_dev_h = geo.normdeg180(me.sun_dev_h);
			# now we check if the sun is behind the target, which is the direction the gyro seeker is pointed at:
			me.sun_dev = math.sqrt((me.sun_dev_e-me.curr_deviation_e)*(me.sun_dev_e-me.curr_deviation_e)+(me.sun_dev_h-me.curr_deviation_h)*(me.sun_dev_h-me.curr_deviation_h));
			if (me.sun_dev < me.sun_lock) {
				print(me.type~": Locked onto sun, lost target. ");
				me.lock_on_sun = TRUE;
				me.free = TRUE;
			}
		}
	},

	checkForLOS: func () {#GCD
		if (pickingMethod == TRUE and me.guidance != "gps" and me.guidance != "unguided") {
			me.xyz          = {"x":me.coord.x(),                  "y":me.coord.y(),                 "z":me.coord.z()};
		    me.directionLOS = {"x":me.t_coord.x()-me.coord.x(),   "y":me.t_coord.y()-me.coord.y(),  "z":me.t_coord.z()-me.coord.z()};

			# Check for terrain between own weapon and target:
			me.terrainGeod = get_cart_ground_intersection(me.xyz, me.directionLOS);
			if (me.terrainGeod == nil) {
				me.lostLOS = FALSE;
				return;
			} else {
				me.terrain = geo.Coord.new();
				me.terrain.set_latlon(me.terrainGeod.lat, me.terrainGeod.lon, me.terrainGeod.elevation);
				me.maxDist = me.coord.direct_distance_to(me.t_coord);
				me.terrainDist = me.coord.direct_distance_to(me.terrain);
				if (me.terrainDist >= me.maxDist) {
					me.lostLOS = FALSE;
					return;
				}
			}
			if (me.guidance == "semi-radar" or me.guidance == "laser" or me.guidance == "heat" or me.guidance == "vision") {
				if (me.lostLOS == FALSE) {
					print(me.type~": Not guiding (lost line of sight, trying to reaquire)");
				}
				me.lostLOS = TRUE;
				me.guiding = FALSE;
				return;
			} elsif(me.guidance == "radar") {
				if (me.lostLOS == FALSE) {
					print(me.type~": Gave up (lost line of sight)");
				}
				me.lostLOS = TRUE;
				me.free = TRUE;
				return;
			}
		}
		me.lostLOS = FALSE;
	},

	checkForGuidance: func () {#GCD
		if(me.speed_m < me.min_speed_for_guiding) {
			# it doesn't guide at lower speeds
			me.guiding = FALSE;
			if (me.tooLowSpeed == FALSE) {
				print(me.type~": Not guiding (too low speed)");
			}
			me.tooLowSpeed = TRUE;
		} elsif ((me.guidance == "semi-radar" or me.guidance =="laser") and me.is_painted(me.Tgt) == FALSE) {
			# if its semi-radar guided and the target is no longer painted
			me.guiding = FALSE;
			if (me.semiLostLock == FALSE) {
				print(me.type~": Not guiding (lost radar reflection, trying to reaquire)");
			}
			me.semiLostLock = TRUE;
		} elsif (!me.FOV_check(me.curr_deviation_h, me.curr_deviation_e, me.max_seeker_dev) and me.guidance != "gps") {
			# target is not in missile seeker view anymore
			#if (me.curr_deviation_e > me.max_seeker_dev) {
			#	me.viewLost = "Target is above seeker view.";
			#} elsif (me.curr_deviation_e < (-1 * me.max_seeker_dev)) {
			#	me.viewLost = "Target is below seeker view. "~(me.dist_curr*M2NM)~" NM and "~((me.coord.alt()-me.t_coord.alt())*M2FT)~" ft diff.";
			#} elsif (me.curr_deviation_h > me.max_seeker_dev) {
			#	me.viewLost = "Target is right of seeker view.";
			#} else {
			#	me.viewLost = "Target is left of seeker view.";
			#}
			print(me.type~": Target is not in missile seeker view anymore. ");#~me.viewLost);
			me.free = TRUE;
		} elsif (me.all_aspect == FALSE and me.rear_aspect() == FALSE) {
			me.guiding = FALSE;
           	if (me.heatLostLock == FALSE) {
        		print(me.type~": Missile lost heat lock, attempting to reaquire..");
        	}
        	me.heatLostLock = TRUE;
		} elsif (me.life_time < me.drop_time) {
			me.guiding = FALSE;
		} elsif (me.semiLostLock == TRUE) {
			print(me.type~": Reaquired radar reflection.");
			me.semiLostLock = FALSE;
		} elsif (me.heatLostLock == TRUE) {
	       	print(me.type~": Regained heat lock.");
	       	me.heatLostLock = FALSE;
	    } elsif (me.tooLowSpeed == TRUE) {
			print(me.type~": Gained speed and started guiding.");
			me.tooLowSpeed = FALSE;
		}
	},

	canSeekerKeepUp: func () {#GCD
		if (me.last_deviation_e != nil and (me.guidance == "heat" or me.guidance == "vision")) {
			# calculate if the seeker can keep up with the angular change of the target
			#
			# missile own movement is subtracted from this change due to seeker being on gyroscope
			#
			me.dve_dist = me.curr_deviation_e - me.last_deviation_e + me.last_track_e;
			me.dvh_dist = me.curr_deviation_h - me.last_deviation_h + me.last_track_h;
			me.deviation_per_sec = math.sqrt(me.dve_dist*me.dve_dist+me.dvh_dist*me.dvh_dist)/me.dt;

			if (me.deviation_per_sec > me.angular_speed) {
				#print(sprintf("last-elev=%.1f", me.last_deviation_e)~sprintf(" last-elev-adj=%.1f", me.last_track_e));
				#print(sprintf("last-head=%.1f", me.last_deviation_h)~sprintf(" last-head-adj=%.1f", me.last_track_h));
				# lost lock due to angular speed limit
				printf("%s: %.1f deg/s too fast angular change for seeker head.", me.type, me.deviation_per_sec);
				me.free = TRUE;
			}
		}

		me.last_deviation_e = me.curr_deviation_e;
		me.last_deviation_h = me.curr_deviation_h;
	},

	cruiseAndLoft: func () {#GCD
		#
		# cruise, loft, cruise-missile
		#
		if (me.guiding == FALSE) {
			return;
		}
		me.loft_angle = 15;# notice Shinobi used 26.5651 degs, but Raider1 found a source saying 10-20 degs.
		me.cruise_or_loft = FALSE;
		me.time_before_snap_up = me.drop_time * 3;
		me.limitGs = FALSE;

        if(me.loft_alt != 0 and me.snapUp == FALSE) {
        	# this is for Air to ground/sea cruise-missile (SCALP, Sea-Eagle, Taurus, Tomahawk, RB-15...)

        	# detect terrain for use in terrain following
        	me.nextGroundElevationMem[1] -= 1;
            me.geoPlus2 = me.nextGeoloc(me.coord.lat(), me.coord.lon(), me.hdg, me.old_speed_fps, me.dt*5);
            me.geoPlus3 = me.nextGeoloc(me.coord.lat(), me.coord.lon(), me.hdg, me.old_speed_fps, me.dt*10);
            me.geoPlus4 = me.nextGeoloc(me.coord.lat(), me.coord.lon(), me.hdg, me.old_speed_fps, me.dt*20);
            me.e1 = geo.elevation(me.coord.lat(), me.coord.lon());# This is done, to make sure is does not decline before it has passed obstacle.
            me.e2 = geo.elevation(me.geoPlus2.lat(), me.geoPlus2.lon());# This is the main one.
            me.e3 = geo.elevation(me.geoPlus3.lat(), me.geoPlus3.lon());# This is an extra, just in case there is an high cliff it needs longer time to climb.
            me.e4 = geo.elevation(me.geoPlus4.lat(), me.geoPlus4.lon());
			if (me.e1 != nil) {
            	me.nextGroundElevation = me.e1;
            } else {
            	print(me.type~": nil terrain, blame terrasync! Cruise-missile keeping altitude.");
            }
            if (me.e2 != nil and me.e2 > me.nextGroundElevation) {
            	me.nextGroundElevation = me.e2;
            	if (me.e2 > me.nextGroundElevationMem[0] or me.nextGroundElevationMem[1] < 0) {
            		me.nextGroundElevationMem[0] = me.e2;
            		me.nextGroundElevationMem[1] = 5;
            	}
            }
            if (me.nextGroundElevationMem[0] > me.nextGroundElevation) {
            	me.nextGroundElevation = me.nextGroundElevationMem[0];
            }
            if (me.e3 != nil and me.e3 > me.nextGroundElevation) {
            	me.nextGroundElevation = me.e3;
            }
            if (me.e4 != nil and me.e4 > me.nextGroundElevation) {
            	me.nextGroundElevation = me.e4;
            }

            me.Daground = 0;# zero for sealevel in case target is ship. Don't shoot A/S missiles over terrain. :)
            if(me.Tgt.get_type() == SURFACE or me.follow == TRUE) {
                me.Daground = me.nextGroundElevation * M2FT;
            }
            me.loft_alt_curr = me.loft_alt;
            if (me.dist_curr < me.old_speed_fps * 4 * FT2M and me.dist_curr > me.old_speed_fps * 2.5 * FT2M) {
            	# the missile lofts a bit at the end to avoid APN to slam it into ground before target is reached.
            	# end here is between 2.5-4 seconds
            	me.loft_alt_curr = me.loft_alt*2;
            }
            if (me.dist_curr > me.old_speed_fps * 2.5 * FT2M) {# need to give the missile time to do final navigation
                # it's 1 or 2 seconds for this kinds of missiles...
                me.t_alt_delta_ft = (me.loft_alt_curr + me.Daground - me.alt_ft);
                #print("var t_alt_delta_m : "~t_alt_delta_m);
                if(me.loft_alt_curr + me.Daground > me.alt_ft) {
                    # 200 is for a very short reaction to terrain
                    #print("Moving up");
                    me.raw_steer_signal_elev = -me.pitch + math.atan2(me.t_alt_delta_ft, me.old_speed_fps * me.dt * 5) * R2D;
                } else {
                    # that means a dive angle of 22.5° (a bit less
                    # coz me.alt is in feet) (I let this alt in feet on purpose (more this figure is low, more the future pitch is high)
                    #print("Moving down");
                    me.slope = me.clamp(me.t_alt_delta_ft / 300, -5, 0);# the lower the desired alt is, the steeper the slope.
                    me.raw_steer_signal_elev = -me.pitch + me.clamp(math.atan2(me.t_alt_delta_ft, me.old_speed_fps * me.dt * 5) * R2D, me.slope, 0);
                }
                me.cruise_or_loft = TRUE;
            } elsif (me.dist_curr > 500) {
                # we put 9 feets up the target to avoid ground at the
                # last minute...
                #print("less than 1000 m to target");
                #me.raw_steer_signal_elev = -me.pitch + math.atan2(t_alt_delta_m + 100, me.dist_curr) * R2D;
                #me.cruise_or_loft = 1;
            } else {
            	#print("less than 500 m to target");
            }
            if (me.cruise_or_loft == TRUE) {
            	#print(" pitch "~me.pitch~" + me.raw_steer_signal_elev "~me.raw_steer_signal_elev);
            }
        } elsif (me.rail == TRUE and me.rail_forward == FALSE and me.rotate_token == FALSE) {
			# tube launched missile turns towards target

			me.raw_steer_signal_elev = me.curr_deviation_e;
			#print("Turning, desire "~me.t_elev_deg~" degs pitch.");
			me.cruise_or_loft = TRUE;
			me.limitGs = TRUE;
			if (math.abs(me.curr_deviation_e) < 20) {
				me.rotate_token = TRUE;
				#print("Is last turn, snap-up/PN takes it from here..")
			}
		} elsif (me.snapUp == TRUE and me.t_elev_deg > me.clamp(-80/me.speed_m,-30,-5) and me.dist_curr * M2NM > me.speed_m * 3
			 and me.t_elev_deg < me.loft_angle #and me.t_elev_deg > -7.5
			 and me.dive_token == FALSE) {
			# lofting: due to target is more than 10 miles out and we havent reached
			# our desired cruising alt, and the elevation to target is less than lofting angle.
			# The -7.5 limit, is so the seeker don't lose track of target when lofting.
			if (me.life_time < me.time_before_snap_up and me.coord.alt() * M2FT < me.loft_alt) {
				#print("preparing for lofting");
				me.cruise_or_loft = TRUE;
			} elsif (me.coord.alt() * M2FT < me.loft_alt) {
				me.raw_steer_signal_elev = -me.pitch + me.loft_angle;
				me.limitGs = TRUE;
				#print(sprintf("Lofting %.1f degs, dev is %.1f", me.loft_angle, me.raw_steer_signal_elev));
			} else {
				me.dive_token = TRUE;
				#print("Stopped lofting");
			}
			me.cruise_or_loft = TRUE;
		} elsif (me.snapUp == TRUE and me.coord.alt() > me.t_coord.alt() and me.last_cruise_or_loft == TRUE
		         and me.t_elev_deg > me.clamp(-80/me.speed_m,-30,-5) and me.dist_curr * M2NM > me.speed_m * 3) {
			# cruising: keeping altitude since target is below and more than -45 degs down

			me.ratio = (g_fps * me.dt)/me.old_speed_fps;
            me.attitude = 0;

            if (me.ratio < 1 and me.ratio > -1) {
                me.attitude = math.asin(me.ratio)*R2D;
            }

			me.raw_steer_signal_elev = -me.pitch + me.attitude;
			#print("Cruising, desire "~me.attitude~" degs pitch.");
			me.cruise_or_loft = TRUE;
			me.limitGs = TRUE;
			me.dive_token = TRUE;
		} elsif (me.last_cruise_or_loft == TRUE and math.abs(me.curr_deviation_e) > 25 and me.life_time > me.time_before_snap_up) {
			# after cruising, point the missile in the general direction of the target, before PN starts guiding.
			#print("Rotating toward target");
			me.raw_steer_signal_elev = me.curr_deviation_e;
			me.cruise_or_loft = TRUE;
			#me.limitGs = TRUE;

			# TODO: this needs to be worked on.
		}
	},

	APN: func () {#GCD
		#
		# augmented proportional navigation
		#
		if (me.guiding == TRUE and me.free == FALSE and me.dist_last != nil and me.last_dt != 0) {
			# augmented proportional navigation for heading #
			#################################################

			if (me.navigation == "direct") {
				# pure pursuit
				me.raw_steer_signal_head = me.curr_deviation_h;
				if (me.cruise_or_loft == FALSE) {
					me.raw_steer_signal_elev = me.curr_deviation_e;
					me.attitudePN = math.atan2(-(me.speed_down_fps+g_fps * me.dt), me.speed_horizontal_fps ) * R2D;
		            me.gravComp = me.pitch - me.attitudePN;
		            #printf("Gravity compensation %0.2f degs", me.gravComp);
		            me.raw_steer_signal_elev += me.gravComp;
				}
				return;
			} elsif (find("APN", me.navigation)!=-1) {
				me.apn = 1;
			} else {
				me.apn = 0;
			}
			if ((me.dist_direct_last - me.dist_curr_direct) < 0) {
				# might happen if missile is cannot catch up to target. It might still be accelerating or it has lost too much speed.
				# PN needs closing rate to be positive to give meaningful steering commands. So we fly straight and hope for better closing rate.
				me.raw_steer_signal_head = 0;
				if (me.cruise_or_loft == FALSE) {
					me.raw_steer_signal_elev = 0;
					me.attitudePN = math.atan2(-(me.speed_down_fps+g_fps * me.dt), me.speed_horizontal_fps ) * R2D;
			        me.gravComp = me.pitch - me.attitudePN;
			        #printf("Gravity compensation %0.2f degs", me.gravComp);
			        #print("Negative closing rate");
			        me.raw_steer_signal_elev += me.gravComp;
			    }
		        return;
			}

			me.horz_closing_rate_fps = me.clamp(((me.dist_last - me.dist_curr)*M2FT)/me.dt, 0, 1000000);#clamped due to cruise missiles that can fly slower than target.
			#printf("Horz closing rate: %5d ft/sec", me.horz_closing_rate_fps);

			me.c_dv = geo.normdeg180(me.t_course-me.last_t_course);

			me.line_of_sight_rate_rps = (D2R*me.c_dv)/me.dt;#positive clockwise

			#printf("LOS rate: %.4f rad/s", line_of_sight_rate_rps);

			#if (me.before_last_t_coord != nil) {
			#	var t_heading = me.before_last_t_coord.course_to(me.t_coord);
			#	var t_dist   = me.before_last_t_coord.distance_to(me.t_coord);
			#	var t_dist_dir   = me.before_last_t_coord.direct_distance_to(me.t_coord);
			#	var t_climb      = me.t_coord.alt() - me.before_last_t_coord.alt();
			#	var t_horz_speed = (t_dist*M2FT)/(me.dt+me.last_dt);
			#	var t_speed      = (t_dist_dir*M2FT)/(me.dt+me.last_dt);
			#} else {
			#	var t_heading = me.last_t_coord.course_to(me.t_coord);
			#	var t_dist   = me.last_t_coord.distance_to(me.t_coord);
			#	var t_dist_dir   = me.last_t_coord.direct_distance_to(me.t_coord);
			#	var t_climb      = me.t_coord.alt() - me.last_t_coord.alt();
			#	var t_horz_speed = (t_dist*M2FT)/me.dt;
			#	var t_speed      = (t_dist_dir*M2FT)/me.dt;
			#}

			#var t_pitch      = math.atan2(t_climb,t_dist)*R2D;

			# calculate target acc as normal to LOS line:
			if ((me.flareLock == FALSE and me.chaffLock == FALSE) or me.t_heading == nil) {
				me.t_heading        = me.Tgt.get_heading();
				me.t_pitch          = me.Tgt.get_Pitch();
				me.t_speed_fps      = me.Tgt.get_Speed()*KT2FPS;#true airspeed
			} elsif (me.flarespeed_fps != nil) {
				me.t_speed_fps      = me.flarespeed_fps;#true airspeed
			}

			#if (me.last_t_coord.direct_distance_to(me.t_coord) != 0) {
			#	# taking sideslip and AoA into consideration:
			#	me.t_heading    = me.last_t_coord.course_to(me.t_coord);
			#	me.t_climb      = me.t_coord.alt() - me.last_t_coord.alt();
			#	me.t_dist       = me.last_t_coord.distance_to(me.t_coord);
			#	me.t_pitch      = math.atan2(me.t_climb, me.t_dist) * R2D;
			#} elsif (me.Tgt.get_Speed() > 25) {
				# target position was not updated since last loop.
				# to avoid confusing the navigation, we just fly
				# straight.
				#print("not updated");
			#	return;
			#}



			me.t_horz_speed_fps     = math.abs(math.cos(me.t_pitch*D2R)*me.t_speed_fps);#flawed due to AoA is not taken into account, but dont have that info.
			me.t_LOS_norm_head_deg  = me.t_course + 90;#when looking at target this direction will be 90 deg right of target
			me.t_LOS_norm_speed_fps = math.cos((me.t_LOS_norm_head_deg - me.t_heading)*D2R)*me.t_horz_speed_fps;

			if (me.last_t_norm_speed == nil) {
				me.last_t_norm_speed = me.t_LOS_norm_speed_fps;
			}

			me.t_LOS_norm_acc_fps2  = (me.t_LOS_norm_speed_fps - me.last_t_norm_speed)/me.dt;

			me.last_t_norm_speed = me.t_LOS_norm_speed_fps;

			me.toBody = math.cos(me.curr_deviation_h*D2R);#convert perpendicular LOS acc. to perpendicular body acc.
			if (me.toBody==0) me.toBody=0.00001;

			# acceleration perpendicular to instantaneous line of sight in feet/sec^2
			me.acc_lateral_fps2 = me.pro_constant*me.line_of_sight_rate_rps*me.horz_closing_rate_fps/me.toBody+me.apn*me.t_LOS_norm_acc_fps2;
			#printf("horz acc = %.1f + %.1f", proportionality_constant*line_of_sight_rate_rps*horz_closing_rate_fps, proportionality_constant*t_LOS_norm_acc/2);

			# now translate that sideways acc to an angle:
			me.velocity_vector_length_fps = me.clamp(me.old_speed_horz_fps, 0.0001, 1000000);
			me.commanded_lateral_vector_length_fps = me.acc_lateral_fps2*me.dt;

			#isosceles triangle:
			#me.raw_steer_signal_head = math.asin(me.clamp((me.commanded_lateral_vector_length_fps*0.5)/me.velocity_vector_length_fps,-1,1))*R2D*2;
			me.raw_steer_signal_head = math.atan2(me.commanded_lateral_vector_length_fps, me.velocity_vector_length_fps)*R2D;

			#printf("Proportional lead: %0.1f deg horz", -(me.curr_deviation_h-me.raw_steer_signal_head));

			#print(sprintf("LOS-rate=%.2f rad/s - closing-rate=%.1f ft/s",line_of_sight_rate_rps,horz_closing_rate_fps));
			#print(sprintf("commanded-perpendicular-acceleration=%.1f ft/s^2", acc_lateral_fps2));
			#printf("horz leading by %.1f deg, commanding %.1f deg", me.curr_deviation_h, me.raw_steer_signal_head);

			if (me.cruise_or_loft == FALSE) {# and me.last_cruise_or_loft == FALSE
				if (find("PN",me.navigation) != -1 and size(me.navigation) > 3) {
					me.fixed_aim = num(right(me.navigation, 2));
					me.raw_steer_signal_elev = me.curr_deviation_e+me.fixed_aim;
					me.attitudePN = math.atan2(-(me.speed_down_fps+g_fps * me.dt), me.speed_horizontal_fps ) * R2D;
		            me.gravComp = me.pitch - me.attitudePN;
		            #printf("Gravity compensation %0.2f degs", me.gravComp);
		            me.raw_steer_signal_elev += me.gravComp;
				} else {
					# augmented proportional navigation for elevation #
					###################################################
					#print(me.navigation~" in fully control");
					me.vert_closing_rate_fps = me.clamp(((me.dist_direct_last - me.dist_curr_direct)*M2FT)/me.dt, 0.0, 1000000);
					#printf("Vert closing rate: %5d ft/sec", me.vert_closing_rate_fps);
					me.line_of_sight_rate_up_rps = (D2R*(me.t_elev_deg-me.last_t_elev_deg))/me.dt;

					# calculate target acc as normal to LOS line: (up acc is positive)
					me.t_approach_bearing             = me.t_course + 180;


					# used to do this with trigonometry, but vector math is simpler to understand: (they give same result though)
					me.t_LOS_elev_norm_speed     = me.scalarProj(me.t_heading,me.t_pitch,me.t_speed_fps,me.t_approach_bearing,me.t_elev_deg*-1 +90);

					if (me.last_t_elev_norm_speed == nil) {
						me.last_t_elev_norm_speed = me.t_LOS_elev_norm_speed;
					}

					me.t_LOS_elev_norm_acc            = (me.t_LOS_elev_norm_speed - me.last_t_elev_norm_speed)/me.dt;
					me.last_t_elev_norm_speed          = me.t_LOS_elev_norm_speed;
					#printf("Target acc. perpendicular to LOS (positive up): %.1f G.", me.t_LOS_elev_norm_acc/g_fps);

					me.toBody = math.cos(me.curr_deviation_e*D2R);#convert perpendicular LOS acc. to perpendicular body acc.
					if (me.toBody==0) me.toBody=0.00001;

					me.acc_upwards_fps2 = me.pro_constant*me.line_of_sight_rate_up_rps*me.vert_closing_rate_fps/me.toBody+me.apn*me.t_LOS_elev_norm_acc;
					#printf("vert acc = %.2f + %.2f G", me.pro_constant*me.line_of_sight_rate_up_rps*me.vert_closing_rate_fps/g_fps, (me.apn*me.pro_constant*me.t_LOS_elev_norm_acc/2)/g_fps);
					me.velocity_vector_length_fps = me.clamp(me.old_speed_fps, 0.0001, 1000000);
					me.commanded_upwards_vector_length_fps = me.acc_upwards_fps2*me.dt;

					#me.raw_steer_signal_elev = math.asin(me.clamp((me.commanded_upwards_vector_length_fps*0.5)/me.velocity_vector_length_fps,-1,1))*R2D*2;
					me.raw_steer_signal_elev = math.atan2(me.commanded_upwards_vector_length_fps, me.velocity_vector_length_fps)*R2D;

					# now compensate for the predicted gravity drop of attitude:
		            me.attitudePN = math.atan2(-(me.speed_down_fps+g_fps * me.dt), me.speed_horizontal_fps ) * R2D;
		            me.gravComp = me.pitch - me.attitudePN;
		            #printf("Gravity compensation %0.2f degs", me.gravComp);
		            me.raw_steer_signal_elev += me.gravComp;

					#printf("Proportional lead: %0.1f deg elev", -(me.curr_deviation_e-me.raw_steer_signal_elev));
				}
			}
		}
	},

	scalarProj: func (head, pitch, magn, projHead, projPitch) {#GCD
		head      = head*D2R;
		pitch     = pitch*D2R;
		projHead  = projHead*D2R;
		projPitch = projPitch*D2R;

		# Convert the 2 polar vectors to cartesian:

		# velocity vector of target
		me.ax = magn * math.cos(pitch) * math.cos(-head);#north
		me.ay = magn * math.cos(pitch) * math.sin(-head);#west
		me.az = magn * math.sin(pitch);                  #up

		# vector pointing from target perpendicular to LOS
		me.bx = 1 * math.cos(projPitch) * math.cos(-projHead);# north
		me.by = 1 * math.cos(projPitch) * math.sin(-projHead);# west
		me.bz = 1 * math.sin(projPitch);                      # up

		# the dot product is the scalar projection. And represent the target velocity perpendicular to LOS
		me.result = (me.ax * me.bx + me.ay * me.by + me.az * me.bz)/1;
		return me.result;
	},

	map: func (value, leftMin, leftMax, rightMin, rightMax) {
	    # Figure out how 'wide' each range is
	    var leftSpan = leftMax - leftMin;
	    var rightSpan = rightMax - rightMin;

	    # Convert the left range into a 0-1 range (float)
	    var valueScaled = (value - leftMin) / leftSpan;

	    # Convert the 0-1 range into a value in the right range.
	    return rightMin + (valueScaled * rightSpan);
	},

	proximity_detection: func {

		####Ground interaction
        me.ground = geo.elevation(me.coord.lat(), me.coord.lon());
        if(me.ground != nil)
        {
            if(me.ground > me.coord.alt()) {
            	me.event = "exploded";
            	if(me.life_time < me.arming_time) {
                	me.event = "landed disarmed";
            	}
            	if ((me.Tgt != nil and me.direct_dist_m != nil) or me.Tgt == nil) {
            		me.explode("Hit terrain.", me.event);
            		return TRUE;
            	}
            }
        }

		if (me.Tgt != nil) {
			# Get current direct distance.
			me.cur_dir_dist_m = me.coord.direct_distance_to(me.t_coord);
			if (me.useHitInterpolation == TRUE) { # use Nikolai V. Chr. interpolation
				if ( me.direct_dist_m != nil and me.life_time > me.arming_time) {
					#print("distance to target_m = "~cur_dir_dist_m~" prev_distance to target_m = "~me.direct_dist_m);
					if ( me.cur_dir_dist_m > me.direct_dist_m and me.cur_dir_dist_m < 250) {
						#print("passed target");
						# Distance to target increase, trigger explosion.
						me.explode("Passed target.");
						return TRUE;
					}
					if (me.life_time > me.selfdestruct_time or (me.destruct_when_free == TRUE and me.free == TRUE)) {
						me.explode("Selfdestructed.");
					    return TRUE;
					}
				}
			} else { # use Fabien Barbier trigonometry
				var BC = me.cur_dir_dist_m;
		        var AC = me.direct_dist_m;
		        if(me.last_coord != nil)
		        {
		            var AB = me.last_coord.direct_distance_to(me.coord);
			        #
			        #  A_______C'______ B
			        #   \      |      /     We have a system  :   x²   = CB² - C'B²
			        #    \     |     /                            C'B  = AB  - AC'
			        #     \    |x   /                             AC'² = A'C² + x²
			        #      \   |   /
			        #       \  |  /        Then, if I made no mistake : x² = BC² - ((BC²-AC²+AB²)/(2AB))²
			        #        \ | /
			        #         \|/
			        #          C
			        # C is the target. A is the last missile positioin and B tha actual.
			        # For very high speed (more than 1000 m /seconds) we need to know if,
			        # between the position A and the position B, the distance x to the
			        # target is enough short to proxiimity detection.

			        # get current direct distance.
			        if(me.direct_dist_m != nil)
			        {
			            var x2 = BC * BC - (((BC * BC - AC * AC + AB * AB) / (2 * AB)) * ((BC * BC - AC * AC + AB * AB) / (2 * AB)));
			            if(BC * BC - x2 < AB * AB)
			            {
			                # this is to check if AC' < AB
			                if(x2 > 0)
			                {
			                    me.cur_dir_dist_m = math.sqrt(x2);
			                }
			            }

			            if(me.tpsApproch == 0)
			            {
			                me.tpsApproch = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
			            }
			            else
			            {
			                me.vApproch = (me.direct_dist_m-me.cur_dir_dist_m) / (props.globals.getNode("/sim/time/elapsed-sec", 1).getValue() - me.tpsApproch);
			                me.tpsApproch = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
			            }

			            if(me.usedChance == FALSE and me.cur_dir_dist_m > me.direct_dist_m and me.direct_dist_m < me.reportDist * 2 and me.life_time > me.arming_time)
			            {
			                if(me.direct_dist_m < me.reportDist)
			                {
			                    # distance to target increase, trigger explosion.
			                    me.explodeTrig("In range.");
			                    return TRUE;
			                } else {
		                        # you don't have a second chance. Missile missed
		                        me.free = 1;
		                        me.usedChance = TRUE;
		                        return FALSE;
			                }
			            }
			            if (me.life_time > me.selfdestruct_time or (me.destruct_when_free == TRUE and me.free == TRUE)) {
							me.explode("Selfdestructed.");
						    return TRUE;
						}
			        }
				}
			}
			me.direct_dist_m = me.cur_dir_dist_m;
		}
		return FALSE;
	},

	explode: func (reason, event = "exploded") {

		me.SwSoundFireOnOff.setBoolValue(FALSE);

		if (me.lock_on_sun == TRUE) {
			reason = "Locked onto sun.";
		} elsif (me.flareLock == TRUE) {
			reason = "Locked onto flare.";
		} elsif (me.chaffLock == TRUE) {
			reason = "Locked onto chaff.";
		}

		var explosion_coord = me.last_coord;
		if (me.Tgt != nil) {
			var min_distance = me.direct_dist_m;

			for (var i = 0.00; i <= 1; i += 0.025) {
				var t_coord = me.interpolate(me.last_t_coord, me.t_coord, i);
				var coord = me.interpolate(me.last_coord, me.coord, i);
				var dist = coord.direct_distance_to(t_coord);
				if (dist < min_distance) {
					min_distance = dist;
					explosion_coord = coord;
				}
			}
			if (me.before_last_coord != nil and me.before_last_t_coord != nil) {
				for (var i = 0.00; i <= 1; i += 0.025) {
					var t_coord = me.interpolate(me.before_last_t_coord, me.last_t_coord, i);
					var coord = me.interpolate(me.before_last_coord, me.last_coord, i);
					var dist = coord.direct_distance_to(t_coord);
					if (dist < min_distance) {
						min_distance = dist;
						explosion_coord = coord;
					}
				}
			}
		}
		me.coord = explosion_coord;

		var wh_mass = event == "exploded"?me.weight_whead_lbm:0;#will report 0 mass if did not have time to arm
		impact_report(me.coord, wh_mass, "munition", me.type, me.new_speed_fps*FT2M);

		if (me.Tgt != nil) {
			var phrase = sprintf( me.type~" "~event~": %01.1f", min_distance) ~ " meters from: " ~ (me.flareLock == FALSE?(me.chaffLock == FALSE?me.callsign:(me.callsign ~ "'s chaff")):me.callsign ~ "'s flare");
			print(phrase~"  Reason: "~reason~sprintf(" time %.1f", me.life_time));
			if (min_distance < me.reportDist) {
				me.sendMessage(phrase);
			} else {
				me.sendMessage(me.type~" missed "~me.callsign~": "~reason);
			}
		}

		me.ai.getNode("valid", 1).setBoolValue(0);
		if (event == "exploded") {
			me.animate_explosion();
			me.explodeSound = TRUE;
		} else {
			me.animate_dud();
			me.explodeSound = FALSE;
		}
		me.Tgt = nil;
	},

	explodeTrig: func (reason, event = "exploded") {
		# get missile relative position to the target at last frame.
        var t_bearing_deg = me.last_t_coord.course_to(me.last_coord);
        var t_delta_alt_m = me.last_coord.alt() - me.last_t_coord.alt();
        var new_t_alt_m = me.t_coord.alt() + t_delta_alt_m;
        var t_dist_m  = math.sqrt(math.abs((me.direct_dist_m * me.direct_dist_m)-(t_delta_alt_m * t_delta_alt_m)));
        # create impact coords from this previous relative position
        # applied to target current coord.
        me.t_coord.apply_course_distance(t_bearing_deg, t_dist_m);
        me.t_coord.set_alt(new_t_alt_m);
        var wh_mass = event == "exploded"?me.weight_whead_lbm:0;#will report 0 mass if did not have time to arm
        impact_report(me.t_coord, wh_mass, "munition", me.type, me.new_speed_fps*FT2M);

		if (me.lock_on_sun == TRUE) {
			reason = "Locked onto sun.";
		} elsif (me.flareLock == TRUE) {
			reason = "Locked onto flare.";
		} elsif (me.chaffLock == TRUE) {
			reason = "Locked onto chaff.";
		}

		if (me.Tgt != nil) {
			var phrase = sprintf( me.type~" "~event~": %01.1f", me.direct_dist_m) ~ " meters from: " ~ (me.flareLock == FALSE?(me.chaffLock == FALSE?me.callsign:(me.callsign ~ "'s chaff")):me.callsign ~ "'s flare");
			print(phrase~"  Reason: "~reason~sprintf(" time %.1f", me.life_time));
			me.sendMessage(phrase);
		}

		me.ai.getNode("valid", 1).setBoolValue(0);
		if (event == "exploded") {
			me.animate_explosion();
			me.explodeSound = TRUE;
		} else {
			me.animate_dud();
			me.explodeSound = FALSE;
		}
		me.Tgt = nil;
	},

	sendMessage: func (str) {#GCD
		if (getprop("payload/armament/msg")) {
			defeatSpamFilter(str);
		} else {
			setprop("/sim/messages/atc", str);
		}
	},

	interpolate: func (start, end, fraction) {#GCD
		me.xx = (start.x()*(1-fraction)+end.x()*fraction);
		me.yy = (start.y()*(1-fraction)+end.y()*fraction);
		me.zz = (start.z()*(1-fraction)+end.z()*fraction);

		me.cc = geo.Coord.new();
		me.cc.set_xyz(me.xx,me.yy,me.zz);

		return me.cc;
	},

	getPitch: func (coord1, coord2) {#GCD
		#pitch from coord1 to coord2 in degrees (takes curvature of earth into effect.)
		return vector.Math.getPitch(coord1, coord2);
	},

	getPitch2: func (coord1, coord2) {#GCD
		#pitch from coord1 to coord2 in degrees (assumes earth is flat)
		me.flat_dist = coord1.distance_to(coord2);
		me.flat_alt  = coord2.alt()-coord1.alt();
		return math.atan2(me.flat_alt, me.flat_dist)*R2D;
	},

	# aircraft searching for lock
	search: func {#GCD
		if ( me.status == MISSILE_FLYING ) {
			me.SwSoundVol.setDoubleValue(0);
			me.SwSoundOnOff.setBoolValue(FALSE);
			return;
		} elsif ( me.status == MISSILE_STANDBY ) {
			# Stand by.
			me.SwSoundVol.setDoubleValue(0);
			me.SwSoundOnOff.setBoolValue(FALSE);
			me.trackWeak = 1;
			return;
		} elsif ( me.status > MISSILE_SEARCH) {
			# Locked or fired.
			return;
		} elsif (me.deleted == TRUE) {
			return;
		}
		#print("search");
		# search.
		if (1==1 or contact != me.Tgt) {
#			if (contact != nil and contact.isValid() == TRUE)
#              print("search2: tty=", contact.get_type(), " gnd=", me.target_gnd, " g=", me.guidance, " r=",contact.get_range());
			if (contact != nil and contact.isValid() == TRUE and
				(  (contact.get_type() == SURFACE and me.target_gnd == TRUE)
                or (contact.get_type() == AIR and me.target_air == TRUE)
                or (contact.get_type() == MARINE and me.target_sea == TRUE))) {
#				print("search3");
				me.tagt = contact; # In the radar range and horizontal field.
				me.rng = me.tagt.get_range();
				me.total_elev  = deviation_normdeg(OurPitch.getValue(), me.tagt.getElevation()); # deg.
				me.total_horiz = deviation_normdeg(OurHdg.getValue(), me.tagt.get_bearing());    # deg.
				# Check if in range and in the seeker FOV.
				if ( (me.class!="A" or contact.get_Speed()>15)
                     and ((me.guidance != "semi-radar" and me.guidance != "laser") or me.is_painted(me.tagt) == TRUE)
 				     and me.rng < me.max_fire_range_nm and me.rng > me.min_fire_range_nm and me.FOV_check(me.total_horiz, me.total_elev, me.fcs_fov) ) {
					#print("search4");
					me.status = MISSILE_LOCK;
					me.SwSoundOnOff.setBoolValue(TRUE);
					me.SwSoundVol.setDoubleValue(me.vol_track_weak);
					me.trackWeak = 1;
					me.Tgt = me.tagt;

			        me.callsign = me.Tgt.get_Callsign();

					me.time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();
					me.update_track_time = me.time;

					settimer(func me.update_lock(), 0.1);
					return;
				} else {
					me.Tgt = nil;
				}
			} else {
				me.Tgt = nil;
			}
		}
		me.SwSoundVol.setDoubleValue(me.vol_search);
		me.SwSoundOnOff.setBoolValue(TRUE);
		me.trackWeak = 1;
		settimer(func me.search(), 0.1);
	},

	update_lock: func() {#GCD
		#
		# Missile locked on target
		#
		if ( me.Tgt == nil or me.status == MISSILE_FLYING) {
			return TRUE;
		}
		if (me.status == MISSILE_SEARCH) {
			# Status = searching.
			#print("search commanded");
			me.return_to_search();
			return TRUE;
		} elsif ( me.status == MISSILE_STANDBY ) {
			# Status = stand-by.
			me.reset_seeker();
			me.SwSoundOnOff.setBoolValue(FALSE);
			me.SwSoundVol.setDoubleValue(0);
			me.trackWeak = 1;
			return TRUE;
		} elsif (!me.Tgt.isValid()) {
			# Lost of lock due to target disapearing:
			# return to search mode.
			#print("invalid");
			me.return_to_search();
			return TRUE;
		} elsif (me.deleted == TRUE) {
			return;
		}
		#print("lock");
		# Time interval since lock time or last track loop.
		if (me.status == MISSILE_LOCK) {
			# Status = locked. Get target position relative to our aircraft.
			me.curr_deviation_e = - deviation_normdeg(OurPitch.getValue(), me.Tgt.getElevation());
			me.curr_deviation_h = - deviation_normdeg(OurHdg.getValue(), me.Tgt.get_bearing());
		}

		me.time = props.globals.getNode("/sim/time/elapsed-sec", 1).getValue();

		# Compute HUD reticle position.
		if ( use_fg_default_hud == TRUE and me.status == MISSILE_LOCK ) {
			var h_rad = (90 - me.curr_deviation_h) * D2R;
			var e_rad = (90 - me.curr_deviation_e) * D2R;
			var devs = develev_to_devroll(h_rad, e_rad);
			var combined_dev_deg = devs[0];
			var combined_dev_length =  devs[1];
			var clamped = devs[2];
			if ( clamped ) { SW_reticle_Blinker.blink();}
			else { SW_reticle_Blinker.cont();}
			HudReticleDeg.setDoubleValue(combined_dev_deg);
			HudReticleDev.setDoubleValue(combined_dev_length);
		}
		if (me.status != MISSILE_STANDBY ) {
			me.in_view = me.check_t_in_fov();
			if (me.in_view == FALSE) {
				#print("out of view");
				me.return_to_search();
				return TRUE;
			}
			# We are not launched yet: update_track() loops by itself at 10 Hz.
			me.dist = geo.aircraft_position().direct_distance_to(me.Tgt.get_Coord());
			if (me.time - me.update_track_time > 1) {
				# after 1 second we get solid track.
				me.SwSoundOnOff.setBoolValue(TRUE);
				me.SwSoundVol.setDoubleValue(me.vol_track);
				me.trackWeak = 0;
			} else {
				me.SwSoundOnOff.setBoolValue(TRUE);
				me.SwSoundVol.setDoubleValue(me.vol_track_weak);
				me.trackWeak = 1;
			}
			if (contact == nil or (contact.getUnique() != nil and me.Tgt.getUnique() != nil and contact.getUnique() != me.Tgt.getUnique())) {
				#print("oops ");
				me.return_to_search();
				return TRUE;
			}
			settimer(func me.update_lock(), 0.1);
		}
		return TRUE;
	},

	return_to_search: func {#GCD
		me.status = MISSILE_SEARCH;
		me.Tgt = nil;
		me.SwSoundOnOff.setBoolValue(TRUE);
		me.SwSoundVol.setDoubleValue(me.vol_search);
		me.trackWeak = 1;
		me.reset_seeker();
		settimer(func me.search(), 0.1);
	},

	FOV_check: func (deviation_hori, deviation_elev, fov_radius) {
		me.fov_radial = math.sqrt(math.pow(deviation_hori,2)+math.pow(deviation_elev,2));
		if (me.fov_radial <= fov_radius) {
			return TRUE;
		}
		# out of FOV
		return FALSE;
	},

	check_t_in_fov: func {#GCD
		me.total_elev  = deviation_normdeg(OurPitch.getValue(), me.Tgt.getElevation()); # deg.
		me.total_horiz = deviation_normdeg(OurHdg.getValue(), me.Tgt.get_bearing());    # deg.
		# Check if in range and in the seeker FOV.
		if (me.FOV_check(me.total_horiz, me.total_elev, me.fcs_fov) and me.Tgt.get_range() < me.max_fire_range_nm and me.Tgt.get_range() > me.min_fire_range_nm) {
			return TRUE;
		}
		# Target out of FOV or range while still not launched, return to search loop.
		return FALSE;
	},

	is_painted: func (target) {#GCD
		if(target != nil and target.isPainted() != nil and target.isPainted() == TRUE) {
			return TRUE;
		}
		return FALSE;
	},

	reset_seeker: func {#GCD
		settimer(func { HudReticleDeg.setDoubleValue(0) }, 2);
		interpolate(HudReticleDev, 0, 2);
	},

	clamp_min_max: func (v, mm) {
		if ( v < -mm ) {
			v = -mm;
		} elsif ( v > mm ) {
			v = mm;
		}
		return(v);
	},

	clamp: func(v, min, max) { v < min ? min : v > max ? max : v },

	animation_flags_props: func {
		# Create animation flags properties.
		var path_base = "payload/armament/"~me.type_lc~"/flags/";

		var msl_path = path_base~"msl-id-" ~ me.ID;
		me.msl_prop = props.globals.initNode( msl_path, TRUE, "BOOL", TRUE);
		me.msl_prop.setBoolValue(TRUE);# this is cause it might already exist, and so need to force value

		var smoke_path = path_base~"smoke-id-" ~ me.ID;
		me.smoke_prop = props.globals.initNode( smoke_path, FALSE, "BOOL", TRUE);

		var explode_path = path_base~"explode-id-" ~ me.ID;
		me.explode_prop = props.globals.initNode( explode_path, FALSE, "BOOL", TRUE);

		var explode_smoke_path = path_base~"explode-smoke-id-" ~ me.ID;
		me.explode_smoke_prop = props.globals.initNode( explode_smoke_path, FALSE, "BOOL", TRUE);

		var deploy_id_path = path_base~"deploy-id-" ~ me.ID;
		me.deploy_id_prop = props.globals.initNode( deploy_id_path, FALSE, "BOOL", TRUE);

		var explode_sound_path = "payload/armament/flags/explode-sound-on-" ~ me.ID;;
		me.explode_sound_prop = props.globals.initNode( explode_sound_path, FALSE, "BOOL", TRUE);

		var explode_sound_vol_path = "payload/armament/flags/explode-sound-vol-" ~ me.ID;;
		me.explode_sound_vol_prop = props.globals.initNode( explode_sound_vol_path, 0, "DOUBLE", TRUE);
	},

	animate_explosion: func {#GCD
		#
		# a last position update to where the explosion happened:
		#
		me.latN.setDoubleValue(me.coord.lat());
		me.lonN.setDoubleValue(me.coord.lon());
		me.altN.setDoubleValue(me.coord.alt()*M2FT);
		me.pitchN.setDoubleValue(0);# this will make explosions from cluster bombs (like M90) align to ground 'sorta'.
		me.msl_prop.setBoolValue(FALSE);
		me.smoke_prop.setBoolValue(FALSE);
		me.explode_prop.setBoolValue(TRUE);
		settimer( func me.explode_prop.setBoolValue(FALSE), 0.5 );
		settimer( func me.explode_smoke_prop.setBoolValue(TRUE), 0.5 );
		settimer( func me.explode_smoke_prop.setBoolValue(FALSE), 3 );
	},

	animate_dud: func {#GCD
		#
		# a last position update to where the impact happened:
		#
		me.latN.setDoubleValue(me.coord.lat());
		me.lonN.setDoubleValue(me.coord.lon());
		me.altN.setDoubleValue(me.coord.alt()*M2FT);
		#me.pitchN.setDoubleValue(0); uncomment this to let it lie flat on ground, instead of sticking its nose in it.
		me.smoke_prop.setBoolValue(FALSE);
	},

	sndPropagate: func {
		var dt = deltaSec.getValue();
		if (dt == 0) {
			#FG is likely paused
			settimer(func me.sndPropagate(), 0.01);
			return;
		}
		#dt = update_loop_time;
		var elapsed = systime();
		if (me.elapsed_last != 0) {
			dt = (elapsed - me.elapsed_last) * speedUp.getValue();
		}
		me.elapsed_last = elapsed;

		me.ac = geo.aircraft_position();
		var distance = me.coord.direct_distance_to(me.ac);

		me.sndDistance = me.sndDistance + (me.sndSpeed * dt) * FT2M;
		if(me.sndDistance > distance) {
			var volume = math.pow(2.71828,(-.00025*(distance-1000)));
			#print("explosion heard "~distance~"m vol:"~volume);
			me.explode_sound_vol_prop.setDoubleValue(volume);
			me.explode_sound_prop.setBoolValue(1);
			settimer( func me.explode_sound_prop.setBoolValue(0), 3);
			settimer( func me.del(), 4);
			return;
		} elsif (me.sndDistance > 5000) {
			settimer(func { me.del(); }, 4 );
		} else {
			settimer(func me.sndPropagate(), 0.05);
			return;
		}
	},

	steering_speed_G: func(steering_e_deg, steering_h_deg, s_fps, dt) {#GCD
		# Get G number from steering (e, h) in deg, speed in ft/s.
		me.steer_deg = math.sqrt((steering_e_deg*steering_e_deg) + (steering_h_deg*steering_h_deg));

		# next speed vector
		me.vector_next_x = math.cos(me.steer_deg*D2R)*s_fps;
		me.vector_next_y = math.sin(me.steer_deg*D2R)*s_fps;

		# present speed vector
		me.vector_now_x = s_fps;
		me.vector_now_y = 0;

		# subtract the vectors from each other
		me.dv = math.sqrt((me.vector_now_x - me.vector_next_x)*(me.vector_now_x - me.vector_next_x)+(me.vector_now_y - me.vector_next_y)*(me.vector_now_y - me.vector_next_y));

		# calculate g-force
		# dv/dt=a
		me.g = (me.dv/dt) / g_fps;

		return me.g;
	},

    max_G_Rotation: func(steering_e_deg, steering_h_deg, s_fps, dt, gMax) {#GCD
		me.guess = 1;
		me.coef = 1;
		me.lastgoodguess = 1;

		for(var i=1;i<25;i+=1){
			me.coef = me.coef/2;
			me.new_g = me.steering_speed_G(steering_e_deg*me.guess, steering_h_deg*me.guess, s_fps, dt);
			if (me.new_g < gMax) {
				me.lastgoodguess = me.guess;
				me.guess = me.guess + me.coef;
			} else {
				me.guess = me.guess - me.coef;
			}
		}
		return me.lastgoodguess;
	},

	nextGeoloc: func(lat, lon, heading, speed, dt, alt=100) {
	    # lng & lat & heading, in degree, speed in fps
	    # this function should send back the futures lng lat
	    me.distanceN = speed * dt * FT2M; # should be a distance in meters
	    #print("distance ", distance);
	    # much simpler than trigo
	    me.NextGeo = geo.Coord.new().set_latlon(lat, lon, alt);
	    me.NextGeo.apply_course_distance(heading, me.distanceN);
	    return me.NextGeo;
	},

	rho_sndspeed: func(altitude) {
		# Calculate density of air: rho
		# at altitude (ft), using standard atmosphere,
		# standard temperature T and pressure p.

		me.T = 0;
		me.p = 0;
		if (altitude < 36152) {
			# curve fits for the troposphere
			me.T = 59 - 0.00356 * altitude;
			me.p = 2116 * math.pow( ((me.T + 459.7) / 518.6) , 5.256);
		} elsif ( 36152 < altitude and altitude < 82345 ) {
			# lower stratosphere
			me.T = -70;
			me.p = 473.1 * math.pow( const_e , 1.73 - (0.000048 * altitude) );
		} else {
			# upper stratosphere
			me.T = -205.05 + (0.00164 * altitude);
			me.p = 51.97 * math.pow( ((me.T + 459.7) / 389.98) , -11.388);
		}

		me.rho = me.p / (1718 * (me.T + 459.7));

		# calculate the speed of sound at altitude
		# a = sqrt ( g * R * (T + 459.7))
		# where:
		# snd_speed in feet/s,
		# g = specific heat ratio, which is usually equal to 1.4
		# R = specific gas constant, which equals 1716 ft-lb/slug/R

		me.snd_speed = math.sqrt( 1.4 * 1716 * (me.T + 459.7));
		return [me.rho, me.snd_speed];

	},

	getCCIPadv: func (maxFallTime_sec, timeStep, type) {
		# for non flat areas. Lower falltime or higher timestep means using less CPU time.
		# returns nil for higher than maxFallTime_sec. Else a vector with [Coord, hasTimeToArm].
        me.ccip_altC = getprop("position/altitude-ft")*FT2M;
        me.ccip_dens = getprop("fdm/jsbsim/atmosphere/density-altitude");
        me.ccip_speed_down_fps = getprop("velocities/speed-down-fps");
        me.ccip_speed_east_fps = getprop("velocities/speed-east-fps");
        me.ccip_speed_north_fps = getprop("velocities/speed-north-fps");

        # Fix crap
		if (type == "AIM-9L")
            type = "aim-9";
        elsif (type == "AIM-9X")
            type = "aim-9x";
        elsif (type == "AIM-9M")
            type = "aim-9m";
        else if (type == "AIM-7M")
            type = "aim-7";
        else if (type == "MK-82")
            type = "mk-82";
        else if (type == "MK-83")
            type = "mk-83";
        else if (type == "MK-84")
            type = "mk-84";
        else if (type == "CBU-105")
            type = "cbu-105";
        else if (type == "B61-12")
            type = "b61-12";
        else if (type == "3 X CBU-87")
            type = "cbu-87";
		else if (type == "2 X AIM-9X")
	        type = "aim-9x";
        else if (type == "3 X MK-83")
            type = "mk-83";
        else if (type == "LAU-68C")
            type = "lau-68";
        else if (type == "AIM-120C")
            type = "aim-120c";
        else if (type == "AIM-120D")
            type = "aim-120d";
        me.eject_speed = getprop("payload/armament/"~type~"/ejector-speed-fps");
        me.rail = getprop("payload/armament/"~type~"/rail");
        me.weight_launch_lbm = getprop("payload/armament/"~type~"/weight-launch-lbs");
        me.drop_time = getprop("payload/armament/"~type~"/drop-time");
        me.deploy_time = getprop("payload/armament/"~type~"/deploy-time");
        me.Cd_base = getprop("payload/armament/"~type~"/drag-coeff");
        me.Cd_delta = getprop("payload/armament/"~type~"/delta-drag-coeff-deploy");
        me.simple_drag = getprop("payload/armament/"~type~"/simplified-induced-drag");
        me.simple_drag = getprop("payload/armament/"~type~"/simplified-induced-drag");
        me.ref_area_sqft = getprop("payload/armament/"~type~"/cross-section-sqft");
        me.arming_time = getprop("payload/armament/"~type~"/arming-time-sec");

        if (me.Cd_delta == nil) {
            me.Cd_delta = 0;
        }
        if (me.simple_drag == nil) {
            me.simple_drag = 1;
        }

        me.myMath = {parents:[vector.Math],};#personal vector library, to avoid using a mutex on it.

		if (me.eject_speed != 0 and !me.rail) {
			# add ejector speed down from belly:
			me.aircraft_vec = [me.ccip_speed_north_fps,-me.ccip_speed_east_fps,-me.ccip_speed_down_fps];
			me.eject_vec    = me.myMath.normalize(me.myMath.eulerToCartesian3Z(-OurHdg.getValue(),OurPitch.getValue(),OurRoll.getValue()));
			me.eject_vec    = me.myMath.product(-me.eject_speed, me.eject_vec);
			me.init_rel_vec = me.myMath.plus(me.aircraft_vec, me.eject_vec);
			me.ccip_speed_down_fps = -me.init_rel_vec[2];
			me.ccip_speed_east_fps = -me.init_rel_vec[1];
			me.ccip_speed_north_fps = me.init_rel_vec[0];
		}

        me.ccip_t = 0.0;
        me.ccip_dt = timeStep;
        me.ccip_fps_z = -me.ccip_speed_down_fps;
        me.ccip_fps_x = math.sqrt(me.ccip_speed_east_fps*me.ccip_speed_east_fps+me.ccip_speed_north_fps*me.ccip_speed_north_fps);
        me.ccip_bomb = me;

        me.ccip_rs = me.ccip_bomb.rho_sndspeed(getprop("sim/flight-model") == "jsb"?me.ccip_dens:me.ccip_altC*M2FT);
        me.ccip_rho = me.ccip_rs[0];
        me.ccip_mass = me.ccip_bomb.weight_launch_lbm * LBM2SLUGS;

        me.ccipPos = geo.Coord.new(geo.aircraft_position());

        # we calc heading from composite speeds, due to alpha and beta might influence direction bombs will fall:
        if(me.ccip_fps_x == 0) return nil;
        me.ccip_heading = geo.normdeg(math.atan2(me.ccip_speed_east_fps,me.ccip_speed_north_fps)*R2D);
        #print();
        #printf("CCIP     %.1f", me.ccip_heading);
		me.ccip_pitch = math.atan2(me.ccip_fps_z, me.ccip_fps_x);
        while (me.ccip_t <= maxFallTime_sec) {
			me.ccip_t += me.ccip_dt;
			me.ccip_bomb.deploy = me.clamp(me.extrapolate(me.ccip_t, me.drop_time, me.drop_time+me.deploy_time,0,1),0,1);
			# Apply drag
			me.ccip_fps = math.sqrt(me.ccip_fps_x*me.ccip_fps_x+me.ccip_fps_z*me.ccip_fps_z);
			if (me.ccip_fps==0) return nil;
			me.ccip_q = 0.5 * me.ccip_rho * me.ccip_fps * me.ccip_fps;
			me.ccip_mach = me.ccip_fps / me.ccip_rs[1];
			me.ccip_Cd = me.ccip_bomb.drag(me.ccip_mach);
			me.ccip_deacc = (me.ccip_Cd * me.ccip_q * me.ccip_bomb.ref_area_sqft) / me.ccip_mass;
			me.ccip_fps -= me.ccip_deacc*me.ccip_dt;

			# new components and pitch
			me.ccip_fps_z = me.ccip_fps*math.sin(me.ccip_pitch);
			me.ccip_fps_x = me.ccip_fps*math.cos(me.ccip_pitch);
			me.ccip_fps_z -= g_fps * me.ccip_dt;
			me.ccip_pitch = math.atan2(me.ccip_fps_z, me.ccip_fps_x);

			# new position
			me.ccip_altC = me.ccip_altC + me.ccip_fps_z*me.ccip_dt*FT2M;
			me.ccip_dist = me.ccip_fps_x*me.ccip_dt*FT2M;
			me.ccip_oldPos = geo.Coord.new(me.ccipPos);
			me.ccipPos.apply_course_distance(me.ccip_heading, me.ccip_dist);
			me.ccipPos.set_alt(me.ccip_altC);

			low_or_not = (((me.ccip_dist / FT2M) / me.ccip_fps) < me.arming_time);

			# test terrain
			me.ccip_grnd = geo.elevation(me.ccipPos.lat(),me.ccipPos.lon());
			if (me.ccip_grnd != nil) {
				if (1 == 1) {#me.ccip_grnd < me.ccip_altC) {
					#return [me.ccipPos,me.arming_time<me.ccip_t];
					me.result = me.getTerrain(me.ccip_oldPos, me.ccipPos);
					if (me.result != nil) {
						return [me.result, low_or_not, me.ccip_t];
					}
					return [me.ccipPos, low_or_not, me.ccip_t];
					#var inter = me.extrapolate(me.ccip_grnd,me.ccip_altC,me.ccip_oldPos.alt(),0,1);
					#return [me.interpolate(me.ccipPos,me.ccip_oldPos,inter),me.arming_time<me.ccip_t];
				}
			} else {
				return nil;
			}
        }
        return nil;
	},

	getTerrain: func (from, to) {
		me.xyz = {"x":from.x(),                  "y":from.y(),                 "z":from.z()};
        me.dir = {"x":to.x()-from.x(),  "y":to.y()-from.y(), "z":to.z()-from.z()};
        me.v = get_cart_ground_intersection(me.xyz, me.dir);
        if (me.v != nil) {
            me.terrain = geo.Coord.new();
            me.terrain.set_latlon(me.v.lat, me.v.lon, me.v.elevation);
            return me.terrain;
        }
        return nil;
	},

	active: {},
	flying: {},
};


# Create impact report.

#altitde-agl-ft DOUBLE
#impact
#	elevation-m DOUBLE
#	heading-deg DOUBLE
#	latitude-deg DOUBLE
#	longitude-deg DOUBLE
#	pitch-deg DOUBLE
#	roll-deg DOUBLE
#	speed-mps DOUBLE
#	type STRING
# valid "true" BOOL
var impact_report = func(pos, mass, string, name, speed_mps) {
	# Find the next index for "ai/models/model-impact" and create property node.
	var n = props.globals.getNode("ai/models", 1);
	for (var i = 0; 1; i += 1)
		if (n.getChild(string, i, 0) == nil)
			break;
	var impact = n.getChild(string, i, 1);

	impact.getNode("impact/elevation-m", 1).setDoubleValue(pos.alt());
	impact.getNode("impact/latitude-deg", 1).setDoubleValue(pos.lat());
	impact.getNode("impact/longitude-deg", 1).setDoubleValue(pos.lon());
	impact.getNode("warhead-lbm", 1).setDoubleValue(mass);
	impact.getNode("mass-slug", 1).setDoubleValue(mass/slugs_to_lbm);
	impact.getNode("impact/speed-mps", 1).setDoubleValue(speed_mps);
	#impact.getNode("speed-mps", 1).setValue(speed_mps);
	impact.getNode("valid", 1).setBoolValue(1);
	impact.getNode("impact/type", 1).setValue("something");#"terrain"
	impact.getNode("name", 1).setValue(name);

	var impact_str = "/ai/models/" ~ string ~ "[" ~ i ~ "]";
	setprop("ai/models/model-impact", impact_str);
}

# HUD clamped target blinker
SW_reticle_Blinker = aircraft.light.new("payload/armament/hud/hud-sw-reticle-switch", [0.1, 0.1]);
setprop("payload/armament/hud/hud-sw-reticle-switch/enabled", 1);





var eye_hud_m          = 0.6;#pilot: -3.30  hud: -3.9
var hud_radius_m       = 0.100;

#was in hud
var develev_to_devroll = func(dev_rad, elev_rad) {
	var clamped = 0;
	# Deviation length on the HUD (at level flight),
	# 0.6686m = distance eye <-> virtual HUD screen.
	var h_dev = eye_hud_m / ( math.sin(dev_rad) / math.cos(dev_rad) );
	var v_dev = eye_hud_m / ( math.sin(elev_rad) / math.cos(elev_rad) );
	# Angle between HUD center/top <-> HUD center/symbol position.
	# -90° left, 0° up, 90° right, +/- 180° down.
	var dev_deg =  math.atan2( h_dev, v_dev ) * R2D;
	# Correction with own a/c roll.
	var combined_dev_deg = dev_deg - OurRoll.getValue();
	# Lenght HUD center <-> symbol pos on the HUD:
	var combined_dev_length = math.sqrt((h_dev*h_dev)+(v_dev*v_dev));
	# clamp and squeeze the top of the display area so the symbol follow the egg shaped HUD limits.
	var abs_combined_dev_deg = math.abs( combined_dev_deg );
	var clamp = hud_radius_m;
	if ( abs_combined_dev_deg >= 0 and abs_combined_dev_deg < 90 ) {
		var coef = ( 90 - abs_combined_dev_deg ) * 0.00075;
		if ( coef > 0.050 ) { coef = 0.050 }
		clamp -= coef;
	}
	if ( combined_dev_length > clamp ) {
		combined_dev_length = clamp;
		clamped = 1;
	}
	var v = [combined_dev_deg, combined_dev_length, clamped];
	return(v);
}

#was in radar
var deviation_normdeg = func(our_heading, target_bearing) {
	var dev_norm = geo.normdeg180(our_heading - target_bearing);
	return dev_norm;
}

#
# this code make sure messages don't trigger the MP spam filter:

var spams = 0;
var spamList = [];

var defeatSpamFilter = func (str) {
  spams += 1;
  if (spams == 15) {
    spams = 1;
  }
  str = str~":";
  for (var i = 1; i <= spams; i+=1) {
    str = str~".";
  }
  var myCallsign = getprop("sim/multiplay/callsign");
  if (myCallsign != nil and find(myCallsign, str) != -1) {
  	str = myCallsign~": "~str;
  }
  var newList = [str];
  for (var i = 0; i < size(spamList); i += 1) {
    append(newList, spamList[i]);
  }
  spamList = newList;
}

var spamLoop = func {
  var spam = pop(spamList);
  if (spam != nil) {
    setprop("/sim/multiplay/chat", spam);
  }
  settimer(spamLoop, 1.20);
}

spamLoop();
