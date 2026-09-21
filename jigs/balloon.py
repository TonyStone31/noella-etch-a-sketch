#!/usr/bin/env python3
# A JIG: any program that prints Heck.  This one prints a balloon on a string.
# It is handed its values as  Name=value  - lengths as plain inches.
import sys, math

v = dict(a.split("=", 1) for a in sys.argv[1:] if "=" in a)
r = float(v.get("Radius", 18))
e = float(v.get("East", 0))
n = float(v.get("North", 0))
h = float(v.get("Height", 72))

# the balloon: a circle standing up, facing south
print("circle")
print(f"  center = {e}\" east, {n}\" north, {h}\" up")
print(f"  radius = {r}\"")
print("  facing = south")
print("  ink = red")
print("end")

# the knot: a little triangle under it
k = r / 8
top = h - r
print(f"line = {e}\" east, {n}\" north, {top}\" up to {e - k}\" east, {n}\" north, {top - k}\" up")
print(f"line = {e - k}\" east, {n}\" north, {top - k}\" up to {e + k}\" east, {n}\" north, {top - k}\" up")
print(f"line = {e + k}\" east, {n}\" north, {top - k}\" up to {e}\" east, {n}\" north, {top}\" up")

# the string: a gentle wave down to the floor
steps = 12
x0, z0 = e, top - k
for i in range(1, steps + 1):
    z1 = (top - k) * (1 - i / steps)
    x1 = e + math.sin(i * math.pi / 3) * r / 6
    print(f"line = {x0:.4f}\" east, {n}\" north, {z0:.4f}\" up to {x1:.4f}\" east, {n}\" north, {z1:.4f}\" up")
    x0, z0 = x1, z1
