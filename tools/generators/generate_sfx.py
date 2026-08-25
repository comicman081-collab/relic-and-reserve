from pathlib import Path
import math, wave, struct
root=Path(__file__).resolve().parents[2]
out=root/'audio'; out.mkdir(exist_ok=True)
names=['brush','cloth','metal_click','screw','drawer','cabinet','camera_shutter','scanner','purchase','ui_click','ui_hover','auction_bid','auction_hammer','sale_success','warning','packaging','box','tool_pick','object_place','coin_cue']
for i,name in enumerate(names):
    path=out/f'{name}.wav'; rate=22050; duration=0.16+(i%4)*0.04; freq=180+(i%8)*55
    with wave.open(str(path),'w') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        for n in range(int(rate*duration)):
            t=n/rate; env=max(0.0,1.0-t/duration); sample=math.sin(2*math.pi*freq*t)*env*0.22
            if i%3==0: sample += math.sin(2*math.pi*(freq*1.7)*t)*env*0.08
            w.writeframes(struct.pack('<h',int(max(-1,min(1,sample))*32767)))
print(f'generated {len(names)} procedural WAV cues')
