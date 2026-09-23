#!/usr/bin/env python3
# A JIG: any program that prints Heck.  This one prints a body to dress -
# a mannequin, standing on the floor, facing south.
#
# It is handed its values as  Name=value  - lengths as plain inches.
#
#   Height   how tall, from the floor to the top of the head     (6')
#   Weight   in pounds - what makes the same height fuller or slighter (150)
#   Bust, Waist, Hip
#            those three measurements, round, when you have them; left
#            out, they follow the height and the weight
#   Sides    how many corners round each section                    (24)
#   East, North
#            where she stands
#
# There is no engine in this and no library: a body is a stack of ovals.
# At each height that matters there is a width, a depth, and how far the
# middle of the oval sits back from the line the body stands on; between
# those the ovals are eased into one another, and a skin of triangles is
# stretched over the lot.  Every edge is soft, so what shows is the shape
# and not the mesh.  The numbers are a woman's, six foot and a hundred and
# fifty pounds - what a size chart calls a tall eight - and the other sizes
# are scaled from her.  Her arms hang at her sides, palms in.
import sys, math

v = dict(a.split("=", 1) for a in sys.argv[1:] if "=" in a)
def num(name, default):
    try:
        return float(v.get(name, default))
    except ValueError:
        return float(default)

H = num("Height", 72.0)
W = num("Weight", 150.0)
N = max(8, int(num("Sides", 24)))
E0 = num("East", 0.0)
N0 = num("North", 0.0)

# How much fuller or slighter than the woman the numbers are for.  Bulk
# goes with the square of a girth and the height, so a girth scale is the
# square root of the weight per inch of height, against hers.
g = math.sqrt((W / 150.0) / (H / 72.0))
# Height scales every level; hers is 72.
s = H / 72.0

# ---- the sections -------------------------------------------------------
# (height as a share of the stature, width, depth, how far back the middle
# of the oval sits - all inches at 72" - and which girth scale it takes)
# The names after them are the ones a measuring tape knows.

TORSO = [
    (0.460, 14.0, 8.4, 0.0, "g"),   # where the legs join
    (0.500, 14.2, 9.0, 0.0, "g"),
    (0.530, 14.4, 9.4, 0.0, "g"),   # hip - the fullest
    (0.565, 13.4, 8.8, 0.2, "g"),   # high hip
    (0.600, 12.0, 8.0, 0.3, "g"),
    (0.625, 10.6, 6.7, 0.3, "g"),   # waist
    (0.660, 11.6, 7.6, 0.2, "g"),   # under the bust
    (0.700, 12.4, 9.6, -0.5, "g"),  # bust
    (0.735, 13.0, 8.6, 0.0, "g"),
    (0.780, 14.2, 8.0, 0.2, "g"),   # the armpits
    (0.810, 15.6, 6.4, 0.4, "h"),   # across the shoulders
    (0.826, 12.0, 5.8, 0.5, "h"),   # where they slope
    (0.836, 7.6, 5.2, 0.6, "h"),
    (0.845, 4.6, 4.8, 0.8, "n"),    # the neck
    (0.868, 4.4, 4.7, 0.8, "n"),    # under the chin
]
HEAD = [
    (0.868, 4.4, 4.7, 0.8, "1"),
    (0.884, 4.8, 5.6, 0.9, "1"),    # the jaw
    (0.905, 5.6, 7.0, 0.8, "1"),
    (0.935, 5.9, 7.5, 0.7, "1"),    # the eyes: the widest
    (0.965, 5.7, 7.2, 0.6, "1"),
    (0.985, 4.4, 5.6, 0.5, "1"),
    (0.997, 2.0, 2.6, 0.4, "1"),
]
LEG = [
    (0.000, 3.6, 9.6, -2.6, "f"),   # the sole: a shoe, near enough
    (0.026, 3.4, 8.2, -1.8, "f"),
    (0.042, 3.0, 4.0, -0.2, "f"),
    (0.055, 2.8, 3.2, 0.0, "g"),    # the ankle
    (0.120, 3.4, 3.9, 0.0, "g"),
    (0.200, 4.2, 4.7, 0.2, "g"),    # the calf
    (0.260, 3.8, 4.2, 0.0, "g"),
    (0.285, 3.9, 4.4, 0.0, "g"),    # the knee
    (0.340, 4.6, 5.0, 0.0, "g"),
    (0.400, 5.6, 5.8, 0.0, "g"),
    (0.450, 6.4, 7.0, 0.0, "g"),    # the thigh
    (0.478, 6.6, 7.2, 0.0, "g"),
]
LEG_APART = 3.5          # each leg's middle, east and west of the line
# an arm hangs a little out from the side, so the sixth number is how far
# from the middle its own middle is at that height
ARM = [
    (0.387, 0.6, 1.0, 0.3, "f", 9.6),   # the fingertips
    (0.410, 1.0, 2.6, 0.3, "f", 9.5),   # the fingers
    (0.440, 1.1, 3.4, 0.3, "f", 9.4),   # the palm
    (0.480, 1.2, 3.0, 0.3, "f", 9.2),
    (0.500, 1.7, 2.2, 0.3, "f", 9.1),   # the wrist
    (0.560, 2.6, 2.7, 0.4, "g", 8.8),
    (0.620, 3.0, 3.3, 0.5, "g", 8.4),   # the forearm
    (0.660, 3.0, 3.4, 0.6, "g", 8.0),   # the elbow
    (0.690, 3.0, 3.2, 0.5, "g", 7.8),
    (0.740, 3.4, 3.5, 0.5, "g", 7.4),   # the upper arm
    (0.790, 3.8, 3.9, 0.5, "g", 7.0),   # the deltoid
    (0.815, 3.4, 3.6, 0.5, "g", 6.8),
    (0.824, 1.6, 1.8, 0.5, "h", 6.6),   # the top of the shoulder
]

# The three the tape measures, as the table has them, and as they were asked
# for; a ratio for each, eased along the body between them.
def girth(w, d):
    a, b = w / 2, d / 2
    h = ((a - b) / (a + b)) ** 2
    return math.pi * (a + b) * (1 + 3 * h / (10 + math.sqrt(4 - 3 * h)))

def wanted(name, level):
    for (z, w, d, off, k) in TORSO:
        if z == level:
            have = girth(w * g, d * g)
    ask = v.get(name)
    if ask is None or ask == "":
        return 1.0
    try:
        return float(ask) / have
    except ValueError:
        return 1.0

R_HIP, R_WAIST, R_BUST = wanted("Hip", 0.530), wanted("Waist", 0.625), wanted("Bust", 0.700)

def asked_ratio(z):
    # below the hip the hip's; hip to waist to bust eased; above the bust
    # fading to nothing by the shoulders
    if z <= 0.530: return R_HIP
    if z <= 0.625: return R_HIP + (R_WAIST - R_HIP) * (z - 0.530) / (0.625 - 0.530)
    if z <= 0.700: return R_WAIST + (R_BUST - R_WAIST) * (z - 0.625) / (0.700 - 0.625)
    if z <= 0.810: return R_BUST + (1.0 - R_BUST) * (z - 0.700) / (0.810 - 0.700)
    return 1.0

def scale_of(kind, z):
    if kind == "g": return g * asked_ratio(z)
    if kind == "h": return math.sqrt(g)          # shoulders are bone, mostly
    if kind == "n": return math.sqrt(g)
    if kind == "f": return 1.0                    # a shoe is a shoe
    return 1.0

# ---- easing between the sections ----------------------------------------
# A monotone cubic through the points: it passes through every number in
# the table and never overshoots, so a waist stays a waist.
def monotone(xs, ys):
    n = len(xs)
    d = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, n - 1):
        if d[i - 1] * d[i] <= 0:
            m[i] = 0.0
        else:
            m[i] = (d[i - 1] + d[i]) / 2
    for i in range(n - 1):
        if d[i] == 0:
            m[i] = m[i + 1] = 0.0
        else:
            a, b = m[i] / d[i], m[i + 1] / d[i]
            t = a * a + b * b
            if t > 9:
                tau = 3 / math.sqrt(t)
                m[i], m[i + 1] = tau * a * d[i], tau * b * d[i]
    def at(x):
        if x <= xs[0]: return ys[0]
        if x >= xs[-1]: return ys[-1]
        i = 0
        while xs[i + 1] < x: i += 1
        h = xs[i + 1] - xs[i]
        t = (x - xs[i]) / h
        t2, t3 = t * t, t * t * t
        return ((2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h * m[i] +
                (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h * m[i + 1])
    return at

def rings_of(table, step_in):
    # the levels: every one in the table, and more between so that no gap
    # is over step_in inches
    table = [r if len(r) == 6 else r + (0.0,) for r in table]
    zs = [z for (z, w, d, off, k, cx) in table]
    ws = [w * scale_of(k, z) for (z, w, d, off, k, cx) in table]
    ds = [d * scale_of(k, z) for (z, w, d, off, k, cx) in table]
    os_ = [off * s for (z, w, d, off, k, cx) in table]
    cs = [cx * s for (z, w, d, off, k, cx) in table]
    fw, fd, fo, fc = monotone(zs, ws), monotone(zs, ds), monotone(zs, os_), monotone(zs, cs)
    levels = []
    for i in range(len(zs) - 1):
        gap = (zs[i + 1] - zs[i]) * H
        n = max(1, int(math.ceil(gap / step_in)))
        for j in range(n):
            levels.append(zs[i] + (zs[i + 1] - zs[i]) * j / n)
    levels.append(zs[-1])
    return [(z * H, fw(z), fd(z), fo(z), fc(z)) for z in levels]

# ---- printing -------------------------------------------------------------
out = []
def say(line): out.append(line)

def along(n, plus, minus):
    # a length and its direction - Heck has west, not minus east
    n = round(n, 3) + 0.0
    return f'{abs(n):.3f}" {plus if n >= 0 else minus}'

def place(x, y, z):
    return f'{along(x, "east", "west")}, {along(y, "north", "south")}, {along(z, "up", "down")}'

def ring_points(prefix, ring, side):
    # side is which way the ring's own middle is moved: 1 east, -1 west
    z, w, d, off, cx = ring
    names = []
    for i in range(N):
        a = 2 * math.pi * i / N
        # anticlockwise seen from above, starting east
        x = E0 + side * cx + w / 2 * math.cos(a)
        y = N0 + off + d / 2 * math.sin(a)
        nm = f"{prefix}{i + 1}"
        say(f"    {nm} = {place(x, y, z)}")
        names.append(nm)
    return names

faces, lines, open_rings, seen = [], [], [], set()
def edge(a, b):
    # each edge once, whichever face asked for it
    if (b, a) not in seen and (a, b) not in seen:
        seen.add((a, b))
        lines.append((a, b))

def wall(lo, hi):
    # the skin between two rings, as triangles - the ovals differ, so a
    # four-cornered piece would not lie flat.  Turned to face outward.
    for i in range(N):
        j = (i + 1) % N
        faces.append((lo[i], lo[j], hi[j]))
        faces.append((lo[i], hi[j], hi[i]))
        edge(lo[i], lo[j])
        edge(lo[i], hi[i])
        edge(lo[i], hi[j])

def cap(ring, up):
    # a flat end: the ring's own loop, turned to face up or down
    names = list(ring) if up else list(reversed(ring))
    faces.append(tuple(names))
    for i in range(N):
        edge(ring[i], ring[(i + 1) % N])
    open_rings.remove(ring)

def pole(ring, name, x, y, z):
    say(f"    {name} = {place(x, y, z)}")
    for i in range(N):
        j = (i + 1) % N
        faces.append((ring[i], ring[j], name))
        edge(ring[i], ring[j])
        edge(ring[i], name)

say("solid")
say("  paint = #E6DCCB")
say("  points")

# the torso, closed underneath where the legs go in
torso = rings_of(TORSO, 2.0 * s)
rings = [ring_points(f"t{k}p", r, 1) for k, r in enumerate(torso)]
open_rings.extend(rings)
cap(rings[0], up=False)
for k in range(len(rings) - 1):
    wall(rings[k], rings[k + 1])
neck_top = rings[-1]

# the head, sharing the ring under the chin, closed at the crown
head = rings_of(HEAD, 1.2 * s)
hrings = [neck_top] + [ring_points(f"h{k}p", r, 1) for k, r in enumerate(head[1:])]
open_rings.extend(hrings[1:])
for k in range(len(hrings) - 1):
    wall(hrings[k], hrings[k + 1])
crown = head[-1]
pole(hrings[-1], "crown", E0, N0 + crown[3], H)

# two legs, closed at the top, where they are inside the torso - a shell
# with a gap in it is one that will not print
LEG = [r + (LEG_APART,) for r in LEG]
for side, sign in (("l", -1), ("r", 1)):
    leg = rings_of(LEG, 2.0 * s)
    lrings = [ring_points(f"{side}{k}p", r, sign) for k, r in enumerate(leg)]
    open_rings.extend(lrings)
    cap(lrings[0], up=False)
    cap(lrings[-1], up=True)
    for k in range(len(lrings) - 1):
        wall(lrings[k], lrings[k + 1])

# two arms, rounded off at the shoulder and at the fingertips
for side, sign in (("a", -1), ("b", 1)):
    arm = rings_of(ARM, 1.5 * s)
    arings = [ring_points(f"{side}{k}p", r, sign) for k, r in enumerate(arm)]
    open_rings.extend(arings)
    for k in range(len(arings) - 1):
        wall(arings[k], arings[k + 1])
    tip, top = arm[0], arm[-1]
    # every stack runs from the floor up, so a point above its last ring
    # faces out as the crown does; under its first, the ring goes round
    # the other way
    pole(arings[0][::-1], f"{side}tip", E0 + sign * tip[4], N0 + tip[3], tip[0] - 0.5 * s)
    pole(arings[-1], f"{side}top", E0 + sign * top[4], N0 + top[3], top[0] + 0.6 * s)

say("  end")
for f in faces:
    say("  face = " + " ".join(f))
# every ring is a closed, flat loop of lines, and a closed loop of lines is
# a face unless the text says otherwise - and inside a body it is not
for r in open_rings:
    say("  noface = " + " ".join(r))
for a, b in lines:
    say("  line")
    say(f"    points = {a} to {b}")
    say("    soft = true")
    say("  end")
say("end")
print("\n".join(out))
