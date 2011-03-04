﻿namespace kri.buf

import System
import OpenTK
import OpenTK.Graphics.OpenGL


public class Texture(Surface):
	private final	hardId	as uint
	private static	boundId	as uint	= 0
	private			ready	= false
	public			intFormat	as PixelInternalFormat
	public			pixFormat	as PixelFormat
	public			dep		as uint	= 0
	public			target	= TextureTarget.Texture2D
	
	public def constructor():
		hardId = GL.GenTexture()
	private def constructor(manId as uint):
		hardId = manId
	public static final	Zero	= Texture(0)
	def destructor():
		kri.Help.safeKill() do():
			GL.DeleteTexture(hardId)
	
	public static def Slot(tun as byte) as void:
		GL.ActiveTexture( TextureUnit.Texture0 + tun )
	public static def ResetCache() as void:
		boundId = 0
		
	# virtual routines

	public override def attachTo(fa as FramebufferAttachment) as void:
		init(0)	if not ready
		assert ready
		GL.FramebufferTexture2D( FramebufferTarget.Framebuffer, fa, TextureTarget.Texture2D, hardId, 0 )

	public override def bind() as void:
		return	if boundId == hardId
		boundId = hardId
		GL.BindTexture( target, hardId )
	
	public override def syncBack() as void:
		bind()
		vals = (of int:0,0,0,0)
		pars = (
			GetTextureParameter.TextureWidth,
			GetTextureParameter.TextureHeight,
			GetTextureParameter.TextureSamples,
			GetTextureParameter.TextureInternalFormat)
		for i in range(vals.Length):
			GL.GetTexParameterI( target, pars[i], vals[i] )
		wid,het,samples = vals[0:3]
		intFormat = cast(PixelInternalFormat,vals[3])

	# initialization routines
	
	public def init(sif as SizedInternalFormat, buf as kri.vb.Object) as void:
		target = TextureTarget.TextureBuffer
		bind()
		ready = true
		GL.TexBuffer( TextureBufferTarget.TextureBuffer, sif, buf.Extract )
		syncBack()
	
	public def init(level as byte) as void:
		if samples:
			initMulti( level>0 )
		else:
			init[of byte]( level, null )
	
	public def initMulti(fixedLoc as bool) as void:
		bind()
		caps = kri.Ant.Inst.caps
		assert samples and samples <= caps.multiSamples
		assert wid <= caps.textureSize
		assert het <= caps.textureSize
		assert dep <= caps.textureSize
		tams = cast( TextureTargetMultisample, cast(int,target) )
		ready = true
		if dep:
			assert target == TextureTarget.Texture2DMultisampleArray	
			GL.TexImage3DMultisample( tams, samples, intFormat, wid, het, dep, fixedLoc )
		else:
			assert target == TextureTarget.Texture2DMultisample
			GL.TexImage2DMultisample( tams, samples, intFormat, wid, het, fixedLoc )
	
	public def GetPixelType(t as Type) as PixelType:
		return PixelType.UnsignedByte	if t==byte
		return PixelType.UnsignedShort	if t==ushort
		return PixelType.UnsignedInt	if t==uint
		return PixelType.HalfFloat		if t in (Vector2h,Vector3h,Vector4h)
		return PixelType.Float			if t in (single,Vector2,Vector3,Vector4)
		assert not 'good type'
		return PixelType.Bitmap
	
	private def setImage[of T(struct)](tg as TextureTarget, level as byte, data as (T)) as void:
		assert not samples
		caps = kri.Ant.Inst.caps
		assert wid <= caps.textureSize
		assert het <= caps.textureSize
		assert dep <= caps.textureSize
		ready = true
		pt = GetPixelType(T)
		if dep:
			GL.TexImage3D( tg, level, intFormat, wid, het, dep,	0, pixFormat, pt, data )
		elif het:
			GL.TexImage2D( tg, level, intFormat, wid, het, 		0, pixFormat, pt, data )
		else:
			GL.TexImage1D( tg, level, intFormat, wid, 	 		0, pixFormat, pt, data )
	
	public def init[of T(struct)](level as byte, data as (T)) as void:
		bind()
		setImage(target,level,data)
	
	public def initCube[of T(struct)](side as int, level as byte, data as (T)) as void:
		bind()
		tArray = (
			TextureTarget.TextureCubeMapNegativeX, TextureTarget.TextureCubeMapNegativeY, TextureTarget.TextureCubeMapNegativeZ,
			TextureTarget.Texture1D,	# dummy corresponding side==0
			TextureTarget.TextureCubeMapPositiveX, TextureTarget.TextureCubeMapPositiveY, TextureTarget.TextureCubeMapPositiveZ)
		assert side and side>=-3 and side<=3
		setImage( tArray[side+3], level, data )
	
	public def initCube() as void:
		bind()
		for t in (
			TextureTarget.TextureCubeMapNegativeX,	TextureTarget.TextureCubeMapPositiveX,
			TextureTarget.TextureCubeMapNegativeY,	TextureTarget.TextureCubeMapPositiveY,
			TextureTarget.TextureCubeMapNegativeZ,	TextureTarget.TextureCubeMapPositiveZ):
			setImage[of byte]( t, 0, null )

	# state routines
	
	# set filtering mode: point/linear
	public def filt(mode as bool, mips as bool) as void:
		vMin as TextureMinFilter
		vMag = (TextureMagFilter.Nearest,TextureMagFilter.Linear)[mode]
		vmi0 = (TextureMinFilter.Nearest,TextureMinFilter.Linear)
		vmi1 = (TextureMinFilter.NearestMipmapNearest,TextureMinFilter.LinearMipmapLinear)
		vMin = (vmi0,vmi1)[mips][mode]
		val = (of int: cast(int,vMin), cast(int,vMag))
		bind()
		GL.TexParameter( target, TextureParameterName.TextureMinFilter, val[0] )
		GL.TexParameter( target, TextureParameterName.TextureMagFilter, val[1] )
	
	# set wrapping mode: clamp/repeat
	public def wrap(mode as TextureWrapMode, dim as int) as void:
		val = cast(int,mode)
		wraps = (TextureParameterName.TextureWrapS, TextureParameterName.TextureWrapT, TextureParameterName.TextureWrapR)
		assert dim>=0 and dim<wraps.Length
		bind()
		for wp in wraps[0:dim]:
			GL.TexParameterI(target, wp, val)

	# set shadow mode: on/off
	public def shadow(en as bool) as void:
		param = 0
		bind()
		if en:
			param = cast(int, TextureCompareMode.CompareRefToTexture)
			func = cast(int, DepthFunction.Lequal)
			GL.TexParameterI( target, TextureParameterName.TextureCompareFunc, func )
		if 'always':
			GL.TexParameterI( target, TextureParameterName.TextureCompareMode, param )
		
	# generate mipmaps
	public def genLevels() as byte:
		assert target != TextureTarget.TextureRectangle
		assert not samples
		ti = cast(GenerateMipmapTarget, cast(int,target))
		bind()
		GL.GenerateMipmap(ti)
		num as int = 0
		GL.GetTexParameterI( target, GetTextureParameter.TextureMaxLod, num )
		return System.Math.Min(0xFF,num+1)
	
	# init all state
	public def setState(wrap as int, fl as bool, mips as bool) as void:
		wm = (TextureWrapMode.MirroredRepeat, TextureWrapMode.ClampToBorder, TextureWrapMode.Repeat)[wrap+1]
		bind()
		wrap(wm,2)
		filt(fl,mips)
		genLevels()	if mips
	
	# select a range of LODs to sample from
	public def setLevels(a as int, b as int) as void:
		bind()
		GL.TexParameterI( target, TextureParameterName.TextureBaseLevel, a )	if a>=0
		GL.TexParameterI( target, TextureParameterName.TextureMaxLevel, b )		if b>=0