#!/usr/bin/env python3
"""Generate VetPilot's illustrated German Shepherd app icon with stdlib only.

The same 1024px artwork is written into the in-app ShepherdIcon image set and
AppIcon set so CI and local Xcode builds never depend on an external image API.
"""
from pathlib import Path
import math, random, struct, zlib, json

SIZE = 1024
ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "FergusonVetPilot" / "Resources" / "Assets.xcassets"
SHEPHERD = ASSETS / "ShepherdIcon.imageset" / "ShepherdIcon.png"
APPICON = ASSETS / "AppIcon.appiconset" / "AppIcon-1024.png"

pixels = bytearray(SIZE * SIZE * 3)

def clamp(v): return max(0, min(255, int(v)))

def put(x, y, color, alpha=1.0):
    if not (0 <= x < SIZE and 0 <= y < SIZE): return
    i = (y * SIZE + x) * 3
    if alpha >= 0.999:
        pixels[i:i+3] = bytes(color)
    else:
        pixels[i] = clamp(pixels[i] * (1-alpha) + color[0] * alpha)
        pixels[i+1] = clamp(pixels[i+1] * (1-alpha) + color[1] * alpha)
        pixels[i+2] = clamp(pixels[i+2] * (1-alpha) + color[2] * alpha)

def ellipse(cx, cy, rx, ry, color, alpha=1.0):
    y0=max(0,int(cy-ry)); y1=min(SIZE-1,int(cy+ry))
    for y in range(y0,y1+1):
        ny=(y-cy)/ry
        if abs(ny)>1: continue
        dx=rx*math.sqrt(max(0,1-ny*ny))
        for x in range(max(0,int(cx-dx)), min(SIZE-1,int(cx+dx))+1): put(x,y,color,alpha)

def triangle(a,b,c,color,alpha=1.0):
    minx=max(0,int(min(a[0],b[0],c[0]))); maxx=min(SIZE-1,int(max(a[0],b[0],c[0])))
    miny=max(0,int(min(a[1],b[1],c[1]))); maxy=min(SIZE-1,int(max(a[1],b[1],c[1])))
    def area(p1,p2,p3): return p1[0]*(p2[1]-p3[1])+p2[0]*(p3[1]-p1[1])+p3[0]*(p1[1]-p2[1])
    A=area(a,b,c)
    if A==0: return
    for y in range(miny,maxy+1):
        for x in range(minx,maxx+1):
            p=(x,y); w1=area(p,b,c); w2=area(a,p,c); w3=area(a,b,p)
            if (A>0 and w1>=0 and w2>=0 and w3>=0) or (A<0 and w1<=0 and w2<=0 and w3<=0): put(x,y,color,alpha)

def line(x0,y0,x1,y1,color,width=1,alpha=1.0):
    dx=x1-x0; dy=y1-y0; steps=max(abs(dx),abs(dy),1)
    for s in range(steps+1):
        x=round(x0+dx*s/steps); y=round(y0+dy*s/steps)
        r=max(0,width//2)
        for yy in range(y-r,y+r+1):
            for xx in range(x-r,x+r+1): put(xx,yy,color,alpha)

# Deep medical-blue radial background.
for y in range(SIZE):
    for x in range(SIZE):
        dx=(x-512)/700; dy=(y-480)/700; d=min(1, math.sqrt(dx*dx+dy*dy))
        glow=max(0,1-d)
        put(x,y,(12+int(8*glow),42+int(28*glow),86+int(54*glow)))

# Soft halo behind the face.
for r,alpha in [(395,.035),(360,.045),(325,.055)]: ellipse(512,510,r,r,(90,152,236),alpha)

# Ears: black-edged, tan inner ear, warm tissue center.
for flip in (-1,1):
    tip=(512+flip*278,92); outer1=(512+flip*142,345); outer2=(512+flip*325,363)
    triangle(tip,outer1,outer2,(43,35,31))
    triangle((512+flip*258,145),(512+flip*154,341),(512+flip*288,326),(180,111,55))
    triangle((512+flip*232,205),(512+flip*174,332),(512+flip*258,310),(86,52,47))

# Neck / chest.
ellipse(512,900,275,300,(174,111,51))
ellipse(512,910,182,290,(207,146,75))
triangle((305,760),(420,1024),(270,1024),(48,39,32))
triangle((719,760),(604,1024),(754,1024),(48,39,32))

# Head with layered warmth and natural taper.
ellipse(512,535,280,332,(190,124,58))
ellipse(512,545,248,305,(206,145,73),.95)
ellipse(512,600,230,245,(220,163,92),.65)
# forehead blaze
ellipse(512,390,88,190,(219,151,74),.85)

# German shepherd dark facial mask / temples.
ellipse(390,440,112,160,(48,40,33),.98)
ellipse(634,440,112,160,(48,40,33),.98)
triangle((326,375),(448,360),(455,545),(54,43,34),.95)
triangle((698,375),(576,360),(569,545),(54,43,34),.95)

# Cheek and muzzle cream highlights.
ellipse(375,610,105,138,(224,175,107),.75)
ellipse(649,610,105,138,(224,175,107),.75)
ellipse(512,676,150,126,(216,173,114),.98)
ellipse(512,625,104,135,(76,61,48),.98)

# Eyes, amber irises, glossy highlights, subtle lids.
for ex in (408,616):
    ellipse(ex,501,64,50,(33,29,25))
    ellipse(ex,507,40,39,(155,96,35))
    ellipse(ex,509,25,30,(20,18,16))
    ellipse(ex-10,493,9,12,(255,244,206))
    ellipse(ex+12,520,5,6,(240,191,109),.8)
    line(ex-55,463,ex+49,457,(69,49,34),8,.8)

# Nose + mouth details.
ellipse(512,724,87,66,(24,24,25))
ellipse(485,705,32,22,(112,116,119),.5)
ellipse(482,733,18,12,(5,5,6))
ellipse(542,733,18,12,(5,5,6))
line(512,776,512,801,(56,34,31),5)
line(512,801,470,818,(77,40,37),4)
line(512,801,554,818,(77,40,37),4)
ellipse(512,820,37,14,(165,83,81),.82)

# Collar and medical tag.
ellipse(512,872,192,48,(18,85,192),.98)
ellipse(512,873,150,27,(31,111,224),.7)
ellipse(512,925,51,51,(244,120,24))
# white medical cross
for y in range(900,950):
    for x in range(500,525): put(x,y,(250,250,250))
for y in range(912,938):
    for x in range(487,538): put(x,y,(250,250,250))

# Deterministic fur strokes: soft directional texture instead of flat polygons.
rng=random.Random(73021)
for _ in range(1350):
    x=rng.randint(285,739); y=rng.randint(250,835)
    # only strokes that land on non-background fur zones by approximate oval test
    nx=(x-512)/285; ny=(y-535)/340
    if nx*nx+ny*ny>1: continue
    if 360 < x < 455 and 390 < y < 575 or 569 < x < 664 and 390 < y < 575:
        base=(123,87,49)
    else:
        base=(246,194,117) if rng.random()<0.45 else (117,79,42)
    length=rng.randint(5,15); slant=rng.randint(-3,3)
    line(x,y,x+slant,y+length,base,rng.choice([1,1,2]),rng.uniform(.10,.27))

# Gentle vignette.
for y in range(SIZE):
    for x in range(SIZE):
        dx=(x-512)/620; dy=(y-512)/620; d=math.sqrt(dx*dx+dy*dy)
        if d>.72: put(x,y,(2,14,38), min(.42,(d-.72)*1.2))

# Encode RGB PNG.
raw=bytearray()
for y in range(SIZE):
    raw.append(0)
    s=y*SIZE*3; raw.extend(pixels[s:s+SIZE*3])

def chunk(kind,data):
    return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)

png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',SIZE,SIZE,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(raw),9))+chunk(b'IEND',b'')

SHEPHERD.parent.mkdir(parents=True, exist_ok=True)
APPICON.parent.mkdir(parents=True, exist_ok=True)
SHEPHERD.write_bytes(png)
APPICON.write_bytes(png)
(SHEPHERD.parent/'Contents.json').write_text(json.dumps({
    'images':[{'filename':'ShepherdIcon.png','idiom':'universal','scale':'1x'}],
    'info':{'author':'xcode','version':1}
}, indent=2)+'\n')
print(APPICON)
print(SHEPHERD)
