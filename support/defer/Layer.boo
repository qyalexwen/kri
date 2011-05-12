﻿namespace support.defer.layer

import System.Collections.Generic
import OpenTK
import OpenTK.Graphics.OpenGL
import kri.shade


public class Fill( kri.rend.tech.General ):
	public	shadeUnits		= true
	private final	fbo		as kri.buf.Holder
	private final	factory	= kri.shade.Linker(onLink)
	private	mesh	as kri.Mesh		= null
	private	vDict	as kri.vb.Dict	= null
	private final	din		= Dictionary[of string,kri.meta.Hermit]()
	private	final	sVert	= Object.Load('/g/layer/pass_v')
	private final	sFrag	= Object.Load('/g/layer/pass_f')
	private final	fout	= ('c_diffuse','c_specular','c_normal')
	# params
	private final	pDic	= par.Dict()
	private final	pZero	= par.Value[of single]('zero')
	private final	pTex	= par.Texture('texture')
	private final	pColor	= par.Value[of Vector4]('user_color')
	private final	mDiff	= par.Value[of Vector4]('mask_diffuse')
	private final	mSpec	= par.Value[of Vector4]('mask_specular')
	private final	mNorm	= par.Value[of Vector4]('mask_normal')

	# init
	public def constructor(con as support.defer.Context):
		super('g.layer.fill')
		fbo = con.buf
		pDic.var(pColor,mDiff,mSpec,mNorm)
		pDic.var(pZero)
		pDic.unit(pTex)
	
	private def onLink(sa as Mega) as void:
		sa.fragout(*fout)
	
	private def setBlend(str as string) as bool:
		GL.BlendEquation( BlendEquationMode.FuncAdd )
		if str == '':
			pZero.Value = 0f
			GL.BlendFunc( BlendingFactorSrc.One, BlendingFactorDest.Zero )
		elif str == 'MIX':
			pZero.Value = 1f
			GL.BlendFunc( BlendingFactorSrc.DstColor, BlendingFactorDest.Zero )
		elif str == 'ADD':
			pZero.Value = 0f
			GL.BlendFunc( BlendingFactorSrc.One, BlendingFactorDest.One )
		else:	return false
		return true
	
	private def setParams(app as kri.meta.UnitApp) as void:
		mDiff.Value = Vector4(0f)
		mSpec.Value = Vector4(0f)
		mNorm.Value = Vector4(0f)
		for inf in app.affects:
			if inf == 'color_diffuse':
				mDiff.Value.Xyz = Vector3(1f)
			if inf == 'color_spec':
				mSpec.Value.Xyz = Vector3(1f)
			if inf == 'normal':
				app.blend = ''
				break
		c = app.color
		flag = (0f,1f)[app.doIntencity]
		pColor.Value = Vector4( c.R, c.G, c.B, flag )

	# construct
	public override def construct(mat as kri.Material) as Bundle:
		bu = Bundle()
		bu.dicts.Add( mat.dict )
		sa = bu.shader
		sa.add( *kri.Ant.Inst.libShaders )
		sa.add( '/g/layer/make_v', '/g/layer/make_f' )
		sa.fragout(*fout)
		return bu
	
	# draw
	protected override def onPass(va as kri.vb.Array, tm as kri.TagMat, bu as Bundle) as void:
		if not mesh.render( va, bu, vDict, tm.off, tm.num, 1, null ):
			return
		if not shadeUnits:	return
		GL.Enable( EnableCap.Blend )
		for un in tm.mat.unit:
			app = un.application
			if not un.input:	continue
			if not app.prog:
				uname = 'unit'
				din[uname] = un.input
				mapins = kri.load.Meta.MakeTexCoords(false,din)
				if mapins:
					(un as kri.meta.ISlave).link(uname,pDic)	# add offset and scale under proper names
					(un.input as kri.meta.IBase).link(pDic)		# add input-specific data
					sall = List[of Object](mapins)
					sall.AddRange(( sVert, sFrag, un.input.Shader ))	# core shaders
					sall.AddRange( kri.Ant.Inst.libShaders )			# standard shaders
					app.prog = factory.link( sall, pDic )	# generate program
				else:	app.prog = Bundle.Empty
			if app.prog and app.prog.Failed:
				continue
			pTex.Value = un.Value
			setParams(app)
			if not setBlend( app.blend ):
				kri.lib.Journal.Log("Blend: unknown mode (${app.blend})")
				app.blend = ''
			mesh.render( va, app.prog, vDict, tm.off, tm.num, 1, null )
		GL.Disable( EnableCap.Blend )

	# resize
	public override def setup(pl as kri.buf.Plane) as bool:
		fbo.resize( pl.wid, pl.het )
		return super(pl)

	# work	
	public override def process(link as kri.rend.link.Basic) as void:
		fbo.at.depth = link.Depth
		fbo.bind()
		link.SetDepth(0f, false)
		link.ClearColor()
		scene = kri.Scene.Current
		if not scene:	return
		for e in scene.entities:
			kri.Ant.Inst.params.activate(e)
			vDict = e.CombinedAttribs
			mesh = e.mesh
			addObject(e)
