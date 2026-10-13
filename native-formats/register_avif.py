#!/usr/bin/env python3
"""Register AVIF with RV; upstream's generic OIIO extension list omits it."""
from pathlib import Path
import sys
p = Path(sys.argv[1]) / 'src/lib/image/IOoiio/IOoiio.cpp'
s = p.read_text()
if 'addType("avif"' not in s:
    anchor = '        addType("webp", "Google WebP", rw, codecs);'
    if s.count(anchor) != 1:
        raise SystemExit('Unsupported OpenRV source layout: update the AVIF registration patch')
    s = s.replace(anchor, anchor + '\n        addType("avif", "AVIF Image", r, codecs);')
    p.write_text(s)
