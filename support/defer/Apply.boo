﻿namespace support.defer

import OpenTK.Graphics.OpenGL
import kri.shade

#---------	DEFERRED BASE APPLY		--------#

public class ApplyBase( kri.rend.Basic ):
	protected	final	bu		= Bundle()
	private		texDepth		as par.Texture	= null
	public		initOnly		= false
	# custom activation
	private virtual def onInit() as void:
		pass
	private virtual def onDraw() as void:
		pass
	# link
	protected def relink(con as Context) as void:
		texDepth = con.texDepth
		bu.dicts.Add( con.dict )
		bu.shader.add( '/lib/quat_v','/lib/tool_v','/lib/defer_f','/lib/math_f' )
		bu.shader.add( con.sh_apply, con.sh_diff, con.sh_spec )
		bu.link()
	# work
	public override def process(con as kri.rend.link.Basic) as void:
		texDepth.Value = con.Depth
		con.activate(false)
		onInit()
		if initOnly:	return
		# enable depth check
		con.activate( con.Target.Same, 0f, false )
		GL.CullFace( CullFaceMode.Front )
		GL.DepthFunc( DepthFunction.Gequal )
		# add lights
		using blend = kri.Blender():
			blend.add()
			onDraw()
		GL.CullFace( CullFaceMode.Back )
		GL.DepthFunc( DepthFunction.Lequal )


#---------	DEFERRED STANDARD APPLY		--------#

public class Apply( ApplyBase ):
	private final bv		= Bundle()
	private final texLit	= par.Value[of kri.buf.Texture]('light')
	private final context	as support.light.Context
	private final sphere	as kri.gen.Frame
	private final cone		as kri.gen.Frame
	# init
	public def constructor(lc as support.light.Context, con as Context):
		super()
		sphere = con.sphere
		cone = con.cone
		context = lc
		bu.shader.add('/g/apply_v')
		relink(con)
		# fill shader
		bv.shader.add( '/copy_v', '/g/init_f' )
		bv.dicts.Add( con.dict )
	# shadow
	private def bindShadow(t as kri.buf.Texture) as void:
		if t:
			texLit.Value = t
			t.filt(false,false)
			t.shadow(false)
		else:
			texLit.Value = context.defShadow
	# work
	private override def onInit() as void:
		kri.Ant.Inst.quad.draw(bv)
	private override def onDraw() as void:
		scene = kri.Scene.Current
		if not scene:	return
		for l in scene.lights:
			bindShadow( l.depth )
			kri.Ant.Inst.params.activate(l)
			sphere.draw(bu)
