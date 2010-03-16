﻿namespace kri.load

public partial class Native:
	protected def getProjector(p as kri.Projector) as void:
		p.rangeIn	= getReal()
		p.rangeOut	= getReal()
		p.fov		= getReal() * 0.5f

	#---	Parse entity	---#
	public def p_entity() as bool:
		off,n = 0,0
		m = geData[of kri.Mesh]()
		node = geData[of kri.Node]()
		return false	if not m or not node
		e = kri.Entity( node:node, mesh:m )
		at.scene.entities.Add(e)
		puData(e)
		while true:
			n = br.ReadUInt16()
			break	if not n
			e.tags.Add( kri.TagMat( off:off, num:n,
				mat: at.mats[ getString(STR_LEN) ] ))
			off += n
		n = m.nPoly - off
		return	if not n
		assert n > 0
		e.tags.Add( kri.TagMat(off:off, num:n, mat:con.mDef ))
		return true
	
	#---	Parse spatial node	---#
	public def p_node() as bool:
		n = kri.Node( getString(STR_LEN) )
		at.nodes[n.name] = n
		puData(n)
		n.Parent = at.nodes[ getString(STR_LEN) ]
		n.Local = getSpatial()
		return true
	
	#---	Parse camera	---#
	public def p_cam() as bool:
		n = geData[of kri.Node]()
		return false	if not n
		c = kri.Camera( node:n )
		br.ReadByte()	# is current
		getProjector(c)
		at.scene.cameras.Add(c)
		return true

	#---	Light Types		---#
	public enum LiType:
		Point
		Sun
		Spot
		HEMI
		AREA
	#---	Parse light source	---#
	public def p_lamp() as bool:
		n = geData[of kri.Node]()
		return false	if not n
		l = kri.Light( node:n )
		l.color	= getColor()
		# attenuation
		l.energy	= getReal()
		l.quad1		= getReal()
		l.quad2		= getReal()
		l.sphere	= getReal()
		# main
		lt = cast(LiType, br.ReadByte())
		getProjector(l)
		if lt == LiType.Sun:
			l.makeDirectional( l.fov )
		elif lt == LiType.Point:
			l.fov = 0f
		l.softness	= getReal()
		at.scene.lights.Add(l)
		return true
	
	#---	Parse light source	---#
	public def p_part() as bool:
		#pm = kri.part.Manager( br.ReadUInt32() )
		//pe = kri.part.Emitter(pm,ent)
		pe as kri.part.Emitter = null
		br.ReadUInt32()		# amount
		getString(STR_LEN)	# name
		psMat = at.mats[ getString(STR_LEN) ]
		psMat = con.mDef	if not psMat
		br.ReadBytes(5)	# distribution
		for i in range(3+2+6+3+3+2):	# lifetime, velocity, force, size
			getReal()
		if pe and 'emitting from the mesh surface':
			e = geData[of kri.Entity]()
			return false	if not e
			pe.onUpdate = { kri.Ant.Inst.units.activate(e.unit) }
		at.scene.particles.Add(pe)
		return true