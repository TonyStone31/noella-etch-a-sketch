#!/bin/sh
# A JIG: any program that prints Heck.  This one prints a flight of steps.
# It is handed its values as  Name=value  - lengths as plain inches.
# (steps.ps1 beside this is the same jig for a machine with PowerShell and
# no shell; the program runs whichever suits the machine it is on.)
awk -v args="$*" 'BEGIN {
  n = split(args, A, " ")
  for (i = 1; i <= n; i++) { split(A[i], kv, "="); v[kv[1]] = kv[2] }
  steps = (v["Steps"] != "") ? v["Steps"] : 5
  rise  = (v["Rise"]  != "") ? v["Rise"]  : 7.5
  going = (v["Run"]   != "") ? v["Run"]   : 10
  wide  = (v["Width"] != "") ? v["Width"] : 36
  e     = (v["East"]  != "") ? v["East"]  : 0
  no    = (v["North"] != "") ? v["North"] : 0
  x = e; z = 0
  for (side = 0; side <= 1; side++) {
    y = no + side * wide; x = e; z = 0
    for (i = 1; i <= steps; i++) {
      printf "line = %g\" east, %g\" north, %g\" up to + %g\" up\n", x, y, z, rise
      printf "line = %g\" east, %g\" north, %g\" up to + %g\" east\n", x, y, z + rise, going
      x += going; z += rise
    }
  }
  x = e; z = 0
  printf "line = %g\" east, %g\" north, %g\" up to + %g\" north\n", x, no, z, wide
  for (i = 1; i <= steps; i++) {
    printf "line = %g\" east, %g\" north, %g\" up to + %g\" north\n", x, no, z + rise, wide
    printf "line = %g\" east, %g\" north, %g\" up to + %g\" north\n", x + going, no, z + rise, wide
    x += going; z += rise
  }
}'
