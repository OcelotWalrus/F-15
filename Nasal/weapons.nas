# F-15 Weapons system
# ---------------------------
# ---------------------------
# Richard Harrison (rjh@zaretto.com) Feb  2015 - based on F-14B version by Alexis Bory
# ---------------------------

var AcModel = props.globals.getNode("sim/model/f15");
var SwCoolOffLight   = AcModel.getNode("controls/armament/acm-panel-lights/sw-cool-off-light");
var MslPrepOffLight  = AcModel.getNode("controls/armament/acm-panel-lights/msl-prep-off-light");
var WeaponSelector    = AcModel.getNode("controls/armament/weapon-selector");
var ArmSwitch        = AcModel.getNode("controls/armament/master-arm-switch");
var GrSwitch         = AcModel.getNode("controls/armament/gun-rate-switch");
var SysRunning       = AcModel.getNode("systems/armament/system-running");
var GunRunning       = AcModel.getNode("systems/gun/running");
var GunCountAi       = props.globals.getNode("ai/submodels/submodel[3]/count");
var GunCount         = AcModel.getNode("systems/gun/rounds");
var GunReady         = AcModel.getNode("systems/gun/ready");
var GunStop          = AcModel.getNode("systems/gun/stop", 1);
var GunRateHighLight = AcModel.getNode("controls/armament/acm-panel-lights/gun-rate-high-light");
var LauRunning       = props.globals.getNode("fdm/jsbsim/fcs/hydra3trigger");
var LauReady         = props.globals.getNode("fdm/jsbsim/fcs/hydra3ready");
var LauStop          = props.globals.getNode("fdm/jsbsim/fcs/hydra3stop", 1);


# AIM-9L stuff:
var SwCount    = AcModel.getNode("systems/armament/aim9/count");
var SWCoolOn   = AcModel.getNode("controls/armament/acm-panel-lights/sw-cool-on-light");
var SWCoolOff  = AcModel.getNode("controls/armament/acm-panel-lights/sw-cool-off-light");
var SwSoundVol = AcModel.getNode("systems/armament/aim9/sound-volume");
var Current_srm   = nil;
var Current_mk84   = nil;
var Current_mrm   = nil;
var Current_missile   = nil;
var sel_missile_count = 0;

aircraft.data.add( WeaponSelector, ArmSwitch );

setlistener("sim/model/f15/controls/armament/weapon-selector", func(v)
{
    aircraft.arm_selector();
    aircraft.demand_weapons_refresh();
});

var getDLZ = func {
    if (ArmSwitch.getValue() and Current_missile != nil) {
        return Current_missile.getDLZ();
    }
}

# Init
var weapons_init = func()
{
	print("Initializing F-15 weapons system");
	ArmSwitch.setValue(0);
	system_stop();
	SysRunning.setBoolValue(0);
	update_gun_ready();
	update_lau_ready();
	setlistener("controls/armament/trigger", func(Trig)
                {
# Check selected weapon type and set the trigger listeners.
                    var weapon_s = WeaponSelector.getValue();
                    print("Trigger ",weapon_s," ",Trig.getBoolValue());
                    if ( weapon_s == 0 ) {
                        update_gun_ready();
                        if ( Trig.getBoolValue())
                        {
                            GunStop.setBoolValue(0);
                            fire_gun();
                        }
                        else
                        {
                            GunStop.setBoolValue(1);
                        }
                    }
                    elsif ( weapon_s == 1 and Trig.getBoolValue())
                    {
                        release_aim9();
                    }
                    elsif ( weapon_s == 2 and Trig.getBoolValue())
                    {
                        release_aim9();
                    }
                    elsif ( weapon_s == 4 and Trig.getBoolValue())
                    {
                        update_lau_ready();
                        if ( Trig.getBoolValue())
                        {
                            setprop("fdm/jsbsim/fcs/hydra3stop", 0);
                            fire_lau();
                        }
                        else
                        {
                            setprop("fdm/jsbsim/fcs/hydra3stop", 1);
                        }
                    }
                    elsif ( weapon_s == 5 and Trig.getBoolValue())
                    {
                        release_bomb();
                    }
                    elsif ( weapon_s == 6 and Trig.getBoolValue())
                    {
                        release_aim9();
                    }
                }, 0, 1);
	setlistener("controls/armament/pickle", func(Trig)
                {
# this should release all locked missles. need to fix the logic to lock on missiles
# so for now this will just work with the currently selected armament, but not the gun.
                    var weapon_s = WeaponSelector.getValue();
                    print("Pickle ",weapon_s," ",Trig.getBoolValue());
                    if ( weapon_s == 0 ) {
                        print("Pickle does not fire the gun");
                    }
                    elsif ( weapon_s == 1 and Trig.getBoolValue())
                    {
                        release_aim9();
                    }
                    elsif ( weapon_s == 2 and Trig.getBoolValue())
                    {
                        release_aim9();
                    } elsif ( weapon_s == 4 ) {
                        print("Pickle does not fire the gun");
                    }
                    elsif ( weapon_s == 5 and Trig.getBoolValue())
                    {
                        release_bomb();
                    }
                }, 0, 1);
}



# Main loop
var armament_update = func {
	# Trigered each 0.1 sec by instruments.nas main_loop() if Master Arm Engaged.

    sel_missile_count = get_sel_missile_count();
	# Turn sidewinder cooling lights On/Off.
	if ( sel_missile_count > 0 ) {
		SWCoolOn.setBoolValue(1);
		SWCoolOff.setBoolValue(0);
		update_sw_ready();
	} else {
		SWCoolOn.setBoolValue(0);
		SWCoolOff.setBoolValue(1);
		# Turn Current_srm.status to stand by.
		#set_status_current_aim9(-1);
	}

    if (Current_missile != nil) {
        setprop("sim/model/f15/systems/armament/selected-arm", getprop("payload/weight["~Current_missile.ID~"]/selected"));
    }
    if (WeaponSelector.getValue() == 0) {
        setprop("sim/model/f15/systems/armament/selected-arm", "M61A1");
    }
    if (WeaponSelector.getValue() == 4) {
        setprop("sim/model/f15/systems/armament/selected-arm", "LAU-68C");
    }

    if (WeaponSelector.getValue() == 5) {
        if (Current_mk84 != nil and Current_mk84.status == 1) {
            setprop("sim/model/f15/systems/armament/launch-light",1);
        } else {
            setprop("sim/model/f15/systems/armament/launch-light",0);
        }
    }
    elsif (WeaponSelector.getValue() == 1) {
        if (Current_srm != nil and Current_srm.status == 1) {
            setprop("sim/model/f15/systems/armament/launch-light",1);
        } else {
            setprop("sim/model/f15/systems/armament/launch-light",0);
        }
    } elsif (WeaponSelector.getValue() == 2) {
        if (Current_mrm != nil and Current_mrm.status == 1) {
            setprop("sim/model/f15/systems/armament/launch-light",1);
        } else {
            setprop("sim/model/f15/systems/armament/launch-light",0);
        }
    } else {
        setprop("sim/model/f15/systems/armament/launch-light",0);
    }
}

var update_lau_ready = func()
 {
    lau_count = getprop("ai/submodels/submodel[7]/count") + getprop("ai/submodels/submodel[8]/count") + getprop("ai/submodels/submodel[9]/count") + getprop("ai/submodels/submodel[10]/count") + getprop("ai/submodels/submodel[11]/count") + getprop("ai/submodels/submodel[12]/count");
	var ready = 0;
	if ( ArmSwitch.getValue() and lau_count > 0 )
 {
		ready = 1;
	}
	setprop("fdm/jsbsim/fcs/hydra3ready", ready);
}

var fire_lau = func {
	var grun   = getprop("fdm/jsbsim/fcs/hydra3trigger");
	var gready = getprop("fdm/jsbsim/fcs/hydra3ready");
	var gstop  = getprop("fdm/jsbsim/fcs/hydra3stop");
	if (gstop or getprop("controls/armament/trigger") == 0) {
		setprop("fdm/jsbsim/fcs/hydra3trigger", 0);
		return;
	}
	if (gready and !grun) {
		setprop("fdm/jsbsim/fcs/hydra3trigger", 1);
		grun = 1;
	}
	if ((gready and grun) or getprop("fdm/jsbsim/fcs/hydra3ready") and getprop("fdm/jsbsim/fcs/hydra3trigger")) {
	    if (getprop("ai/submodels/submodel[7]/count") > 0) {
	        setprop("ai/submodels/submodel[7]/count", getprop("ai/submodels/submodel[7]/count") - 1);
	    } elsif (getprop("ai/submodels/submodel[8]/count") > 0) {
	        setprop("ai/submodels/submodel[8]/count", getprop("ai/submodels/submodel[8]/count") - 1);
	        setprop("ai/submodels/submodel[7]/count", -1);
	    } elsif (getprop("ai/submodels/submodel[9]/count") > 0) {
	        setprop("ai/submodels/submodel[9]/count", getprop("ai/submodels/submodel[9]/count") - 1);
	    } elsif (getprop("ai/submodels/submodel[10]/count") > 0) {
	        setprop("ai/submodels/submodel[10]/count", getprop("ai/submodels/submodel[10]/count") - 1);
	    } elsif (getprop("ai/submodels/submodel[11]/count") > 0) {
	        setprop("ai/submodels/submodel[11]/count", getprop("ai/submodels/submodel[11]/count") - 1);
	    } elsif (getprop("ai/submodels/submodel[12]/count") > 0) {
	        setprop("ai/submodels/submodel[12]/count", getprop("ai/submodels/submodel[12]/count") - 1);
	    }
	    lau_count = getprop("ai/submodels/submodel[7]/count") + getprop("ai/submodels/submodel[8]/count") + getprop("ai/submodels/submodel[9]/count") + getprop("ai/submodels/submodel[10]/count") + getprop("ai/submodels/submodel[11]/count") + getprop("ai/submodels/submodel[12]/count");
	    if (lau_count < 0) {
	        setprop("ai/submodels/submodel[7]/count", 0);
	        setprop("fdm/jsbsim/fcs/hydra3trigger", 0);
			setprop("fdm/jsbsim/fcs/hydra3ready", 0);
			return;
	    }
		settimer(fire_lau, .85);
	}
	armament_update();
}

var update_gun_ready = func()
 {
	var ready = 0;
	if ( ArmSwitch.getValue() and GunCount.getValue() > 0 )
 {
		ready = 1;
	}
	GunReady.setBoolValue(ready);
}

var fire_gun = func {
	var grun   = GunRunning.getValue();
	var gready = GunReady.getBoolValue();
	var gstop  = GunStop.getBoolValue();
	if (gstop) {
		GunRunning.setBoolValue(0);
		return;
	}
	if (gready and !grun) {
		GunRunning.setBoolValue(1);
		grun = 1;
	}
	if (gready and grun) {
		var real_gcount = GunCountAi.getValue();
		var new_gcount = real_gcount*5;
		if (new_gcount < 5 ) {
			new_gcount = 0;
			GunRunning.setBoolValue(0);
			GunReady.setBoolValue(0);
			GunCount.setValue(new_gcount);
			return;
		}
		GunCount.setValue(new_gcount);
		print(new_gcount);
		settimer(fire_gun, 0.1);
	}
	armament_update();
}

var missile_code_from_ident= func(mty)
{
        if (mty == "AIM-9L")
            return "aim9";
        elsif (mty == "AIM-9X")
            return "aim9x";
        elsif (mty == "AIM-9M")
            return "aim9m";
        else if (mty == "AIM-7M")
            return "aim7";
        else if (mty == "MK-82")
            return "mk82";
        else if (mty == "MK-83")
            return "mk83";
        else if (mty == "MK-84")
            return "mk84";
        else if (mty == "CBU-105")
            return "cbu105";
        else if (mty == "B61-12")
            return "b6112";
        else if (mty == "3 X CBU-87")
            return "cbu87";
        else if (mty == "2 X AIM-9X")
            return "aim9x";
        else if (mty == "3 X MK-83")
            return "mk83";
        else if (mty == "LAU-68C")
            return "lau68";
        else if (mty == "AIM-120C")
            return "aim120c";
        else if (mty == "AIM-120D")
            return "aim120d";
}
var get_sel_missile_count = func()
{
        if (WeaponSelector.getValue() == 5)
        {
            Current_missile = Current_mk84;
            return getprop("sim/model/f15/systems/armament/mk83/count") + getprop("sim/model/f15/systems/armament/mk84/count") + getprop("sim/model/f15/systems/armament/cbu105/count") + getprop("sim/model/f15/systems/armament/cbu87/count") + getprop("sim/model/f15/systems/armament/b6112/count");
        }
        else if (WeaponSelector.getValue() == 1)
        {
            Current_missile = Current_srm;
            return getprop("sim/model/f15/systems/armament/aim9/count") + getprop("sim/model/f15/systems/armament/aim9x/count") + getprop("sim/model/f15/systems/armament/aim9m/count");
        }
        else if (WeaponSelector.getValue() == 2)
        {
            Current_missile = Current_mrm;
            return getprop("sim/model/f15/systems/armament/aim7/count")+getprop("sim/model/f15/systems/armament/aim120c/count")+getprop("sim/model/f15/systems/armament/aim120d/count");
        }
        return 0;
}

var update_sw_ready = func()
{
	if (WeaponSelector.getValue() > 0 and ArmSwitch.getValue())
    {
    	sel_missile_count = get_sel_missile_count();
        var pylon = -1;
		if ( (WeaponSelector.getValue() == 1 and (Current_srm == nil or Current_srm.status == 2)  and sel_missile_count > 0 )
             or (WeaponSelector.getValue() == 2 and (Current_mrm == nil or Current_mrm.status == 2)  and sel_missile_count > 0 )
             or (WeaponSelector.getValue() == 5 and (Current_mk84 == nil or Current_mk84.status == 2)  and sel_missile_count > 0 ))
        {
            print("Missile: sel_missile_count = ", sel_missile_count - 1);
            foreach (var S; Station.firing_order)
            {
                printf("AIM %d: %s, %s",S.index, S.get_type(), S.get_selected());
                if (S.get_selected())
                {
                    print("New AIM ",S.index);
                    pylon = S.index;
                    break;
                }
            }
            if (pylon >= 0)
            {
                if (S.get_type() == "AIM-9L" or S.get_type() == "AIM-9X" or S.get_type() == "AIM-9M" or S.get_type() == "AIM-7M" or S.get_type() == "AIM-120C" or S.get_type() == "MK-83" or S.get_type() == "AIM-120D" or S.get_type() == "MK-84" or S.get_type() == "LAU-68C" or S.get_type() == "CBU-105" or S.get_type() == "3 X CBU-87" or S.get_type() == "B61-12" or S.get_type() == "3 X MK-83" or S.get_type() == "2 X AIM-9X")
                {
                    print(S.get_type()," new !! ", pylon, " sel_missile_count - 1 = ", sel_missile_count - 1);
                    if (WeaponSelector.getValue() == 1) {
                        armament.AIM.new(pylon, S.get_type(), S.get_type());
                        Current_srm = armament.AIM.active[pylon];# if there already was a missile at that pylon, new will return -1, so we just get whatever missile is rdy at that pylon.
                    } elsif (WeaponSelector.getValue() == 2) {
                        armament.AIM.new(pylon, S.get_type(), S.get_type());
                        Current_mrm = armament.AIM.active[pylon];
                    } elsif (WeaponSelector.getValue() == 5) {
                        if (S.get_type() != "3 X CBU-87" and S.get_type() != "3 X MK-83" and S.get_type() != "2 X AIM-9X") {
                            armament.AIM.new(pylon, S.get_type(), S.get_type());
                            Current_mk84 = armament.AIM.active[pylon];
                        } else {
                            if (getprop("payload/weight["~pylon~"]/count") < 1) {
                                print("Cannot select weapon: rack is empty");
                            } elsif (S.get_type() != "2 X AIM-9X") {
                                armament.AIM.new(pylon, S.get_type(), S.get_type());
                                Current_mk84 = armament.AIM.active[pylon];
                            } else {
                                armament.AIM.new(pylon, S.get_type(), S.get_type());
                                Current_srm = armament.AIM.active[pylon];
                            }
                        }
                    }
                }
                else
                    print ("Cannot fire ",S.get_type());

            }
#            else
#                print("Error no missile available");
        }
        elsif (Current_missile != nil and Current_missile.status == -1)
        {
            Current_missile.status = 0;
            Current_missile.search();
        }
    }
    elsif (Current_missile != nil)
    {
		Current_missile.status = -1;
		SwSoundVol.setValue(0);
	}
}

var release_aim9 = func()
{
	if (Current_missile != nil) {
        print("RELEASE MISSILE status: ", Current_missile.status);
		if ( Current_missile.status == 1 ) {
			var current_pylon = "payload/weight["~Current_missile.ID~"]/selected";
			var missile_code = missile_code_from_ident(current_pylon);
			var fire_msg = getprop(sprintf("payload/armament/spd%d/fire-msg", missile_code));
			var phrase = sprintf("spd%d at: spd%d", fire_msg, Current_missile.Tgt.Callsign.getValue());
			if (getprop("sim/model/f15/systems/armament/mp-messaging")) {
				armament.defeatSpamFilter(phrase);
			} else {
				setprop("/sim/messages/atc", phrase);
			}
			# Set the pylon empty:
            # or if it's a missile in a rack, remove one
            # of the missiles in it
            var current_pylon = "payload/weight["~Current_missile.ID~"]/selected";
            var current_count = "payload/weight["~Current_missile.ID~"]/count";
            var current_weight = "payload/weight["~Current_missile.ID~"]/weight-lb";
            var missile_id = "";
            if (getprop(current_pylon) == "AIM-9L")
                missile_id = "aim-9";
            elsif (getprop(current_pylon) == "AIM-9X")
                missile_id = "aim-9x";
            elsif (getprop(current_pylon) == "AIM-9M")
                missile_id = "aim-9m";
            else if (getprop(current_pylon) == "AIM-7M")
                missile_id = "aim-7";
            else if (getprop(current_pylon) == "MK-82")
                missile_id = "mk-82";
            else if (getprop(current_pylon) == "MK-83")
                missile_id = "mk-83";
            else if (getprop(current_pylon) == "MK-84")
                missile_id = "mk-84";
            else if (getprop(current_pylon) == "CBU-105")
                missile_id = "cbu-105";
            else if (getprop(current_pylon) == "B61-12")
                missile_id = "b61-12";
            else if (getprop(current_pylon) == "3 X CBU-87")
                missile_id = "cbu-87";
            else if (getprop(current_pylon) == "2 X AIM-9X")
                missile_id = "aim-9x";
            else if (getprop(current_pylon) == "3 X MK-83")
                missile_id = "mk-83";
            else if (getprop(current_pylon) == "LAU-68C")
                missile_id = "lau-68";
            else if (getprop(current_pylon) == "AIM-120C")
                missile_id = "aim-120c";
            else if (getprop(current_pylon) == "AIM-120D")
                missile_id = "aim-120d";
            print("Release ",current_pylon);
            if (getprop(current_pylon) != "2 X AIM-9X") {
        		setprop(current_pylon,"none");
            } else {
                code_id = missile_code_from_ident(getprop(current_pylon));
                setprop("sim/model/f15/systems/armament/"~code_id~"/count",getprop("sim/model/f15/systems/armament/"~code_id~"/count") - 1);
                setprop(current_count, getprop(current_count) - 1);
                setprop(current_weight, getprop(current_count) * getprop("payload/armament/"~missile_id~"/weight-launch-lbs"));
                if (getprop(current_weight) == 0) {
                    setprop(current_pylon,"none"); # remove the rack if no more missiles are loaded
                }
            }
            print("currently ",getprop(current_pylon));
			armament_update();
            setprop("sim/model/f15/systems/armament/launch-light",0);
			Current_missile.release();
            arm_selector();
		}
	}
    else print("No current missile to release");
}

var release_bomb = func()
{
	if (Current_missile != nil) {
	    if (Current_missile == Current_mk84 and getprop("payload/weight["~Current_missile.ID~"]/selected") != "none" and getprop("sim/model/f15/systems/armament/mk83/count") + getprop("sim/model/f15/systems/armament/mk84/count") + getprop("sim/model/f15/systems/armament/cbu105/count") + getprop("sim/model/f15/systems/armament/cbu87/count") + getprop("sim/model/f15/systems/armament/b6112/count") > 0 and getprop("sim/model/f15/systems/armament/selected-arm") != "none" and ArmSwitch.getValue()) {
	        Current_missile.status = 1; # set status manually here for dumb bombs
	    }
	    if ((getprop("payload/weight["~Current_missile.ID~"]/selected") == "3 X CBU-87" or getprop("payload/weight["~Current_missile.ID~"]/selected") == "3 X MK-83") and getprop("payload/weight["~Current_missile.ID~"]/count") < 1) {
	        Current_missile.status = 0; # reset to 0 cuz there's no more ammo in the rack
	    }
        print("RELEASE MISSILE status: ", Current_missile.status);
		# Set the pylon empty
        # or if it's a bomb in a rack, remove one
        # of the bombs in it
		var current_pylon = "payload/weight["~Current_missile.ID~"]/selected";
        var current_count = "payload/weight["~Current_missile.ID~"]/count";
        var current_weight = "payload/weight["~Current_missile.ID~"]/weight-lb";
        var missile_id = "";
        if (getprop(current_pylon) == "AIM-9L")
            missile_id = "aim-9";
        elsif (getprop(current_pylon) == "AIM-9X")
            missile_id = "aim-9x";
        elsif (getprop(current_pylon) == "AIM-9M")
            missile_id = "aim-9m";
        else if (getprop(current_pylon) == "AIM-7M")
            missile_id = "aim-7";
        else if (getprop(current_pylon) == "MK-82")
            missile_id = "mk-82";
        else if (getprop(current_pylon) == "MK-83")
            missile_id = "mk-83";
        else if (getprop(current_pylon) == "MK-84")
            missile_id = "mk-84";
        else if (getprop(current_pylon) == "CBU-105")
            missile_id = "cbu-105";
        else if (getprop(current_pylon) == "B61-12")
            missile_id = "b61-12";
        else if (getprop(current_pylon) == "3 X CBU-87")
            missile_id = "cbu-87";
        else if (getprop(current_pylon) == "2 X AIM-9X")
            missile_id = "aim-9x";
        else if (getprop(current_pylon) == "3 X MK-83")
            missile_id = "mk-83";
        else if (getprop(current_pylon) == "LAU-68C")
            missile_id = "lau-68";
        else if (getprop(current_pylon) == "AIM-120C")
            missile_id = "aim-120c";
        else if (getprop(current_pylon) == "AIM-120D")
            missile_id = "aim-120d";
        print("Release ",current_pylon);
        if (getprop(current_pylon) != "3 X CBU-87" and getprop(current_pylon) != "3 X MK-83") {
    		setprop(current_pylon,"none");
        } else {
            code_id = missile_code_from_ident(getprop(current_pylon));
            setprop("sim/model/f15/systems/armament/"~code_id~"/count",getprop("sim/model/f15/systems/armament/"~code_id~"/count") - 1);
            setprop(current_count, getprop(current_count) - 1);
            setprop(current_weight, getprop(current_count) * getprop("payload/armament/"~missile_id~"/weight-launch-lbs"));
            if (getprop(current_weight) == 0) {
                setprop(current_pylon,"none"); # remove the rack if no more bombs are loaded
            }
        }
        print("currently ",getprop(current_pylon));
		armament_update();
        setprop("sim/model/f15/systems/armament/launch-light",0);
		Current_missile.release();
        arm_selector();
	}
    else print("No current missile to release");
}

var set_status_current_aim9 = func(n)
{
	if (Current_missile != nil) {
		Current_missile.status = n;
	}
}

# System start and stop.
# Timers for weapons system status lights.
var system_start = func
{
    print("Weapons System start");
	settimer (func { GunRateHighLight.setBoolValue(1); }, 0.3);
	update_gun_ready();
	update_lau_ready();
	SysRunning.setBoolValue(1);
	settimer (func { SwCoolOffLight.setBoolValue(1); }, 0.6);
	settimer (func { MslPrepOffLight.setBoolValue(1); }, 2);
	settimer (func {
                  if (Current_missile != nil and WeaponSelector.getValue() and sel_missile_count > 0) {
                      Current_missile.status = 0;
                      Current_missile.search();
                  }
              }, 2.5);
}

var system_stop = func
{
    print("Weapons System stop");
	GunRateHighLight.setBoolValue(0);
	SysRunning.setBoolValue(0);
                setprop("sim/model/f15/systems/armament/launch-light",0);
	foreach (var S; Station.list)
    {
		S.set_display(0); # initialize bcode (showing weapons set over MP).
	}
	if (Current_missile != nil)
    {
		set_status_current_aim9(-1);
	}
	SwSoundVol.setValue(0);
	settimer (func { SwCoolOffLight.setBoolValue(0);SWCoolOn.setBoolValue(0); }, 0.6);
	settimer (func { MslPrepOffLight.setBoolValue(0); }, 1.2);
}


# Controls
setlistener("sim/model/f15/controls/armament/master-arm-switch", func(v)
{
    print("Master arm ",v.getValue());
    var a = v.getValue();
	var master_arm_switch = ArmSwitch.getValue();
	if (master_arm_switch)
    {
        system_start();
		SysRunning.setBoolValue(1);
	}
    else
    {
        system_stop();
		SysRunning.setBoolValue(0);
	}
    demand_weapons_refresh();
});

var master_arm_cycle = func()
{
	var master_arm_switch = ArmSwitch.getValue();
    print("arm_cycle: master_arm_switch",master_arm_switch);
	if (master_arm_switch == 0)
    {
		ArmSwitch.setValue(1);
	}
    else
    {
		ArmSwitch.setValue(0);
	}
}

var demand_weapons_refresh = func {
    setprop("sim/model/f15/controls/armament/weapons-updated", getprop("sim/model/f15/controls/armament/weapons-updated")+1);
}
#
#
# F-15 throttle has weapons selector switch with
# (AFT)
# GUN
# SRM = AIM-9L (Sidewinder)
# MRM = AIM-120C, AIM-7M, AIM-120D
# (FWD)
var arm_selector = func() {
	update_gun_ready();
	update_lau_ready();
	var weapon_s = WeaponSelector.getValue();
#    print("arm stick selector ",weapon_s);
    setprop("sim/model/f15/systems/armament/launch-light",0);
	if ( weapon_s == 0 )
    {
		SwSoundVol.setValue(0);
		set_status_current_aim9(-1);
	}
    elsif ( weapon_s == 5 ) # AG
    {
		if (Current_mk84 != nil and ArmSwitch.getValue() == 2 and sel_missile_count > 0)
        {
            Current_missile = Current_mk84;
			Current_missile.status = 0;
			Current_missile.search();
		}
	}
    elsif ( weapon_s == 1 )
    {
		# AIM-9L: (SRM)
		if (Current_srm != nil and ArmSwitch.getValue() == 2 and sel_missile_count > 0)
        {
            Current_missile = Current_srm;
			Current_missile.status = 0;
			Current_missile.search();
		}
	}
    elsif ( weapon_s == 2 )
    {
        # MRM
		if (Current_mrm != nil and ArmSwitch.getValue() == 2 and sel_missile_count > 0)
        {
            Current_missile = Current_mrm;
			Current_missile.status = 0;
			Current_missile.search();
		}
	}
    else
    {
		SwSoundVol.setValue(0);
		set_status_current_aim9(-1);
	}
    if (Station.firing_order == nil){
        print(" --> arm_selector : weapons not ready");
    }
    else {
        var sel=1; # only the next will be selected
        foreach (var S; Station.firing_order)
          {
              S.set_selected(0);
              if (weapon_s == 2) {
                  if (S.bcode == 2 or S.bcode == 3 or S.bcode == 6) {
                      S.set_selected(sel);
                      sel=0;
                  }
              } else if (weapon_s == 1) {
                  if (S.bcode == 1) {
                      S.set_selected(sel);
                      sel=0;
                  }
              } else if (weapon_s == 5) {
                  if (S.bcode == 4) # MK-83
                    {
                        S.set_selected(sel);
                        sel=0;
                    }
              }
#printf("Station %d %s:%s = %d (%d)",S.index,S.bcode, S.type.getValue(), S.get_selected(),sel);
#              printf("Station %d %s:%s = %d (%d)",S.index,S.bcode, S.type.getValue(), S.get_selected(),sel);
              S.set_type(S.get_type()); # initialize bcode.
          }
        setprop("sim/model/f15/controls/armament/weapons-updated", getprop("sim/model/f15/controls/armament/weapons-updated")+1);
    }
}

setlistener("/payload/weight[0]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[1]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[2]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[3]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[4]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[5]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[6]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[7]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[8]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[9]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});
setlistener("/payload/weight[10]/selected", func(v)
{
    demand_weapons_refresh();
    arm_selector();
});

  ############ Cannon impact messages #####################

var last_impact = 0;

var hit_count = 0;

var impact_listener = func {
  if (awg_9.active_u != nil and (getprop("sim/time/elapsed-sec")-last_impact) > 1) {
    var ballistic_name = props.globals.getNode("/ai/models/model-impact3",1).getValue();
    var ballistic = props.globals.getNode(ballistic_name, 0);
    if (ballistic != nil and ballistic.getName() != "munition") {
      var typeNode = ballistic.getNode("impact/type");
      if (typeNode != nil and typeNode.getValue() != "terrain") {
        var lat = ballistic.getNode("impact/latitude-deg").getValue();
        var lon = ballistic.getNode("impact/longitude-deg").getValue();
        var impactPos = geo.Coord.new().set_latlon(lat, lon);

        var track = awg_9.active_u.propNode;

        var x = track.getNode("position/global-x").getValue();
        var y = track.getNode("position/global-y").getValue();
        var z = track.getNode("position/global-z").getValue();
        var selectionPos = geo.Coord.new().set_xyz(x, y, z);

        var distance = impactPos.distance_to(selectionPos);
        if (distance < 125) {
          last_impact = getprop("sim/time/elapsed-sec");
          var phrase =  ballistic.getNode("name").getValue() ~ " hit: " ~ awg_9.active_u.Callsign.getValue();
          if (getprop("sim/model/f15/systems/armament/mp-messaging")) {
            armament.defeatSpamFilter(phrase);
                  #hit_count = hit_count + 1;
          } else {
            setprop("/sim/messages/atc", phrase);
          }
        }
      }
    }
  }
}

# setup impact listener
setlistener("/ai/models/model-impact3", impact_listener, 0, 0);

# tiny fix
setlistener("ai/submodels/submodel[5]/count", func {
    setprop("ai/submodels/submodel[6]/count", getprop("ai/submodels/submodel[5]/count"));
});


var flareCount = -1;
var flareStart = -1;

var flareLoop = func {
  # Flare release
  if (getprop("ai/submodels/submodel[5]/flare-release-snd") == nil) {
    setprop("ai/submodels/submodel[5]/flare-release-snd", 0);
    setprop("ai/submodels/submodel[5]/flare-release-out-snd", 0);
  }
  var flareOn = getprop("ai/submodels/submodel[5]/flare-release-cmd");
  if (flareOn == 1 and getprop("ai/submodels/submodel[5]/flare-release") == 0
      and getprop("ai/submodels/submodel[5]/flare-release-out-snd") == 0
      and getprop("ai/submodels/submodel[5]/flare-release-snd") == 0) {
    flareCount = getprop("ai/submodels/submodel[5]/count");
    flareStart = getprop("sim/time/elapsed-sec");
    if (flareCount > 0 and getprop("fdm/jsbsim/systems/electrics/ac-essential-bus1") > 0) {
      # release a flare
      setprop("ai/submodels/submodel[5]/flare-release-snd", 1);
      setprop("ai/submodels/submodel[5]/flare-release", 1);
      setprop("rotors/main/blade[3]/flap-deg", flareStart);
      setprop("rotors/main/blade[3]/position-deg", flareStart);
    } else {
      # play the sound for out of flares
      setprop("ai/submodels/submodel[5]/flare-release-out-snd", 1);
    }
  }
  if (getprop("ai/submodels/submodel[5]/flare-release-snd") == 1 and (flareStart + .5) < getprop("sim/time/elapsed-sec")) {
    setprop("ai/submodels/submodel[5]/flare-release-snd", 0);
    setprop("rotors/main/blade[3]/flap-deg", 0);
    setprop("rotors/main/blade[3]/position-deg", 0);
  }
  if (getprop("ai/submodels/submodel[5]/flare-release-out-snd") == 1 and (flareStart + .5) < getprop("sim/time/elapsed-sec")) {
    setprop("ai/submodels/submodel[5]/flare-release-out-snd", 0);
  }
  if (flareCount > getprop("ai/submodels/submodel[5]/count")) {
    # A flare was released in last loop, we stop releasing flares, so user have to press button again to release new.
    setprop("ai/submodels/submodel[5]/flare-release", 0);
    flareCount = -1;
  }
  settimer(flareLoop, 0.1);
};

flareLoop();
