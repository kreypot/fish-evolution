"""Python port of FishArt.draw_fish (species part) to preview every fish without running Godot.
Mirrors scripts/fish_art.gd. Only used for checking the shapes; not part of the game."""
import math, re, sys
from PIL import Image, ImageDraw, ImageFont

SS = 3

def parse_species(path):
    src = open(path).read()
    out = []
    for m in re.finditer(r'\{"id": "(sp_[a-z]+)", "cat": "species", "name": "([^"]+)", "price": (\d+), "body": Color\("(#\w+)"\), "belly": Color\("(#\w+)"\), "fin": Color\("(#\w+)"\), "spec": (\{.*?\})\}', src):
        spec = eval(m.group(7).replace("true", "True").replace("false", "False"))
        out.append(dict(id=m.group(1), name=m.group(2), price=int(m.group(3)), body=m.group(4), belly=m.group(5), fin=m.group(6), spec=spec))
    return out

def hexc(h, a=255):
    h = h.lstrip('#'); return (int(h[0:2],16), int(h[2:4],16), int(h[4:6],16), a)
def darken(c, f): return (int(c[0]*(1-f)), int(c[1]*(1-f)), int(c[2]*(1-f)), c[3])
def lighten(c, f): return (int(c[0]+(255-c[0])*f), int(c[1]+(255-c[1])*f), int(c[2]+(255-c[2])*f), c[3])

class Cv:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w*SS, h*SS), (0,0,0,0))
    def _layer(self, fn, col):
        if col[3] == 255:
            fn(ImageDraw.Draw(self.img), col)
        else:
            lay = Image.new("RGBA", self.img.size, (0,0,0,0)); fn(ImageDraw.Draw(lay), col)
            self.img = Image.alpha_composite(self.img, lay)
    def poly(self, pts, col): self._layer(lambda d,c: d.polygon([(x*SS,y*SS) for x,y in pts], fill=c), col)
    def line(self, a, b, col, w): self._layer(lambda d,c: d.line([(a[0]*SS,a[1]*SS),(b[0]*SS,b[1]*SS)], fill=c, width=max(1,int(w*SS))), col)
    def circle(self, p, r, col): self._layer(lambda d,c: d.ellipse([(p[0]-r)*SS,(p[1]-r)*SS,(p[0]+r)*SS,(p[1]+r)*SS], fill=c), col)
    def arc(self, p, r, a0, a1, col, w): self._layer(lambda d,c: d.arc([(p[0]-r)*SS,(p[1]-r)*SS,(p[0]+r)*SS,(p[1]+r)*SS], math.degrees(a0), math.degrees(a1), fill=c, width=max(1,int(w*SS))), col)

def tri(cv, o, a, b, d, col):
    cv.poly([(o[0]+a[0], o[1]+a[1]), (o[0]+b[0], o[1]+b[1]), (o[0]+d[0], o[1]+d[1])], col)

def body_points(kind, s, mul, bx, by):
    pts = []
    if kind == 4:
        for x,y in [(1.0,0.0),(0.2,0.55),(-0.7,1.0),(-1.0,0.12),(-1.0,-0.12),(-0.7,-1.0),(0.2,-0.55)]: pts.append((x*bx*s*mul, y*by*s*mul))
    elif kind == 3:
        raw = [(1.45,0.0),(0.9,0.3),(0.2,0.42),(-0.6,0.3),(-1.1,0.08),(-1.1,-0.08),(-0.6,-0.3),(0.2,-0.42),(0.9,-0.3)]
        sx, sy = bx/1.4, by/0.42
        for x,y in raw: pts.append((x*sx*s*mul, y*sy*s*mul))
    else:
        for i in range(24):
            a = math.tau*i/24; pts.append((math.cos(a)*bx*s*mul, math.sin(a)*by*s*mul))
    return pts

def oval(cx, cy, rx, ry, n=14):
    return [(cx+math.cos(math.tau*i/n)*rx, cy+math.sin(math.tau*i/n)*ry) for i in range(n)]

def draw_fish(cv, o, s, kind, body, belly, fin, wag, mouth, stage, pattern, spec):
    if "base" in spec: kind = spec["base"]
    bx, by = 1.0, 0.62
    if kind == 1: bx, by = 1.2, 0.4
    elif kind == 2: bx, by = 0.95, 0.85
    elif kind == 3: bx, by = 1.4, 0.42
    elif kind == 4: bx, by = 1.0, 0.85
    bx = spec.get("bx", bx); by = spec.get("by", by)
    tail_kind = spec.get("tail","fork"); dorsal_kind = spec.get("dorsal","auto"); nose_kind = spec.get("nose","none")
    fin_scale = spec.get("fin_scale",1.0); eye_scale = spec.get("eye",1.0)
    nose_x = 1.45*s if kind == 3 else bx*s
    P = lambda x,y: (o[0]+x, o[1]+y)
    tw = wag*0.3*s
    spread, tip_mul, notch_mul = 0.62, 1.0, 0.82
    if tail_kind == "crescent": tip_mul, spread, notch_mul = 1.05, 0.85, 0.55
    elif tail_kind == "fan": tip_mul, spread, notch_mul = 0.95, 0.7, 1.08
    elif tail_kind == "fluke": tip_mul, spread, notch_mul = 0.95, 0.9, 0.7
    tip_x = -1.55*bx*s*tip_mul
    if tail_kind == "whip":
        cv.line(P((-0.95 if kind == 4 else -0.6)*bx*s,0), P(-2.2*bx*s,tw), fin, max(3.0,s*0.12))
    else:
        top=(tip_x,-spread*s+tw); bot=(tip_x,spread*s+tw); notch=(tip_x*notch_mul,tw*0.6)
        bt=(-0.7*bx*s,-0.14*s); bb=(-0.7*bx*s,0.14*s)
        tri(cv,o,bt,top,notch,fin); tri(cv,o,bb,bot,notch,fin); tri(cv,o,bt,notch,bb,fin)
    dm = 0.35+0.28*stage
    if kind == 3: dm = 0.9
    elif kind == 2: dm = 0.0
    dm = {"none":0.0,"tall":1.0,"sail":0.9,"hook":0.6}.get(dorsal_kind, dm)
    if dm > 0:
        ty = -by*s*0.85
        if dorsal_kind == "sail": tri(cv,o,(-0.7*bx*s,ty),(-0.2*bx*s,ty-dm*s),(0.5*bx*s,ty),fin)
        elif dorsal_kind == "hook": tri(cv,o,(-0.1*bx*s,ty),(-0.55*bx*s,ty-dm*s),(0.3*bx*s,ty),fin)
        else: tri(cv,o,(-0.5*bx*s,ty),(-0.2*bx*s,ty-dm*s),(0.35*bx*s,ty),fin)
    if spec.get("anal"):
        b2 = by*s*0.85; tri(cv,o,(-0.5*bx*s,b2),(-0.25*bx*s,b2+0.95*s),(0.3*bx*s,b2),fin)
    if nose_kind == "bill": cv.line(P(nose_x*0.9,0),P(nose_x+1.15*s,-0.02*s),darken(fin,0.1),max(3,s*0.13))
    elif nose_kind == "tusk": cv.line(P(nose_x*0.92,-0.04*s),P(nose_x+1.0*s,-0.22*s),(245,240,217,255),max(3,s*0.1))
    if kind == 2:
        for i in range(12):
            a = math.tau*i/12; p0=(math.cos(a)*bx*s, math.sin(a)*by*s)
            cv.line(P(*p0),P(p0[0]*1.28,p0[1]*1.28),fin,max(2,s*0.09))
    cv.poly([P(*p) for p in body_points(kind,s,1.08,bx,by)], darken(fin,0.2))
    bp = body_points(kind,s,1.0,bx,by)
    cv.poly([P(*p) for p in bp], body)
    lower = bp[0:5] if kind == 3 else (bp[0:4] if kind == 4 else bp[0:13])
    cv.poly([P(*p) for p in lower], belly)
    if nose_kind == "hammer":
        cv.poly([P(*p) for p in oval(nose_x*0.86,0,0.31*s,0.86*s)], darken(fin,0.2))
        cv.poly([P(*p) for p in oval(nose_x*0.86,0,0.26*s,0.8*s)], body)
    if spec.get("bands"):
        for xo in (-0.5,0.0,0.5):
            yb = by*s*math.sqrt(max(0,1-xo*xo))*0.9; bpx = xo*bx*s; bw = max(3,s*0.2)
            cv.line(P(bpx,-yb),P(bpx,yb),(26,26,31,255),bw*1.45); cv.line(P(bpx,-yb),P(bpx,yb),(255,255,255,255),bw)
    if spec.get("patch"): cv.poly([P(*p) for p in oval(0.2*bx*s,-by*s*0.5,0.3*s,0.13*s)], (255,255,255,255))
    if kind != 3:
        if pattern == 2:
            for sx,sy in [(-0.2,-0.22),(0.1,0.12),(0.38,-0.14),(-0.5,0.1),(0.0,-0.02),(0.55,0.14)]:
                cv.circle(P(sx*bx*s, sy*by*s*1.4), max(1.5,s*0.09), (fin[0],fin[1],fin[2],190))
        elif pattern >= 3:
            sc = (255,217,77,242) if pattern == 4 else (fin[0],fin[1],fin[2],204)
            for row in range(-1,2):
                for col in range(-3,4):
                    px = (col*0.27 + (0.135 if row%2 != 0 else 0.0))*bx*s; py = row*0.3*by*s*1.3
                    nx, ny = px/(bx*s*0.82), py/(by*s*0.82)
                    if nx*nx+ny*ny < 1: cv.arc(P(px,py), max(2,s*0.13), 0.6*math.pi, 1.4*math.pi, sc, max(1.2,s*0.04))
    if kind != 4:
        tri(cv,o,(0.15*bx*s,0.18*s),(-0.45*bx*s*fin_scale,0.55*s*fin_scale+wag*0.1*s),(-0.05*bx*s,0.1*s),fin)
    eye = (0.55*bx*s, -by*s*0.35)
    if kind == 4: eye = (0.5*bx*s, -0.12*s)
    if nose_kind == "hammer": eye = (nose_x*0.9, -0.68*s)
    er = max(2.5,0.2*s)*eye_scale
    cv.circle(P(*eye), er, (255,255,255,255)); cv.circle(P(eye[0]+0.06*s,eye[1]), er*0.55, (20,20,31,255))
    if kind == 3 or spec.get("angry"):
        cv.line(P(eye[0]-0.25*s,eye[1]-0.3*s),P(eye[0]+0.28*s,eye[1]-0.05*s),(26,26,38,255),max(2,s*0.07))
    mouth_x = nose_x
    if nose_kind == "beak":
        tri(cv,o,(nose_x*0.8,-0.13*s),(nose_x+0.42*s,0.03*s),(nose_x*0.8,0.17*s),body)
        tri(cv,o,(nose_x*0.8,0.06*s),(nose_x+0.36*s,0.07*s),(nose_x*0.8,0.2*s),belly)
        mouth_x = nose_x+0.34*s
    elif nose_kind == "lure":
        p0=(0.3*bx*s,-by*s*0.85); p1=(0.75*bx*s,-by*s*1.75); p2=(nose_x+0.35*s,-by*s*1.4); st=lighten(fin,0.25)
        cv.line(P(*p0),P(*p1),st,max(2,s*0.06)); cv.line(P(*p1),P(*p2),st,max(2,s*0.06))
        cv.circle(P(*p2),s*0.32,(255,242,115,60)); cv.circle(P(*p2),s*0.15,(255,242,128,255))
    if spec.get("teeth"):
        for ti in range(3):
            tx = mouth_x*(0.9-0.12*ti); ty2 = by*s*0.14
            tri(cv,o,(tx,ty2),(tx-0.08*s,ty2),(tx-0.04*s,ty2+0.15*s),(255,255,255,255))
    if spec.get("spout"):
        spx, spy = 0.35*bx*s, -by*s*0.95; jet = 0.5+0.25*abs(wag); wc = (191,235,255,217)
        for dd in (-1.0,0.0,1.0):
            tp = (spx+dd*0.28*s, spy-(0.55*jet+0.3*(1-abs(dd)))*s)
            cv.line(P(spx,spy),P(*tp),wc,max(2,s*0.07)); cv.circle(P(*tp),max(2,s*0.07),wc)
    cv.line(P(mouth_x*0.97,by*s*0.12),P(mouth_x*0.72,by*s*0.18),(51,20,20,255),max(1.5,s*0.06))

if __name__ == "__main__":
    species = parse_species(sys.argv[1])
    cols, cell_w, cell_h = 4, 380, 300
    rows = math.ceil(len(species)/cols)
    sheet = Image.new("RGBA", (cols*cell_w, rows*cell_h), (40,120,180,255))
    d = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
    for i, sp in enumerate(species):
        cv = Cv(cell_w, cell_h)
        # fit: scale by body length
        draw_fish(cv, (cell_w*0.46, cell_h*0.52), 66, 0, hexc(sp["body"]), hexc(sp["belly"]), hexc(sp["fin"]), 0.4, 0.0, 1, sp["spec"].get("pattern",0), sp["spec"])
        im = cv.img.resize((cell_w, cell_h), Image.LANCZOS)
        sheet.alpha_composite(im, ((i%cols)*cell_w, (i//cols)*cell_h))
        d.text(((i%cols)*cell_w+cell_w//2, (i//cols)*cell_h+cell_h-28), f'{sp["name"]}  ({sp["price"]:,})', font=font, fill=(255,255,255,255), anchor="mm")
    sheet.convert("RGB").save(sys.argv[2]); print("species rendered:", len(species))
