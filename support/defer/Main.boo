﻿namespace support.defer

import OpenTK.Graphics.OpenGL
import kri.shade

#---------	CONTEXT	--------#

public class Context:
	public final buf		= kri.buf.Holder( mask:7 )
	public final sphere		as kri.gen.Frame
	public final cone		as kri.gen.Frame
	public final dict		= par.Dict()
	public final texDepth	= par.Texture('depth')
	public final sh_diff	= Object.Load('/mod/lambert_f')
	public final sh_spec	= Object.Load('/mod/phong_f')
	public final sh_apply	= Object.Load('/g/apply_f')
	
	public def constructor(qord as byte, ncone as byte):
		# light volumes
		sh = kri.gen.Sphere( qord,	OpenTK.Vector3.One )
		sphere	= kri.gen.Frame(sh)
		cn = kri.gen.Cone( ncone,	OpenTK.Vector3.One )
		cone	= kri.gen.Frame(cn)
		# dictionary
		dict.unit(texDepth)
		# diffuse, specular, world space normal
		for i in range(3):
			pt = par.Texture('g'+i)
			tex = kri.buf.Texture(0, PixelInternalFormat.Rgba8, PixelFormat.Rgba )
			buf.at.color[i] = pt.Value = tex
			pt.Value.filt(false,false)
			dict.unit(pt)


#---------	GROUP	--------#

public class BugLayer( kri.rend.Basic ):
	public	final fbo	as kri.buf.Holder
	public	layer		as int	= -1
	public def constructor(con as Context):
		fbo = con.buf
	public override def process(link as kri.rend.link.Basic) as void:
		if layer<0: return
		link.activate(false)
		fbo.mask = 1<<layer
		fbo.copyTo( link.Frame, ClearBufferMask.ColorBufferBit )


#---------	GROUP	--------#

public class Group( kri.rend.Group ):
	public	final	con			as Context
	public	final	rFill		as fill.Fork	= null
	public	final	rLayer		as layer.Fill	= null
	public	final	rApply		as Apply		= null
	public	final	rParticle	as Particle		= null
	public	final	rBug		as BugLayer		= null
	public	Layered	as bool:
		get: return rLayer.active
		set:
			rLayer.active = value
			rFill.active = not value
	
	public def constructor(qord as byte, ncone as uint, lc as support.light.Context, pc as kri.part.Context):
		con = cx = Context(qord,ncone)
		rFill	= fill.Fork(cx)
		rLayer	= layer.Fill(cx)
		rl = List[of kri.rend.Basic]()
		rl.Extend(( rFill, rLayer ))
		if lc:
			rApply = Apply(lc,cx)
			rl.Add(rApply)
		if pc:
			rParticle = Particle(pc,cx)
			rl.Add(rParticle)
		rBug = BugLayer(cx)
		rl.Add(rBug)
		if not 'DebugTexture':
			pt = kri.shade.par.UnitProxy() do():
				return cx.buf.at.color[0] as kri.buf.Texture
			rMapX = kri.rend.debug.Map(false,false,0,pt)
			rl.Add(rMapX)
		super( *rl.ToArray() )
