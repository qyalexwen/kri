﻿namespace kri.rend.light.g

import System
import OpenTK.Graphics.OpenGL
import kri.rend


#---------	RENDER TO G-BUFFER	--------#

public class Fill( tech.Meta ):
	public final buf		= kri.frame.Buffer()
	public GBuf as kri.Texture:
		get: return buf.A[0].Tex
	# init
	public def constructor():
		ms = Array.ConvertAll( ('diffuse','specular','parallax') ) do(name as string):
			return kri.Ant.Inst.slotMetas.find('mat.'+name)
		super('g.make',
			(kri.Ant.Inst.units.texture, kri.Ant.Inst.units.bump), ms,
			(kri.shade.Object('/g/make_v'), kri.shade.Object('/g/make_f'))
			)
		t = kri.Texture( TextureTarget.Texture2DArray )
		buf.A[0].layer(t,0)	# diffuse color * texture
		buf.A[1].layer(t,1)	# specular color
		buf.A[2].layer(t,2)	# world space normal
		buf.mask = 0x7
	# resize
	public override def setup(far as kri.frame.Array) as bool:
		buf.init( far.getW, far.getH )
		buf.A[0].Tex.bind()
		fm = kri.Texture.AskFormat( kri.Texture.Class.Color, 8 )
		fm = PixelInternalFormat.Rgb10A2
		kri.Texture.InitArray(fm, far.getW, far.getH, 3)
		kri.Texture.Filter(false,false)
		return true
	# work	
	public override def process(con as Context) as void:
		con.needDepth(false)
		buf.A[-1].Tex = con.Depth
		buf.activate()
		con.SetDepth(0f, false)
		con.ClearColor()
		drawScene()


#---------	RENDER APPLY G-BUFFER	--------#

public class Apply( Basic ):
	public final gid	= kri.Ant.Inst.slotUnits.getForced('gbuf')
	protected final s0	= kri.shade.Smart()
	protected final sa	= kri.shade.Smart()
	private final gbuf	as kri.Texture
	private final context	as light.Context
	private final pArea	= kri.shade.par.Value[of OpenTK.Vector4]()
	# init
	public def constructor(gt as kri.Texture, lc as light.Context):
		super(false)
		gbuf,context = gt,lc
		# fill shader
		s0.add( 'copy_v', '/g/init_f' )
		s0.link( kri.Ant.Inst.slotAttributes, kri.Ant.Inst.dict )
		# light shader
		d = kri.shade.rep.Dict()
		d.add('area', pArea)
		pArea.Value = OpenTK.Vector4( 0f,0f,0f,1f )
		sa.add( '/g/apply_v', '/g/apply_f' )
		sa.link( kri.Ant.Inst.slotAttributes, d, lc.dict, kri.Ant.Inst.dict )
	# calculate
	private def setArea(l as kri.Light) as void:
		c = kri.Camera.Current
		scam = c.node.World
		sp = slit = l.node.World
		scam.inverse()
		sp.combine( slit, scam )
		p0 = c.project( sp.pos )
		p1 = OpenTK.Vector3( l.rangeOut, 0f,0f )
		p2 = sp.byPoint(p1)
		p1 = OpenTK.Vector3.Subtract( c.project(p2), p0 )
		pArea.Value = OpenTK.Vector4( p0, p1.LengthFast )
	# shadow 
	private def bindShadow(t as kri.Texture) as void:
		if t:
			t.bind()
			kri.Texture.Filter(false,false)
			kri.Texture.Shadow(false)
		else: context.defShadow.bind()
	# work
	public override def process(con as Context) as void:
		con.activate()
		u = kri.Ant.Inst.units
		u.Tex[ gid ] = gbuf
		u.Tex[ u.depth ] = con.Depth
		con.Depth.bind( u.depth )
		kri.Texture.Filter(false,false)
		kri.Texture.Shadow(false)
		# initial fill
		s0.use()
		kri.Ant.Inst.emitQuad()
		# add lights
		using blend = kri.Blender():
			blend.add()
			for l in kri.Scene.current.lights:
				setArea(l)
				kri.Texture.Slot( u.light )
				bindShadow( l.depth )
				l.apply()
				sa.use()
				kri.Ant.Inst.emitQuad()