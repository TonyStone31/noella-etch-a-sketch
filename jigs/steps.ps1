# A JIG: any program that prints Heck.  This one prints a flight of steps.
# It is handed its values as  Name=value  - lengths as plain inches.
# (steps.sh beside this is the same jig for a machine with a shell and no
# PowerShell; the program runs whichever suits the machine it is on.)
$v = @{}
foreach ($a in $args) { if ($a -match '^(\w+)=(.*)$') { $v[$matches[1]] = $matches[2] } }
function Val($name, $default) {
  if ($v.ContainsKey($name)) { [double]::Parse($v[$name], [cultureinfo]::InvariantCulture) } else { $default }
}
function N($x) { ([double]$x).ToString('0.####', [cultureinfo]::InvariantCulture) }

$steps = [int](Val 'Steps' 5)
$rise  = Val 'Rise' 7.5
$going = Val 'Run' 10
$wide  = Val 'Width' 36
$e     = Val 'East' 0
$no    = Val 'North' 0

foreach ($side in 0, 1) {
  $y = $no + $side * $wide; $x = $e; $z = 0
  for ($i = 1; $i -le $steps; $i++) {
    "line = $(N $x)`" east, $(N $y)`" north, $(N $z)`" up to + $(N $rise)`" up"
    "line = $(N $x)`" east, $(N $y)`" north, $(N ($z + $rise))`" up to + $(N $going)`" east"
    $x += $going; $z += $rise
  }
}
$x = $e; $z = 0
"line = $(N $x)`" east, $(N $no)`" north, $(N $z)`" up to + $(N $wide)`" north"
for ($i = 1; $i -le $steps; $i++) {
  "line = $(N $x)`" east, $(N $no)`" north, $(N ($z + $rise))`" up to + $(N $wide)`" north"
  "line = $(N ($x + $going))`" east, $(N $no)`" north, $(N ($z + $rise))`" up to + $(N $wide)`" north"
  $x += $going; $z += $rise
}
