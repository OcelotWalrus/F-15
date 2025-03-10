var Math = {
    #
    # Author: Nikolai V. Chr.
    #
    # Version 1.5
    #
    # When doing euler coords. to cartesian: +x = forw, +y = left,  +z = up.
    # FG struct. coords:                     +x = back, +y = right, +z = up.
    #
    # When doing euler angles (from pilots point of view):  yaw     = yaw left,  pitch = rotate up, roll = roll right.
    # FG rotations:                                         heading = yaw right, pitch = rotate up, roll = roll right.
    #
    clamp: func(v, min, max) { v < min ? min : v > max ? max : v },

    convertCoords: func (x,y,z) {
        return [-x, -y, z];
    },

    convertAngles: func (heading,pitch,roll) {
        return [-heading, pitch, roll];
    },

    # angle between 2 vectors. Returns 0-180 degrees.
    angleBetweenVectors: func (a,b) {
        a = me.normalize(a);
        b = me.normalize(b);
        me.value = me.clamp((me.dotProduct(a,b)/me.magnitudeVector(a))/me.magnitudeVector(b),-1,1);#just to be safe in case some floating point error makes it out of bounds
        return R2D * math.acos(me.value);
    },

    # length of vector
    magnitudeVector: func (a) {
        return math.sqrt(math.pow(a[0],2)+math.pow(a[1],2)+math.pow(a[2],2));
    },

    # dot product of 2 vectors
    dotProduct: func (a,b) {
        return a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
    },

    # rotate a vector. Order: roll, pitch, yaw
    rollPitchYawVector: func (roll, pitch, yaw, vector) {
        me.rollM  = me.rollMatrix(roll);
        me.pitchM = me.pitchMatrix(pitch);
        me.yawM   = me.yawMatrix(yaw);
        me.rotation = me.multiplyMatrices(me.multiplyMatrices(me.yawM, me.pitchM), me.rollM);
        return me.multiplyMatrixWithVector(me.rotation, vector);
    },

    # rotate a vector. Order: yaw, pitch, roll (like an aircraft)
    yawPitchRollVector: func (yaw, pitch, roll, vector) {
        me.rollM  = me.rollMatrix(roll);
        me.pitchM = me.pitchMatrix(pitch);
        me.yawM   = me.yawMatrix(yaw);
        me.rotation = me.multiplyMatrices(me.multiplyMatrices(me.rollM, me.pitchM), me.yawM);
        return me.multiplyMatrixWithVector(me.rotation, vector);
    },

    # multiply 3x3 matrix with vector
    multiplyMatrixWithVector: func (matrix, vector) {
        return [matrix[0]*vector[0]+matrix[1]*vector[1]+matrix[2]*vector[2],
                matrix[3]*vector[0]+matrix[4]*vector[1]+matrix[5]*vector[2],
                matrix[6]*vector[0]+matrix[7]*vector[1]+matrix[8]*vector[2]];
    },

    # multiply 2 3x3 matrices
    multiplyMatrices: func (a,b) {
        return [a[0]*b[0]+a[1]*b[3]+a[2]*b[6], a[0]*b[1]+a[1]*b[4]+a[2]*b[7], a[0]*b[2]+a[1]*b[5]+a[2]*b[8],
                a[3]*b[0]+a[4]*b[3]+a[5]*b[6], a[3]*b[1]+a[4]*b[4]+a[5]*b[7], a[3]*b[2]+a[4]*b[5]+a[5]*b[8],
                a[6]*b[0]+a[7]*b[3]+a[8]*b[6], a[6]*b[1]+a[7]*b[4]+a[8]*b[7], a[6]*b[2]+a[7]*b[5]+a[8]*b[8]];
    },

    # matrix for rolling
    rollMatrix: func (roll) {
        roll = roll * D2R;
        return [1,0,0,
                0,math.cos(roll),-math.sin(roll),
                0,math.sin(roll), math.cos(roll)];
    },

    # matrix for pitching
    pitchMatrix: func (pitch) {
        pitch = pitch * D2R;
        return [math.cos(pitch),0,-math.sin(pitch),
                0,1,0,
                math.sin(pitch),0,math.cos(pitch)];
    },

    # matrix for yawing
    yawMatrix: func (yaw) {
        yaw = yaw * D2R;
        return [math.cos(yaw),-math.sin(yaw),0,
                math.sin(yaw),math.cos(yaw),0,
                0,0,1];
    },

    # gives an vector that points up from fuselage
    eulerToCartesian3Z: func (yaw_deg, pitch_deg, roll_deg) {
        me.yaw   = yaw_deg     * D2R;
        me.pitch = pitch_deg   * D2R;
        me.roll  = roll_deg    * D2R;
        me.x = -math.cos(me.yaw)*math.sin(me.pitch)*math.cos(me.roll) + math.sin(me.yaw)*math.sin(me.roll);
        me.y = -math.sin(me.yaw)*math.sin(me.pitch)*math.cos(me.roll) - math.cos(me.yaw)*math.sin(me.roll);
        me.z =  math.cos(me.pitch)*math.cos(me.roll);#roll changed from sin to cos, since the rotation matrix is wrong
        return [me.x,me.y,me.z];
    },

    # gives an vector that points forward from fuselage
    eulerToCartesian3X: func (yaw_deg, pitch_deg, roll_deg) {
        me.yaw   = yaw_deg     * D2R;
        me.pitch = pitch_deg   * D2R;
        me.roll  = roll_deg    * D2R;
        me.x = math.cos(me.yaw)*math.cos(me.pitch);
        me.y = math.sin(me.yaw)*math.cos(me.pitch);
        me.z = math.sin(me.pitch);
        return [me.x,me.y,me.z];
    },

    # gives an vector that points left from fuselage
    eulerToCartesian3Y: func (yaw_deg, pitch_deg, roll_deg) {
        me.yaw   = yaw_deg     * D2R;
        me.pitch = pitch_deg   * D2R;
        me.roll  = roll_deg    * D2R;
        me.x = -math.cos(me.yaw)*math.sin(me.pitch)*math.sin(me.roll) - math.sin(me.yaw)*math.cos(me.roll);
        me.y = -math.sin(me.yaw)*math.sin(me.pitch)*math.sin(me.roll) + math.cos(me.yaw)*math.cos(me.roll);
        me.z =  math.cos(me.pitch)*math.sin(me.roll);
        return [me.x,me.y,me.z];
    },

    # same as eulerToCartesian3X, except it needs no roll
    eulerToCartesian2: func (yaw_deg, pitch_deg) {
        me.yaw   = yaw_deg     * D2R;
        me.pitch = pitch_deg   * D2R;
        me.x = math.cos(me.pitch) * math.cos(me.yaw);
        me.y = math.cos(me.pitch) * math.sin(me.yaw);
        me.z = math.sin(me.pitch);
        return [me.x,me.y,me.z];
    },

    #pitch from coord1 to coord2 in degrees (takes curvature of earth into effect.)
    getPitch: func (coord1, coord2) {
      if (coord1.lat() == coord2.lat() and coord1.lon() == coord2.lon()) {
        if (coord2.alt() > coord1.alt()) {
          return 90;
        } elsif (coord2.alt() < coord1.alt()) {
          return -90;
        } else {
          return 0;
        }
      }
      if (coord1.alt() != coord2.alt()) {
        me.d12 = coord1.direct_distance_to(coord2);
        me.coord3 = geo.Coord.new(coord1);
        me.coord3.set_alt(coord1.alt()-me.d12*0.5);# this will increase the area of the triangle so that rounding errors dont get in the way.
        me.d13 = coord1.alt()-me.coord3.alt();
        if (me.d12 == 0) {
            # on top of each other, maybe rounding error..
            return 0;
        }
        me.d32 = me.coord3.direct_distance_to(coord2);
        if (math.abs(me.d13)+me.d32 < me.d12) {
            # rounding errors somewhere..one triangle side is longer than other 2 sides combined.
            return 0;
        }
        # standard formula for a triangle where all 3 side lengths are known:
        me.len = (math.pow(me.d12, 2)+math.pow(me.d13,2)-math.pow(me.d32, 2))/(2 * me.d12 * math.abs(me.d13));
        if (me.len < -1 or me.len > 1) {
            # something went wrong, maybe rounding error..
            return 0;
        }
        me.angle = R2D * math.acos(me.len);
        me.pitch = -1* (90 - me.angle);
        #printf("d12 %.4f  d32 %.4f  d13 %.4f len %.4f pitch %.4f angle %.4f", me.d12, me.d32, me.d13, me.len, me.pitch, me.angle);
        return me.pitch;
      } else {
        # same altitude
        me.nc = geo.Coord.new();
        me.nc.set_xyz(0,0,0);        # center of earth
        me.radiusEarth = coord1.direct_distance_to(me.nc);# current distance to earth center
        me.d12 = coord1.direct_distance_to(coord2);
        # standard formula for a triangle where all 3 side lengths are known:
        me.len = (math.pow(me.d12, 2)+math.pow(me.radiusEarth,2)-math.pow(me.radiusEarth, 2))/(2 * me.d12 * me.radiusEarth);
        if (me.len < -1 or me.len > 1) {
            # something went wrong, maybe rounding error..
            return 0;
        }
        me.angle = R2D * math.acos(me.len);
        me.pitch = -1* (90 - me.angle);
        return me.pitch;
      }
    },

    # supply a normal to the plane, and a vector. The vector will be projected onto the plane, and that projection is returned as a vector.
    projVectorOnPlane: func (planeNormal, vector) {
      return me.minus(vector, me.product(me.dotProduct(vector,planeNormal)/math.pow(me.magnitudeVector(planeNormal),2), planeNormal));
    },

    # vector a - vector b
    minus: func (a, b) {
      return [a[0]-b[0], a[1]-b[1], a[2]-b[2]];
    },

    # vector a + vector b
    plus: func (a, b) {
      return [a[0]+b[0], a[1]+b[1], a[2]+b[2]];
    },

    # float * vector
    product: func (scalar, vector) {
      return [scalar*vector[0], scalar*vector[1], scalar*vector[2]]
    },

    # print vector to console
    format: func (v) {
      return sprintf("(%.1f, %.1f, %.1f)",v[0],v[1],v[2]);
    },

    # make vector length 1.0
    normalize: func (v) {
      me.mag = me.magnitudeVector(v);
      return [v[0]/me.mag, v[1]/me.mag, v[2]/me.mag];
    },

# rotation matrices
#
#
#| 1    0          0      |
#| 0 cos(roll) -sin(roll) |
#| 0 sin(roll)  cos(roll) |
#
#| cos(pitch) 0 -sin(pitch) |
#|     0      1      0      |
#| sin(pitch) 0  cos(pitch) |
#
#| cos(yaw) -sin(yaw) 0 |
#| sin(yaw)  cos(yaw) 0 |
#|    0         0     1 |
#
# combined matrix from yaw, pitch, roll:
#
#| cos(yaw)cos(pitch) -cos(yaw)sin(pitch)sin(roll)-sin(yaw)cos(roll) -cos(yaw)sin(pitch)cos(roll)+sin(yaw)sin(roll)|
#| sin(yaw)cos(pitch) -sin(yaw)sin(pitch)sin(roll)+cos(yaw)cos(roll) -sin(yaw)sin(pitch)cos(roll)-cos(yaw)sin(roll)|
#| sin(pitch)          cos(pitch)sin(roll)                            cos(pitch)cos(roll)|
#
#

};
