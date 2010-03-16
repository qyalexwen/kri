namespace kri

import System
import System.Collections.Generic
import OpenTK
import OpenTK.Graphics


# Perspective projector for light & camera
public class Projector:
	public node		as Node
	public rangeIn	= 0f
	public rangeOut	= 100f
	public fov		= 0.4f	# ~23 degrees (half)
	public aspect	= 1f
	public def project(ref v as Vector3) as Vector3:
		dz = -1f / v.Z
		tn = dz / Math.Tan(fov)
		assert fov > 0f
		return Vector3(tn*v.X, aspect*tn*v.Y,
				(2f*dz*rangeIn*rangeOut - rangeIn-rangeOut) / (rangeIn - rangeOut))
	public def toWorld(ref vin as Vector3) as Vector3:
		v = Vector3.Add( Vector3.Multiply(vin,2f), Vector3.One )
		z = 2f*rangeIn*rangeOut / (v.Z*(rangeOut-rangeIn) - rangeOut - rangeIn)
		return Vector3(-z*v.X, -z*v.Y / aspect, z)
		

public class Camera(Projector):
	[property(Current)]
	public static current	as Camera = null


public class Light(Projector,IApplyable):
	# fov == 0 for omni type
	# fov < 0 for directional
	public softness	= 0f
	public color	= Color4(1f,1f,1f,1f)
	public energy	= 1f	# initial energy
	public quad1	= 0f	# linear factor
	public quad2	= 0f	# quadratic factor
	public sphere	= 0f	# spherical bound
	public depth	as Texture	= null
	# copy to state
	public def apply() as void:
		Ant.Inst.params.light.activate(self)
		Ant.Inst.params.lightProj.activate(self)
		Ant.Inst.params.lightView.activate(node)
	# parallel projection
	public def makeDirectional(radius as single) as void:
		fov = -2f / radius



public abstract class Shape:
	public virtual def collide(sh as Shape) as Vector3:
		return -sh.collide(self)

public class ShapeSphere(Shape):
	public center	as Vector3	= Vector3(0f,0f,0f)
	public radius	as single	= 0f
	public virtual def collide(sh as ShapeSphere) as Vector3:
		rez = sh.center - center
		kf = (sh.radius + radius) / rez.LengthFast
		return rez * Math.Max(0f,1f-kf)

# Physics atom
public class Body:
	public final node	as Node
	public final shape	as Shape
	public mass		= 0f
	public vLinear	= Vector3(0f,0f,0f)
	public vAngular	= Vector3(0f,0f,0f)
	public def constructor(n as Node, sh as Shape):
		node,shape = n,sh
	


# Scene that holds entities, lights & cameras
public class Scene:
	[getter(Current)]
	internal static current as Scene = null
	public final name		as string
	public final entities	= List[of Entity]()
	public final bodies		= List[of Body]()
	public final lights		= List[of Light]()
	public final cameras	= List[of Camera]()
	public final particles	= List[of part.Emitter]()
	public def constructor(str as string):
		name = str


# Renders a scene with camera to some buffer
public class View:
	# rendering
	public final con	as rend.Context	# context
	public ren			as rend.Basic	# root render
	# view
	public cam		as Camera	= null
	public scene	as Scene	= null

	public def constructor(buffer as frame.Screen, bc as uint, bd as uint):
		con = rend.Context(buffer,bc,bd)
	public def constructor(buffer as frame.Screen):
		con = rend.Context(buffer,0,0)
	public virtual def resize(wid as int, het as int) as bool:
		return ren.setup( con.resize(wid,het) )
	public def update() as void:
		Scene.current = scene
		if cam:
			cam.aspect = con.Aspect
			Ant.Inst.params.activate(cam)
		con.apply(ren)
		vb.Array.unbind()
		Scene.current = null


# View for rendering to screen
public class ViewScreen(View):
	public final area	= Box2(0f,0f,1f,1f)
	public final out	as frame.Screen
	public def constructor(bc as uint, bd as uint):
		out = frame.Screen()
		super( out, bc, bd )
	public override def resize(wid as int, het as int) as bool:
		return false if not super(wid,het)
		out.init	( cast(int, wid*area.Width),	cast(int, het*area.Height) )
		out.offset	( cast(int, wid*area.Left),		cast(int, het*area.Top) )
		return true