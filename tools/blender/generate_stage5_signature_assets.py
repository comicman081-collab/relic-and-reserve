"""Generate the Stage 5 pocket-sextant mesh with Blender in background mode."""

from __future__ import annotations

import math
from pathlib import Path

import bpy


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets" / "artifacts" / "sextant.obj"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def material(name: str, color: tuple[float, float, float, float], metallic: float, roughness: float):
    value = bpy.data.materials.new(name)
    value.diffuse_color = color
    value.metallic = metallic
    value.roughness = roughness
    return value


def finish_object(obj: bpy.types.Object, name: str, mat: bpy.types.Material, bevel: float = 0.025) -> bpy.types.Object:
    obj.name = name
    obj.data.materials.append(mat)
    if bevel > 0.0:
        modifier = obj.modifiers.new(name="SoftLowPolyEdges", type="BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def box(
    name: str,
    location: tuple[float, float, float],
    size: tuple[float, float, float],
    rotation_z: float,
    mat,
    bevel: float | None = None,
):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=(0.0, 0.0, rotation_z))
    obj = bpy.context.object
    obj.scale = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish_object(obj, name, mat, min(size) * 0.16 if bevel is None else bevel)


def cylinder(
    name: str,
    location: tuple[float, float, float],
    radius: float,
    depth: float,
    rotation: tuple[float, float, float],
    mat,
    vertices: int = 20,
):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    return finish_object(bpy.context.object, name, mat, 0.012)


def build_sextant() -> None:
    brass = material("SextantBrass", (0.58, 0.35, 0.10, 1.0), 0.68, 0.30)
    ivory = material("ScaleIvory", (0.78, 0.72, 0.52, 1.0), 0.20, 0.42)
    teal = material("MirrorTeal", (0.08, 0.26, 0.30, 1.0), 0.30, 0.20)
    dark = material("GripDark", (0.12, 0.13, 0.12, 1.0), 0.12, 0.66)

    center_x, center_z = 0.0, 0.05
    radius = 1.05
    arc_angles = [math.radians(205.0 + step * 10.0) for step in range(14)]
    for index, angle in enumerate(arc_angles):
        x = center_x + math.cos(angle) * radius
        z = center_z + math.sin(angle) * radius
        box(
            f"GraduatedArc_{index:02d}",
            (x, 0.0, z),
            (0.25, 0.16, 0.12),
            angle + math.pi * 0.5,
            ivory if index % 3 == 0 else brass,
        )

    pivot = (0.0, 0.0, 0.98)
    left_end = (math.cos(arc_angles[0]) * radius, 0.0, center_z + math.sin(arc_angles[0]) * radius)
    right_end = (math.cos(arc_angles[-1]) * radius, 0.0, center_z + math.sin(arc_angles[-1]) * radius)
    for name, end in (("LeftFrame", left_end), ("RightFrame", right_end), ("IndexArm", (0.0, 0.0, center_z - radius))):
        dx = end[0] - pivot[0]
        dz = end[2] - pivot[2]
        length = math.hypot(dx, dz)
        angle = math.atan2(dz, dx)
        box(name, ((pivot[0] + end[0]) * 0.5, 0.0, (pivot[2] + end[2]) * 0.5), (length, 0.13, 0.105), angle, brass)

    cylinder("IndexMirror", (0.0, -0.01, 0.98), 0.22, 0.10, (math.pi * 0.5, 0.0, 0.0), teal, 24)
    cylinder("HorizonMirror", (-0.50, -0.01, 0.48), 0.16, 0.09, (math.pi * 0.5, 0.0, 0.0), teal, 20)
    cylinder("PivotCap", (0.0, -0.08, 0.98), 0.09, 0.20, (math.pi * 0.5, 0.0, 0.0), ivory, 20)

    cylinder("TelescopeTube", (-0.10, 0.02, 0.48), 0.105, 1.28, (0.0, math.pi * 0.5, 0.0), dark, 18)
    cylinder("TelescopeBrassCollar", (-0.64, 0.02, 0.48), 0.14, 0.16, (0.0, math.pi * 0.5, 0.0), brass, 18)
    cylinder("TelescopeEyepiece", (0.58, 0.02, 0.48), 0.13, 0.16, (0.0, math.pi * 0.5, 0.0), ivory, 18)

    box("VernierCarriage", (0.0, -0.06, -0.97), (0.44, 0.22, 0.18), 0.0, ivory)
    box("VernierPointer", (0.0, -0.05, -0.60), (0.10, 0.18, 0.58), 0.0, brass)
    box("HandGrip", (0.72, 0.02, -0.12), (0.24, 0.26, 0.72), math.radians(-16.0), dark)
    box("HandGripCap", (0.81, 0.02, 0.22), (0.30, 0.29, 0.12), math.radians(-16.0), brass)

    # A short, visibly different wear sector makes the authored 30-degree clue legible.
    for index, angle in enumerate(arc_angles[8:11]):
        x = center_x + math.cos(angle) * (radius + 0.02)
        z = center_z + math.sin(angle) * (radius + 0.02)
        box(f"ThirtyDegreeWear_{index}", (x, -0.10, z), (0.24, 0.05, 0.055), angle + math.pi * 0.5, teal, bevel=0.0)


def export_obj() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.wm.obj_export(
        filepath=str(OUTPUT),
        export_selected_objects=True,
        export_materials=False,
        forward_axis="NEGATIVE_Z",
        up_axis="Y",
    )


def main() -> None:
    clear_scene()
    build_sextant()
    export_obj()
    print(f"STAGE5_SEXTANT_GENERATED {OUTPUT}")


if __name__ == "__main__":
    main()
