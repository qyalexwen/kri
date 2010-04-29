﻿namespace kri.part.beh

import OpenTK
import kri.shade


public class Sys(Basic):	# at_sys storage for standard root
	public def constructor(pc as kri.part.Context):
		super('/part/beh/sys')
		kri.vb.enrich( self, 2, pc.at_sys )


public class Pad(Basic):	# padding for rgba32f align
	public static final	slot	= kri.Ant.Inst.slotParticles.getForced('pad')
	public def constructor():
		super('/part/beh/pad')
		kri.vb.enrich( self, 1, slot )


public class Norm(Basic):	# fur normalizing
	public def constructor():
		super('/part/beh/fur_norm')


#-------------------------------------------#
#	SIMPLE BEHAVIOR BASE					#
#-------------------------------------------#

public class Simple[of T(struct)](Basic):
	public final pData	as par.Value[of T]
	public def constructor(path as string, varname as string, data as T):
		super(path)
		pData = par.Value[of T](varname)
		pData.Value = data
	public override def link(d as rep.Dict) as void:
		d.var(pData)


#-------------------------------------------#
#	SMALL  BEHAVIORS						#
#-------------------------------------------#

public class Gravity(Simple[of Vector4]):	# gravity & plain forces
	public def constructor():
		super('/part/beh/grav','force_world', Vector4(0f,0f,-9.81f,0f) )

public class Damp(Simple[of single]):		# speed damping
	public def constructor(val as single):
		super('/part/beh/damp','speed_damp',val)

public class Bend(Simple[of single]):		# fur bending
	public def constructor(val as single):
		super( '/part/beh/fur_bend','fur_bend',val)
