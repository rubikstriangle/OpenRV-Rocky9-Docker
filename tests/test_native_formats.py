#!/usr/bin/env python3
"""Decode through packaged RVIO; exit codes and format listings are insufficient."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from PIL import Image

app = Path(sys.argv[1]).resolve()
fixtures = Path(__file__).parent / 'fixtures'
with tempfile.TemporaryDirectory(prefix='rv-web-formats-') as temp:
    env = dict(os.environ, HOME=temp, QT_QPA_PLATFORM='offscreen')
    # The packaged launchers must supply codec paths; don't inherit build paths.
    for key in ['RV_HOME', 'RV_SUPPORT_PATH', 'LD_LIBRARY_PATH', 'OIIO_LIBRARY_PATH',
                'LIBHEIF_PLUGIN_PATH', 'OCIO']:
        env.pop(key, None)
    for name in ['reference.webp', 'alpha.webp', 'reference.avif']:
        output = Path(temp) / (name + '.png')
        result = subprocess.run([str(app / 'bin/rvio_sw'), str(fixtures / name),
                                 '-o', str(output)], env=env, capture_output=True,
                                text=True, timeout=60)
        log = result.stdout + result.stderr
        if result.returncode or 'ERROR:' in log or not output.is_file():
            raise RuntimeError(f'{name}: RVIO decode failed (exit {result.returncode})\n{log}')
        with Image.open(output) as image:
            assert image.size == (32, 32), (name, image.size)
            rgba = image.convert('RGBA')
            # RVIO preserves OIIO's premultiplied RGB for the alpha fixture.
            expected = (32, 64, 96, 128) if name == 'alpha.webp' else (64, 128, 192, 255)
            error = max(abs(a-b) for pixel in rgba.getdata() for a,b in zip(pixel, expected))
            assert error <= 4, (name, 'pixel error', error)
        print(f'PASS: {name} decoded, dimensions and RGBA pixels verified')
print('Native WebP and AVIF decoding verified.')
