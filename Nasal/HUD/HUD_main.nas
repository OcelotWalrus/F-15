# F-15 Canvas HUD
# ---------------------------
# HUD class has dataprovider
# F-15C HUD is in two parts so we have a single class that we can instantiate
# twice on for each combiner pane
# ---------------------------
# Richard Harrison (rjh@zaretto.com) 2015-01-27  - based on F-20 HUD main module Enrique Laso (Flying toaster)
# ---------------------------

var ht_xcf = 1024;
var ht_ycf = -1024;
var ht_xco = 0;
var ht_yco = 0;
var ht_debug = 0;

#angular definitions
#up angle 1.73 deg
#left/right angle 5.5 deg
#down angle 10.2 deg
#total size 11x11.93 deg
#texture square 256x256
#bottom left 0,0
#viewport size  236x256
#center at 118,219
#pixels per deg = 21.458507963

# paste into nasal console for debugging
#aircraft.MainHUD.canvas._node.setValues({
#                           "name": "F-15 HUD",
#                           "size": [1024,1024],
#                           "view": [276,106],
#                           "mipmapping": 0
#  });
#aircraft.MainHUD.svg.setTranslation (0, 20.0);
#aircraft.MainHUD.svg.set("clip", "rect(2,256,276,0)");
#aircraft.MainHUD.svg.setTranslation (-21.0, 37.0);
#aircraft.MainHUD.svg.set("clip", "rect(1,256,276,0)");
#aircraft.MainHUD.svg.set("clip", "rect(10,256,276,0)");
#aircraft.MainHUD.svg.set("clip-frame", canvas.Element.PARENT);

var pitch_factor=11.18;

var alt_range_factor = (9317-191) / 100000; # alt tape size and max value.
var ias_range_factor = (694-191) / 1100;

#Pinto: if you know starting x (left/right) and z (up/down), then i just do
#
#var changeViewX = -1 * (startViewX-getprop(viewX))*getprop(ghosting_x);
#var changeViewY = (startViewY-getprop(viewY))*getprop(ghosting_y);
#
#where ghosting_x and ghosting_y are parallax adjusting. about 7000
# trial and error can quickly give you the right values. Then I move the canvas elements by however much changeViewX and changeViewY are.
# calc of pitch_offset (compensates for AC3D model translated and rotated when loaded. Also semi compensates for HUD being at an angle.)
#        var Hz_b =    0.80643; # HUD position inside ac model after it is loaded translated and rotated.
#        var Hz_t =    0.96749;
#        var Vz   =    getprop("sim/current-view/y-offset-m"); # view Z position (0.94 meter per default)
#
#        var bore_over_bottom = Vz - Hz_b;
#        var Hz_height        = Hz_t-Hz_b;
#        var hozizon_line_offset_from_middle_in_svg = 0.137; #fraction up from middle
#        var frac_up_the_hud = bore_over_bottom / Hz_height - hozizon_line_offset_from_middle_in_svg;
#       var texels_up_into_hud = frac_up_the_hud * me.sy;#sy default is 260
#       var texels_over_middle = texels_up_into_hud - me.sy/2;
#
#
#        pitch_offset = -texels_over_middle;

#var changeViewX = -1 * (startViewX-getprop(viewX))*getprop(ghosting_x);
#var changeViewY = (startViewY-getprop(viewY))*getprop(ghosting_y);

var F15HUD = {
	new : func (svgname){
		var obj = {parents : [F15HUD] };

        obj.process_targets = PartitionProcessor.new("HUD-radar", 20, nil);
        obj.process_targets.set_max_time_usec(500);

        obj.canvas= canvas.new({
                "name": "F-15 HUD",
                    "size": [1024,1024],
                    "view": [256,296],
                    "mipmapping": 0,
                    });
        obj.view = [0, 1.4000051983, -5];
        obj.canvas.addPlacement({"node": "HUDImage1"});
        obj.canvas.addPlacement({"node": "HUDImage2"});
        obj.canvas.setColorBackground(0.36, 1, 0.3, 0.00);
        obj.FocusAtInfinity = 0;
# Create a group for the parsed elements
        obj.svg = obj.canvas.createGroup();

# Parse an SVG file and add the parsed elements to the given group
        print("HUD Parse SVG ",canvas.parsesvg(obj.svg, svgname));

        obj.canvas._node.setValues({
                                    "name": "F-15 HUD",
                                    "size": [1024,1024],
                                    "view": [256,296],
                                    "mipmapping": 0
                    });
        obj.baseTranslation = [30,30];
        obj.svg.setTranslation (obj.baseTranslation[0], obj.baseTranslation[1]);
        obj.svg.set("clip", "rect(11,256,296,0)");
        obj.svg.set("clip-frame", canvas.Element.PARENT);
        obj.svg.setScale(0.8,1.18);

        obj.ladder = obj.get_element("ladder");
        obj.ladder.setScale(1,0.558);

        obj.VV = obj.get_element("VelocityVector");
        obj.BV = obj.get_element("BombVector");
        obj.BV.setVisible(0);
        obj.heading_tape = obj.get_element("heading-scale");
        obj.roll_pointer = obj.get_element("roll-pointer");
        obj.alt_range = obj.get_element("alt_range");
        obj.ias_range = obj.get_element("ias_range");
        obj.window9_rect = obj.get_element("window9_rect");
        obj.window10_rect = obj.get_element("window10_rect");

        obj.target_locked = obj.get_element("target_locked");
        obj.target_locked.setVisible(0);
        obj.crosshair = obj.get_element("guncrosshair");

        obj.window1 = obj.get_text("window1", "condensed.txf",9,1.4);
        obj.window2 = obj.get_text("window2", "condensed.txf",9,1.4);
        obj.window3 = obj.get_text("window3", "condensed.txf",9,1.4);
        obj.window4 = obj.get_text("window4", "condensed.txf",9,1.4);
        obj.window5 = obj.get_text("window5", "condensed.txf",9,1.4);
        obj.window6 = obj.get_text("window6", "condensed.txf",9,1.4);
        obj.window7 = obj.get_text("window7", "condensed.txf",9,1.4);
        obj.window8 = obj.get_text("window8", "condensed.txf",9,1.4);
        obj.window9 = obj.get_text("window9", "condensed.txf",9,1.4);
        obj.window10 = obj.get_text("window10", "condensed.txf",9,1.4);
        obj.window11 = obj.get_text("window11", "condensed.txf",9,1.4);
        obj.window12 = obj.get_text("window12", "condensed.txf",9,1.4);
        obj.cross1 = obj.get_text("cross_1", "condensed.txf",9,1.4);

        obj.window1.setVisible(0);
        obj.cross1.setVisible(0);

        obj.HudNavRangeDisplay = "";
        obj.HudNavRangeETA = "";
        obj.currentViewX = props.globals.getNode("/sim/current-view/x-offset-m");
        obj.currentViewY = props.globals.getNode("/sim/current-view/y-offset-m");

        obj.symbol_reject = 0;
        obj.heading_deg=0;
        obj.roll_deg=0;
        obj.roll_rad=0;
        obj.pitch_deg=0;
        obj.VV_x=0;
        obj.VV_y=0;
        obj.BV_x=0;
        obj.BV_y=0;
        obj.mach=0;
        obj.rng=0;
        obj.eta_s=0;
        obj.showLow=0;

        HudMath.init([-4.54553+0.013,-0.057863,0.84791+0.010], [-4.56837+0.013, 0.057863,0.71547+0.010], [256,296], [0,1.0], [0.788878,0.0], 0);
#
#
# Load the target symbosl.
        obj.max_symbols = 10;
        obj.tgt_symbols =  setsize([],obj.max_symbols);

        for (var i = 0; i < obj.max_symbols; i += 1)
        {
            var name = "target_"~i;
            var tgt = obj.svg.getElementById(name);
            if (tgt != nil)
            {
                obj.tgt_symbols[i] = tgt;
                tgt.setVisible(0);
#                print("HUD: loaded ",name);
            }
            else
                print("HUD: could not locate ",name);
        }

            obj.dlzX      =170;
            obj.dlzY      =100;
            obj.dlzWidth  = 10;
            obj.dlzHeight = 90;
obj.dlzHeight=60;
obj.dlzY = 70;
            obj.dlzLW     =  1;
            obj.dlz      = obj.svg.createChild("group");
            obj.dlz2     = obj.dlz.createChild("group");
            obj.dlzArrow = obj.dlz.createChild("path")
                           .moveTo(0, 0)
                           .lineTo( -5, 4)
                           .moveTo(0, 0)
                           .lineTo( -5, -4)
                           .setColor(0,1,0)
                           .setStrokeLineWidth(obj.dlzLW);

        #
        #
        # using the new property manager to update items on the HUD.
        # this is more efficient as the update methods are only called whenever the property (or properties) change by more than a specified amount
        obj.update_items = [
            props.UpdateManager.FromHashList(["ElectricsAcLeftMainBus","ControlsHudBrightness"] , 0.01, func(val)
                                      {
                                          if (val.ElectricsAcLeftMainBus <= 0
                                              or val.ControlsHudBrightness <= 0) {
                                              obj.svg.setVisible(0);
                                          } else {
                                              obj.svg.setVisible(1);
                                          }
                                      }),
            props.UpdateManager.FromHashValue("AltimeterIndicatedAltitudeFt", 1, func(val)
                                             {
                                                 obj.alt_range.setTranslation(0, val * alt_range_factor);
                                             }),

            props.UpdateManager.FromHashValue("VelocitiesAirspeedKt", 0.1, func(val)
                                      {
                                          obj.ias_range.setTranslation(0, val * ias_range_factor);
                                      }),
            props.UpdateManager.FromHashValue("ControlsHudSymRej", 0.1, func(val)
                                             {
                                                 obj.symbol_reject = val;
                                             }),
            props.UpdateManager.FromHashValue("OrientationHeadingDeg", 0.025, func(val)
                                      {
                                          obj.heading_deg = val;
                                          #heading tape
                                          if (val < 180)
                                            obj.heading_tape_position = -val*54/10;
                                          else
                                            obj.heading_tape_position = (360-val)*54/10;

                                          obj.heading_tape.setTranslation (obj.heading_tape_position,0);
                                      }),
            props.UpdateManager.FromHashList(["OrientationRollDeg","OrientationPitchDeg"], 0.025, func(val)
                                    {
                                        obj.roll_deg = val.OrientationRollDeg;
                                        obj.roll_rad = -obj.roll_deg*3.14159/180.0;
                                        obj.roll_pointer.setRotation (obj.roll_rad);
                                        var ptx = 0;
                                        obj.pitch_deg = val.OrientationPitchDeg;
                                        var pty = 392+ obj.pitch_deg * pitch_factor;

                                        obj.ladder.setRotation(obj.roll_rad);
                                        obj.ladder.setTranslation(ptx,pty);

                                        if (obj.pitch_deg>0)
                                          obj.ladder.setCenter (110,900-obj.pitch_deg*(1815/90));
                                        else
                                          obj.ladder.setCenter (110,900+obj.pitch_deg*-(1772/90));
                                    }),
                            props.UpdateManager.FromHashList(["Alpha", "OrientationSideSlipDeg", "ControlsArmamentWeaponSelector"], 0.001, func(val)
                                                                     {
                                                                         if (val.OrientationSideSlipDeg == nil or val.Alpha == nil)
                                                                           return;
                                                                         obj.VV_x = (val.OrientationSideSlipDeg or 0)*10; # adjust for view
                                                                         obj.VV_y = (val.Alpha or 0)*10; # adjust for view
                                                                         obj.VV.setTranslation (obj.VV_x, obj.VV_y);

																		 bomb_type = getprop("sim/model/f15/systems/armament/selected-bomb");
																		 if (bomb_type != "none") {

	                                                                         # Update pos shit, taken from the FG F-16 model
	                                                                         gpsCoord = armament.AIM.getCCIPadv(18,0.20,bomb_type);
	                                                                         if (gpsCoord == nil) {
	                                                                            gpsCoord2 = geo.Coord.new(geo.aircraft_position());
	                                                                         } else {
	                                                                            gpsCoord2 = gpsCoord[0];
	                                                                         }
			                                                                 crft = geo.aircraft_position();
		                                                                     ptch = vector.Math.getPitch(crft,gpsCoord2);
	                                                                         dst  = crft.direct_distance_to(gpsCoord2);
	                                                                         brng = crft.course_to(gpsCoord2);
	                                                                         hrz  = math.cos(ptch*D2R)*dst;

	                                                                         vel_gz = -math.sin(ptch*D2R)*dst;
	                                                                         vel_gx = math.cos(brng*D2R) *hrz;
	                                                                         vel_gy = math.sin(brng*D2R) *hrz;


	                                                                         yaw   = getprop("orientation/heading-deg") * D2R;
	                                                                         roll  = getprop("orientation/roll-deg")    * D2R;
	                                                                         pitch = getprop("orientation/pitch-deg")   * D2R;

	                                                                         sy = math.sin(yaw);   cy = math.cos(yaw);
	                                                                         sr = math.sin(roll);  cr = math.cos(roll);
	                                                                         sp = math.sin(pitch); cp = math.cos(pitch);

	                                                                         vel_bx = vel_gx * cy * cp
	                                                                                  + vel_gy * sy * cp
	                                                                                  + vel_gz * -sp;
	                                                                         vel_by = vel_gx * (cy * sp * sr - sy * cr)
	                                                                                  + vel_gy * (sy * sp * sr + cy * cr)
	                                                                                  + vel_gz * cp * sr;
	                                                                         vel_bz = vel_gx * (cy * sp * cr + sy * sr)
	                                                                                  + vel_gy * (sy * sp * cr - cy * sr)
	                                                                                  + vel_gz * cp * cr;

	                                                                         dir_y  = math.atan2(round0_(vel_bz), math.max(vel_bx, 0.001)) * R2D;
	                                                                         dir_x  = math.atan2(round0_(vel_by), math.max(vel_bx, 0.001)) * R2D;

	                                                                         pos = HudMath.getCenterPosFromDegs(dir_x,-dir_y);

	                                                                         pos_x = pos[0];
	                                                                         pos_y = pos[1];
	                                                                         bPos = [obj.VV_x,obj.VV_y];
	                                                                         llx  = pos_x - bPos[0];
	                                                                         lly  = pos_y - bPos[1];
	                                                                         ll = math.sqrt(llx * llx + lly * lly);
	                                                                         if (ll != 0) {
	                                                                             pipAng = math.acos(llx / ll);
	                                                                             if (lly < 0) {
	                                                                                 pipAng *= -1;
	                                                                             }
	                                                                             obj.BV_x = pos_x - math.cos(pipAng) * 10;
	                                                                             obj.BV_y = pos_y - math.sin(pipAng) * 10;
	                                                                             obj.BV_x = obj.BV_x / 100; # disable X axis
	                                                                             obj.BV_y = (obj.BV_y / -4 - 315); # adapt it to the f15's HUD
																				 print(obj.BV_y);
	                                                                         } # if gear is down, put it in the center
	                                                                         if (getprop("controls/gear/gear-down")) {
	                                                                            obj.BV_y = 0;
	                                                                         }
	                                                                         obj.BV.setTranslation(obj.BV_x, obj.BV_y);
	                                                                         obj.window12.setTranslation(0, obj.BV_y);
	                                                                         #print(obj.BV_x);
	                                                                         #print(obj.BV_y);
	                                                                         #print("VV");
	                                                                         #print(obj.VV_x);
	                                                                         #print(obj.VV_y);

	                                                                         # determine if distance is too low for arming time
	                                                                         obj.showLow = !gpsCoord[1];
	                                                                         obj.showLow = obj.showLow?-1:1;
																		 }
                                                                     }),
                            props.UpdateManager.FromHashList(["InstrumentedG", "CadcOwsMaximumG"], 0.05, func(val)
                                                                     {
                                                                         obj.window8.setText(sprintf("%02d %02d",
                                                                                                     math.round(val.InstrumentedG*10.0),
                                                                                                     math.round(val.CadcOwsMaximumG*10.0)));
                                                                     }),
                            props.UpdateManager.FromHashList(["VelocitiesAirspeedKt"], nil, func(val)
                                                                     {
                                                                         obj.window9.setText(sprintf("%02d kts", math.round(val.VelocitiesAirspeedKt)));
                                                                     }),
                            props.UpdateManager.FromHashList(["InstrumentedG"], nil, func(val)
                                                                     {
                                                                         obj.window10.setText(sprintf("%4.2f G", val.InstrumentedG));
                                                                     }),
                            props.UpdateManager.FromHashList(["Alpha",
                                                                      "ControlsGearBrakeParking",
                                                                      "AirspeedIndicatorIndicatedMach",
                                                                      "ControlsGearGearDown"], 0.01, func(val)
                                                                     {
                                                                         obj.alpha = val.Alpha or 0;
                                                                         obj.mach = val.AirspeedIndicatorIndicatedMach or 0;
                                                                         if(val.ControlsGearBrakeParking)
                                                                           obj.window7.setText("BRAKES");
                                                                         else if(val.ControlsGearGearDown or obj.alpha > 20)
                                                                           obj.window7.setText(sprintf("AOA %d",obj.alpha));
                                                                         else
                                                                           obj.window7.setText(sprintf("Ma %1.3f",obj.mach));
                                                                     }),
                            props.UpdateManager.FromHashList(["AutopilotRouteManagerActive",
                                                                      "AutopilotRouteManagerWpDist",
                                                                      "AutopilotRouteManagerWpEtaSeconds",
                                                                      "ControlsGearGearDown"], 0.1, func(val)
                                                                     {
                                                                         if (val.AutopilotRouteManagerActive) {
                                                                             obj.rng = val.AutopilotRouteManagerWpDist;
                                                                             obj.eta_s = val.AutopilotRouteManagerWpEtaSeconds;
                                                                             if (obj.rng != nil) {
                                                                                 obj.HudNavRangeDisplay =sprintf("N %4.1f", obj.rng);
                                                                             } else {
                                                                                 obj.HudNavRangeDisplay = "N XXX";
                                                                             }

                                                                             if (obj.eta_s != nil)
                                                                               obj.HudNavRangeETA = sprintf("%2d MIN",obj.eta_s/60);
                                                                             else
                                                                               obj.HudNavRangeETA = "XX MIN";
                                                                         } else {
                                                                             obj.HudNavRangeDisplay = "";
                                                                             obj.HudNavRangeETA = "";
                                                                         }
                                                                     }),
                            props.UpdateManager.FromHashList(["ControlsArmamentMasterArmSwitch",
                                                                      "ControlsArmamentWeaponSelector",
                                                                      "ArmamentRounds",
                                                                      "ArmamentAim9Count",
                                                                      "ArmamentAim120Count",
                                                                      "ArmamentAim120DCount",
                                                                      "ArmamentAim7Count",
                                                                      "ArmamentMk83Count",
                                                                      "ArmamentMk84Count",
                                                                      "ArmamentCbu105Count",
																	  "ArmamentCbu87Count",
                                                                      "RadarActiveTargetAvailable",
                                                                      "RadarActiveTargetDisplay",
                                                                      "RadarActiveTargetCallsign",
                                                                      "RadarActiveTargetType",
                                                                      "RadarActiveTargetRange",
                                                                      "RadarActiveTargetClosure",
                                                                      "HudNavRangeDisplay",
                                                                      "HudNavRangeETA"], nil, func(val)
                                                                     {
                                                                         if (val.ControlsArmamentMasterArmSwitch) {
                                                                             var w_s = val.ControlsArmamentWeaponSelector;
                                                                             obj.window2.setVisible(1);
                                                                             obj.window11.setVisible(0);
                                                                             obj.crosshair.setVisible(0);
                                                                             if (w_s == 0) {
                                                                                 obj.window2.setText(sprintf("%3d",val.ArmamentRounds));
                                                                                 obj.crosshair.setVisible(1);
                                                                                 if (val.ArmamentRounds == 0) {
                                                                                    obj.cross1.setVisible(1);
                                                                                    obj.cross1.setText("------");
                                                                                 }
                                                                                 else {
                                                                                    obj.cross1.setVisible(0);
                                                                                 }
                                                                             } else if (w_s == 1) {
                                                                                 obj.window2.setText(sprintf("S%2dL", val.ArmamentAim9Count));
                                                                                 if (val.ArmamentAim9Count == 0) {
                                                                                    obj.cross1.setVisible(1);
                                                                                    obj.cross1.setText("------");
                                                                                 }
                                                                                 else {
                                                                                    obj.cross1.setVisible(0);
                                                                                 }
                                                                             } else if (w_s == 2){
                                                                                 obj.window2.setText(sprintf("M%2dF", val.ArmamentAim120Count + val.ArmamentAim120DCount + val.ArmamentAim7Count));
                                                                                 if ((val.ArmamentAim120Count + val.ArmamentAim120DCount + val.ArmamentAim7Count) == 0) {
                                                                                    obj.cross1.setVisible(1);
                                                                                    obj.cross1.setText("------");
                                                                                 }
                                                                                 else {
                                                                                    obj.cross1.setVisible(0);
                                                                                 }
                                                                             } else if (w_s == 5){
                                                                                 obj.window2.setText(sprintf("G%2d", val.ArmamentMk83Count + val.ArmamentMk84Count + val.ArmamentCbu105Count + val.ArmamentCbu87Count));
                                                                                 if (val.ArmamentMk83Count + val.ArmamentMk84Count + val.ArmamentCbu105Count + val.ArmamentCbu87Count == 0) {
                                                                                    obj.cross1.setVisible(1);
                                                                                    obj.cross1.setText("------");
                                                                                    obj.BV.setVisible(0);
                                                                                    obj.window12.setVisible(0);
                                                                                 }
                                                                                 else {
                                                                                    obj.cross1.setVisible(0);
                                                                                    obj.window11.setVisible(1);
																					#weapon_type = getprop("payload/weight[~"getprop("sim/model/f15/systems/armament/selected-bomb")"~]/selected");
                                                                                    #obj.window11.setText(weapon_type);
                                                                                    obj.BV.setVisible(1);
                                                                                    if (getprop("controls/gear/gear-down")) {
                                                                                        obj.window12.setText("GROUND");
                                                                                    } elsif (obj.showLow == -1 ) {
                                                                                        obj.window12.setText("LOW");
																					} elsif (getprop("orientation/roll-deg") > 5 or getprop("orientation/roll-deg") < -5) {
                                                                                        obj.window12.setText("ROLL");
                                                                                    } else {
                                                                                        obj.window12.setText("RDY");
                                                                                    }
                                                                                    obj.window12.setVisible(1);
                                                                                }
                                                                             }
                                                                             if (val.RadarActiveTargetAvailable or 0) {
                                                                                 obj.window3.setText(val.RadarActiveTargetCallsign);
                                                                                 var model = "XX";
                                                                                 if (val.RadarActiveTargetType != "")
                                                                                   model = val.RadarActiveTargetType;

                                                                                 #these labels aren't correct - but we don't have a full simulation of the targetting and missiles so
                                                                                 #have no real idea on the details of how this works.
                                                                                 if (val.RadarActiveTargetDisplay){
                                                                                     obj.window4.setText(sprintf("RNG %3.1f", val.RadarActiveTargetRange));
                                                                                     obj.window5.setText(sprintf("CLO %-3d", val.RadarActiveTargetClosure));
                                                                                 } else{
                                                                                     obj.window4.setText("");
                                                                                     obj.window5.setText("");
                                                                                 }
                                                                                 obj.window6.setText(model);
                                                                                 obj.window6.setVisible(1); # SRM UNCAGE / TARGET ASPECT
                                                                             }
                                                                         } else {
                                                                             obj.BV.setVisible(0);
                                                                             obj.window12.setVisible(0);
                                                                             obj.window2.setVisible(0);
                                                                             obj.window11.setVisible(0);
                                                                             obj.crosshair.setVisible(0);
                                                                             obj.cross1.setVisible(0);
                                                                             if (val.HudNavRangeDisplay != "")
                                                                               obj.window3.setText("NAV");
                                                                             else
                                                                               obj.window3.setText("");
                                                                             obj.window4.setText(val.HudNavRangeDisplay);
                                                                             obj.window5.setText(val.HudNavRangeETA);
                                                                             obj.window6.setVisible(0); # SRM UNCAGE / TARGET ASPECT
                                                                         }
                                                                     }
                                                                    ),
                           ];
return obj;
},
  #
#
# get a text element from the SVG and set the font / sizing
    get_text : func(id, font, size, ratio)
    {
        var el = me.svg.getElementById(id);
        el.setFont(font).setFontSize(size,ratio);
        return el;
    },

#
#
# Get an element from the SVG; handle errors; and apply clip rectangle
# if found (by naming convention : addition of _clip to object name).
    get_element : func(id) {
        var el = me.svg.getElementById(id);
        if (el == nil)
        {
            print("Failed to locate ",id," in SVG");
            return el;
        }
        var clip_el = me.svg.getElementById(id ~ "_clip");
        if (clip_el != nil)
        {
            clip_el.setVisible(0);
            var tran_rect = clip_el.getTransformedBounds();

            var clip_rect = sprintf("rect(%d,%d, %d,%d)",
                                   tran_rect[1], # 0 ys
                                   tran_rect[2],  # 1 xe
                                   tran_rect[3], # 2 ye
                                   tran_rect[0]); #3 xs
#            print(id," using clip element ",clip_rect, " trans(",tran_rect[0],",",tran_rect[1],"  ",tran_rect[2],",",tran_rect[3],")");
#   see line 621 of simgear/canvas/CanvasElement.cxx
#   not sure why the coordinates are in this order but are top,right,bottom,left (ys, xe, ye, xs)
            el.set("clip", clip_rect);
            el.set("clip-frame", canvas.Element.PARENT);
        }
        return el;
    },

#
#
#
    update : func(notification) {

        me.dlzArray = aircraft.getDLZ();
#me.dlzArray =[10,8,6,2,9];#test
        if (me.dlzArray == nil or size(me.dlzArray) == 0) {
                me.dlz.hide();
        } else {
            me.dlz.setTranslation(me.dlzX,me.dlzY);
            me.dlz2.removeAllChildren();
            me.dlzArrow.setTranslation(0,-me.dlzArray[4]/me.dlzArray[0]*me.dlzHeight);
            me.dlzGeom = me.dlz2.createChild("path")
                    .moveTo(0, -me.dlzArray[3]/me.dlzArray[0]*me.dlzHeight)
                    .lineTo(0, -me.dlzArray[2]/me.dlzArray[0]*me.dlzHeight)
                    .lineTo(me.dlzWidth, -me.dlzArray[2]/me.dlzArray[0]*me.dlzHeight)
                    .lineTo(me.dlzWidth, -me.dlzArray[3]/me.dlzArray[0]*me.dlzHeight)
                    .lineTo(0, -me.dlzArray[3]/me.dlzArray[0]*me.dlzHeight)
                    .lineTo(0, -me.dlzArray[1]/me.dlzArray[0]*me.dlzHeight)
                    .lineTo(me.dlzWidth, -me.dlzArray[1]/me.dlzArray[0]*me.dlzHeight)
                    .moveTo(0, -me.dlzHeight)
                    .lineTo(me.dlzWidth, -me.dlzHeight-3)
                    .lineTo(me.dlzWidth, -me.dlzHeight+3)
                    .lineTo(0, -me.dlzHeight)
                    .setStrokeLineWidth(me.dlzLW)
                    .setColor(0,1,0);
            me.dlz.show();
        }


        if(me.FocusAtInfinity)
          {
              # parallax correction
              var current_x = me.currentViewX.getValue();
              var current_y = me.currentViewY.getValue();
              #        var current_z = getprop("/sim/current-view/z-offset-m");

              var dx = me.view[0] - current_x;
              var dy = me.view[1] - current_y;

              me.svg.setTranslation(me.baseTranslation[0]-dx*1024, me.baseTranslation[1]+dy*1024);
          }

        if (awg_9.active_u == nil) {
            notification.RadarActiveTargetAvailable = 0;
            notification.RadarActiveTargetCallsign = "";
            notification.RadarActiveTargetType = "";
            notification.RadarActiveTargetRange = 0;
            notification.RadarActiveTargetClosure = 0;
        } else {
            notification.RadarActiveTargetAvailable = 1;
#print("active callsign ",awg_9.active_u.Callsign,":");
            if (awg_9.active_u.Callsign != nil)
              notification.RadarActiveTargetCallsign = awg_9.active_u.Callsign.getValue();
            else
              notification.RadarActiveTargetCallsign = "XXX";

            notification.RadarActiveTargetType = awg_9.active_u.ModelType;
            notification.RadarActiveTargetDisplay = awg_9.active_u.get_display();
            notification.RadarActiveTargetRange = awg_9.active_u.get_range();
            notification.RadarActiveTargetClosure = awg_9.active_u.get_closure_rate();
        }
        notification.HudNavRangeDisplay = me.HudNavRangeDisplay;
        notification.HudNavRangeETA = me.HudNavRangeETA;

        foreach(var update_item; me.update_items)
        {
            update_item.update(notification);
        }

        if (me.svg.getVisible() == 0)
          return;


#        if (hdp.range_rate != nil)
#        {
#            me.window1.setVisible(1);
#            me.window1.setText("");
#        }
#        else
#            me.window1.setVisible(0);


     if (notification["Timestamp"] != nil)
         me.process_targets.set_timestamp(notification.Timestamp);

     me.process_targets.process(me, awg_9.tgts_list,
                                func(pp, obj, data){
                                    obj.target_idx=1;
                                    obj.designated = 0;
                                    obj.target_locked.setVisible(0);
                                }
                                ,
                                func(pp, obj, u){
            var callsign = "XX";
                                    if(u.get_display() == 1){
                if (u.Callsign != nil)
                    callsign = u.Callsign.getValue();
                var model = "XX";

                if (u.ModelType != "")
                    model = u.ModelType;

                                        if (obj.target_idx < obj.max_symbols)
                {
                                              tgt = obj.tgt_symbols[obj.target_idx];
                    if (tgt != nil)
                    {
                        tgt.setVisible(u.get_display());
                                                    var u_dev_rad = (90-u.get_deviation(obj.heading_deg))  * D2R;
                                                    var u_elev_rad = (90-u.get_total_elevation( obj.pitch_deg))  * D2R;
                        var devs = aircraft.develev_to_devroll(u_dev_rad, u_elev_rad);
                        var combined_dev_deg = devs[0];
                        var combined_dev_length =  devs[1];
                        var clamped = devs[2];
                        var yc  = ht_yco + (ht_ycf * combined_dev_length * math.cos(combined_dev_deg*D2R));
                        var xc = ht_xco + (ht_xcf * combined_dev_length * math.sin(combined_dev_deg*D2R));
                        if(devs[2])
                            tgt.setVisible(getprop("sim/model/f15/lighting/hud-diamond-switch/state"));
                        else
                            tgt.setVisible(u.get_display());

                        if (awg_9.active_u != nil and awg_9.active_u.Callsign != nil and u.Callsign != nil and u.Callsign.getValue() == awg_9.active_u.Callsign.getValue())
                        {
                                                          obj.target_locked.setVisible(u.get_display());
                                                          obj.target_locked.setTranslation (xc, yc);
                        }
                        else
                        {
                            #
                            # if in symbol reject mode then only show the active target.
                                                          if(obj.symbol_reject)
                                tgt.setVisible(0);
                        }
                        tgt.setTranslation (xc, yc);

                        if (ht_debug)
                            printf("%-10s %f,%f [%f,%f,%f] :: %f,%f",callsign,xc,yc, devs[0], devs[1], devs[2], u_dev_rad*D2R, u_elev_rad*D2R);
                    }
                }
                                        obj.target_idx = obj.target_idx+1;
            }
                                    return 1;
                                },
                                func(pp, obj, data)
        {
                                    for(var nv = obj.target_idx; nv < obj.max_symbols;nv += 1)
                                      {
                                          tgt = obj.tgt_symbols[nv];
            if (tgt != nil)
            {
                tgt.setVisible(0);
            }
        }
                                });


    },
    list: [],
};

#
# The F-15C HUD is provided by 2 combiners.
# We model this accurately in the geometry by having the two glass panes
# which are texture mapped onto a single canvas texture.two instances of the HUD
# 2016-01-06: The HUD appears slightly trapezoidal (better than previous version
#             however still could be improved possibly with a transformation matrix.

var round0_ = func(x) {
	return math.abs(x) > 0.01 ? x : 0;
};

var HUDRecipient =
{
    new: func(_ident)
    {
        var new_class = emesary.Recipient.new(_ident);
        new_class.MainHUD = nil;
        new_class.Receive = func(notification)
        {
            if (notification.NotificationType == "FrameNotification")
            {
                if (new_class.MainHUD == nil)
                  new_class.MainHUD = F15HUD.new("Nasal/HUD/HUD.svg", "HUDImage1");
                if (!math.mod(notifications.frameNotification.FrameCount,2)){
                    new_class.MainHUD.update(notification);
                }
                return emesary.Transmitter.ReceiptStatus_OK;
            }
            return emesary.Transmitter.ReceiptStatus_NotProcessed;
        };
        return new_class;
    },
};

emesary.GlobalTransmitter.Register(HUDRecipient.new("F15-HUD"));
input = {
        AirspeedIndicatorIndicatedMach          : "instrumentation/airspeed-indicator/indicated-mach",
        Alpha                                   : "orientation/alpha-indicated-deg",
        AltimeterIndicatedAltitudeFt            : "instrumentation/altimeter/indicated-altitude-ft",
        ArmamentMk83Count                       : "sim/model/f15/systems/armament/mk83/count",
        ArmamentMk84Count                       : "sim/model/f15/systems/armament/mk84/count",
        ArmamentAim120Count                     : "sim/model/f15/systems/armament/aim120c/count",
        ArmamentAim7Count                       : "sim/model/f15/systems/armament/aim7/count",
        ArmamentAim9Count                       : "sim/model/f15/systems/armament/aim9/count",
        ArmamentAim120DCount                    : "sim/model/f15/systems/armament/aim120d/count",
		ArmamentCbu105Count                     : "sim/model/f15/systems/armament/cbu105/count",
		ArmamentCbu87Count                     : "sim/model/f15/systems/armament/cbu87/count",
        ArmamentRounds                          : "sim/model/f15/systems/gun/rounds",
        AutopilotRouteManagerActive             : "autopilot/route-manager/active",
        AutopilotRouteManagerWpDist             : "autopilot/route-manager/wp/dist",
        AutopilotRouteManagerWpEtaSeconds       : "autopilot/route-manager/wp/eta-seconds",
        CadcOwsMaximumG                         : "fdm/jsbsim/systems/cadc/ows-maximum-g",
        ControlsArmamentMasterArmSwitch         : "sim/model/f15/controls/armament/master-arm-switch",
        ControlsArmamentWeaponSelector          : "sim/model/f15/controls/armament/weapon-selector",
        ControlsGearBrakeParking                : "controls/gear/brake-parking",
        ControlsGearGearDown                    : "controls/gear/gear-down",
        ControlsHudBrightness                   : "sim/model/f15/controls/HUD/brightness",
        ControlsHudSymRej                       : "sim/model/f15/controls/HUD/sym-rej",
        ElectricsAcLeftMainBus                  : "fdm/jsbsim/systems/electrics/ac-left-main-bus",
        HudNavRangeDisplay                      : "sim/model/f15/instrumentation/hud/nav-range-display",
        HudNavRangeETA                          : "sim/model/f15/instrumentation/hud/nav-range-eta",
        OrientationHeadingDeg                   : "orientation/heading-deg",
        OrientationPitchDeg                     : "orientation/pitch-deg",
        OrientationRollDeg                      : "orientation/roll-deg",
        OrientationSideSlipDeg                  : "orientation/side-slip-deg",
        RadarActiveTargetAvailable              : "sim/model/f15/instrumentation/radar-awg-9/active-target-available",
        RadarActiveTargetCallsign               : "sim/model/f15/instrumentation/radar-awg-9/active-target-callsign",
        RadarActiveTargetClosure                : "sim/model/f15/instrumentation/radar-awg-9/active-target-closure",
        RadarActiveTargetDisplay                : "sim/model/f15/instrumentation/radar-awg-9/active-target-display",
        RadarActiveTargetRange                  : "sim/model/f15/instrumentation/radar-awg-9/active-target-range",
        RadarActiveTargetType                   : "sim/model/f15/instrumentation/radar-awg-9/active-target-type",
        InstrumentedG                           : "instrumentation/g-meter/instrumented-g",
        VelocitiesAirspeedKt                    : "velocities/airspeed-kt",
        ArmingTime                              : "sim/model/f15/systems/armament/arming-time-sec",
};
foreach (var name; keys(input)) {
    emesary.GlobalTransmitter.NotifyAll(notifications.FrameNotificationAddProperty.new("F15-HUD", name, input[name]));
}
