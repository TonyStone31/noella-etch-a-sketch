#!/usr/bin/env bash
# Pure Pascal writer plus independent PDF page/placement checks.
set -e
cd "$(dirname "$0")/.."
FPC=/media/tony/storpart/fpctrunklaztrunk/fpc/bin/x86_64-linux/fpc
LAZ=/media/tony/storpart/fpctrunklaztrunk/lazarus
WS=${LCL_WS:-gtk3}
"$FPC" -Fu. -Fuwebp -FU/tmp -FE/tmp -Cirot \
  -Fu"$LAZ/lcl/units/x86_64-linux" \
  -Fu"$LAZ/lcl/units/x86_64-linux/$WS" \
  -Fu"$LAZ/components/lazutils/lib/x86_64-linux" \
  -Fu"$LAZ/../config_lazarus/onlinepackagemanager/packages/BGRABitmap/bgrabitmap/lib/x86_64-linux-$WS-3.3.1" \
  tests/pdftest.pas > /tmp/hsk-pdftest-build.log 2>&1 \
  || { tail -25 /tmp/hsk-pdftest-build.log; exit 1; }
/tmp/pdftest
python3 - <<'PY'
import re
from pathlib import Path
sizes = [(210,297),(297,420),(420,594),(594,841),(841,1189),
 (215.9,279.4),(279.4,431.8),(431.8,558.8),(558.8,863.6),(863.6,1117.6),
 (228.6,304.8),(304.8,457.2),(457.2,609.6),(609.6,914.4),(914.4,1219.2),
 (762,1066.8),(660.4,965.2),(685.8,990.6),(215.9,355.6),(148,210),(711.2,1016)]
for i, size in enumerate(sizes):
 for landscape in range(2):
  w,h = size[::-1] if landscape else size
  data = Path(f'/tmp/hsk-pdf-{i}-{landscape}.pdf').read_bytes()
  box = re.search(rb'/MediaBox \[0 0 ([\d.]+) ([\d.]+)\]',data)
  assert box, (i,landscape)
  assert abs(float(box[1])*25.4/72-w)<0.001
  assert abs(float(box[2])*25.4/72-h)<0.001
  assert b'/Subtype /Image' not in data, 'PDF must contain no bitmap'
  assert b'B*' in data, 'face holes need even-odd fill'
  assert b'W n' in data, 'drawing must be clipped to its area'
  bar = re.search(rb'([\d.]+) 34.016 m\s+([\d.]+) 34.016 l',data)
  assert bar and abs((float(bar[2])-float(bar[1]))*25.4/72-50)<0.002
  # First red stroke is a 10 m horizontal line. At 1:100 it is 100 mm.
  line = re.search(rb'0[.]996 0 0 RG\s+[\s\S]*?([\d.]+) ([\d.]+) m\s+(?:[\d.]+ [wJ]\s+)*([\d.]+) ([\d.]+) l',data)
  assert line, (i,landscape)
  assert abs((float(line[3])-float(line[1]))*25.4/72-100)<0.002
  assert abs(float(line[2])-float(line[4]))<0.002
  assert abs(float(line[1])*25.4/72-w/2)<0.002
  assert abs(float(line[2])*25.4/72-(h+15)/2)<0.002
# Changing screen zoom preserves vector coordinates, widths, and text sizing.
def content(path):
 data=Path(path).read_bytes()
 return re.search(rb'stream\r?\n(.*?)endstream',data,re.S)[1]
assert content('/tmp/hsk-pdf-0-0.pdf') == content('/tmp/hsk-pdf-zoom.pdf')
data=Path('/tmp/hsk-pdf-imperial.pdf').read_bytes()
line=re.search(rb'0[.]996 0 0 RG\s+[\s\S]*?([\d.]+) ([\d.]+) m\s+(?:[\d.]+ [wJ]\s+)*([\d.]+) ([\d.]+) l',data)
assert abs(float(line[3])-float(line[1])-72)<0.002, 'one foot at 1:12 must be one inch'
import xml.etree.ElementTree as ET
root=ET.parse('/tmp/hsk-pdf-parity.svg').getroot()
ns={'s':'http://www.w3.org/2000/svg'}
assert len(root.findall('s:path',ns))==5
assert any(x.text=='FIELD VERIFY' for x in root.findall('s:text',ns))
assert any(x.text=='A&B <plan> café Ω' for x in root.findall('s:text',ns))
print('PASS: 42 vector sheets; metric/imperial scale, zoom independence, holes, clipping, SVG labels; no images.')
PY
