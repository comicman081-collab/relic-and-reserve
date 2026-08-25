from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[2]; subprocess.run([sys.executable,str(root/"tools/validators/enrich_low_poly_meshes.py")],check=True); print("procedural R2 asset pack rebuilt")
