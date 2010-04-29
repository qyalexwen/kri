﻿namespace kri.load

import OpenTK

public struct SetBake:
	public width	as uint
	public height	as uint
	public b_pos	as byte
	public b_rot	as byte
	public filt		as bool
	public def tag() as kri.ITag:
		return kri.kit.bake.Tag(width,height,b_pos,b_rot,filt)

public partial class Settings:
	public bake		= SetBake( width:256, height:256, b_pos:16, b_rot:8, filt:false )



public partial class Native:
	public final pcon =	kri.part.Context()

	public def finishParticles() as void:
		for pe in at.scene.particles:
			pm = pe.owner
			continue	if pm.Ready
			if 'Std':
				pm.behos.Add( kri.part.beh.Sys(pcon) )
				pm.makeStandard(pcon)
				pm.col_update.extra.Add( pcon.sh_born_time )
			else:
				pass
			pm.init(pcon)


	#---	Parse emitter object	---#
	public def p_part() as bool:
		pm = kri.part.Manager( br.ReadUInt32() )
		puData(pm)
		getVec2()	# particle size
		# create emitter
		pe = kri.part.Emitter( pm, getString() )
		puData(pe)
		pe.obj = geData[of kri.Entity]()
		at.scene.particles.Add(pe)
		# link to material
		pe.mat = at.mats[ getString() ]
		pe.mat = con.mDef	if not pe.mat
		return true


	#---	Parse distribution		---#
	public def pp_dist() as bool:
		def upNode(e as kri.Entity):
			assert e
			kri.Ant.Inst.params.modelView.activate( e.node )
			return true
		source = getString()
		getString()		# type
		br.ReadSingle()	# jitter factor
		ent = geData[of kri.Entity]()
		pe = geData[of kri.part.Emitter]()
		return false	if not pe
		pm = pe.owner

		ph = pm.seBeh[of kri.kit.hair.Behavior]()
		if source == 'FACE':
			if not ent.seTag[of kri.kit.bake.Tag]():
				ent.tags.Add( sets.bake.tag() )
			return true	if ph
		else: assert not ph
		
		sh as kri.shade.Object	= null
		if source == '':
			sh = pcon.sh_surf_node
			pe.onUpdate = upNode
		elif source == 'VERT':
			for i in range(2):
				t = kri.shade.par.Value[of kri.Texture]( ('vertex','quat')[i] )
				pm.dict.unit(t.Name,t)
				t.Value = kri.Texture( TextureTarget.TextureBuffer )
				t.Value.bind()
				ats = (kri.Ant.Inst.attribs.vertex, kri.Ant.inst.attribs.quat)
				kri.Texture.Init( SizedInternalFormat.Rgba32f, ent.findAny(ats[i]) )
				pe.onUpdate = upNode
			parNumber = kri.shade.par.Value[of single]('num_vertices')
			parNumber.Value = 1f * ent.mesh.nVert
			pm.dict.var(parNumber)
			sh = pcon.sh_surf_vertex
		elif source == 'FACE':
			tVert = kri.shade.par.Value[of kri.Texture]('vertex')
			tQuat = kri.shade.par.Value[of kri.Texture]('quat')
			pm.dict.unit(tVert,tQuat)
			pe.onUpdate = def(e as kri.Entity):
				upNode(e)
				tag = e.seTag[of kri.kit.bake.Tag]()
				return false	if not tag
				tVert.Value = tag.tVert
				tQuat.Value = tag.tQuat
				return true
			sh = pcon.sh_surf_face
		else: assert not 'supported :('
		pm.col_update.extra.Add(sh)
		return true


	#---	Parse life data	(emitter)	---#
	public def pp_life() as bool:
		pm = geData[of kri.part.Manager]()
		return false	if not pm
		beh = kri.part.beh.Standard(pcon)
		pm.behos.Add( beh )
		data = getVec4()	# start,end, life time, random
		beh.parLife.Value = Vector4( data.Z, data.W, data.Y-data.X, 1f )
		return true
	
	#---	Parse hair dynamics data	---#
	public def pp_hair() as bool:
		pm = geData[of kri.part.Manager]()
		return false	if not pm
		segs = br.ReadByte()
		beh = kri.kit.hair.Behavior(pcon,segs)
		pm.behos.Add( beh )
		dyn = getVector()	# stiffness, mass, bending
		pm.behos.Add( kri.part.beh.Bend( dyn.Z ))
		damp = getVec2()	# spring, air
		pm.behos.Add( kri.part.beh.Damp( damp.X ))
		pm.behos.Add( kri.part.beh.Norm() )
		return true
	
	#---	Parse velocity setup		---#
	public def pp_vel() as bool:
		pe = geData[of kri.part.Emitter]()
		return false	if not pe or not pe.owner
		objFactor	= getVector()	# object-aligned factor
		tanFactor	= getVector()	# normal, tangent, tan-phase
		add			= getVec2()		# object speed, random
		tan	= Vector3( tanFactor.Y, 0f, tanFactor.X )
		# get behavior
		ps = pe.owner.seBeh[of kri.part.beh.Standard]()
		ph = pe.owner.seBeh[of kri.kit.hair.Behavior]()
		if ps:		# standard
			ps.parVelObj.Value = Vector4( objFactor )
			ps.parVelTan.Value = Vector4( tan, tanFactor.Z )
			ps.parVelKeep.Value = Vector4.Zero
		elif ph:	# hair
			lays = ph.genLayers( pe, Vector4(tan,add.Y) )
			at.scene.particles.Remove(pe)
			at.scene.particles.AddRange(lays)
		else: return false
		return true
	
	public def pp_rot() as bool:
		return true
	
	public def pp_force() as bool:
		pm = geData[of kri.part.Manager]()
		return false	if not pm
		bgav = kri.part.beh.Gravity()
		pm.behos.Add(bgav)
		getVector()	# forces: brownian, drag, damp
		return true
