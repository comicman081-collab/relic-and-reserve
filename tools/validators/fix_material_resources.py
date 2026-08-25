from pathlib import Path
root=Path(__file__).resolve().parents[2]
colors={'wood_dark':(0.23,0.13,0.08),'wood_light':(0.55,0.32,0.14),'aged_wood':(0.35,0.25,0.16),'brass':(0.70,0.43,0.12),'tarnished_brass':(0.43,0.46,0.35),'steel':(0.47,0.51,0.55),'rusted_steel':(0.49,0.22,0.12),'painted_metal':(0.16,0.24,0.28),'aged_paint':(0.28,0.33,0.29),'black_leather':(0.04,0.05,0.06),'brown_leather':(0.31,0.16,0.11),'glass':(0.18,0.43,0.50),'ceramic':(0.70,0.58,0.40),'paper':(0.72,0.62,0.44),'rubber':(0.04,0.05,0.06)}
for name,c in colors.items():
    p=root/'assets/materials'/f'{name}.tres'; p.write_text(f'''[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nalbedo_color = Color({c[0]}, {c[1]}, {c[2]}, 1)\nmetallic = {0.2 if "brass" in name or name in ["steel","rusted_steel","painted_metal"] else 0.0}\nroughness = {0.78 if "wood" in name else 0.55}\n''')
print(f'fixed {len(colors)} Godot material resources')
