from pathlib import Path
root=Path(__file__).resolve().parents[2]; out=root/'assets/materials/generated_materials_r2.tres'; out.write_text('[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nalbedo_color = Color("#7d5a32")\nroughness = 0.7\n'); print(out)
