#!/usr/bin/env python3
"""Bundle codec dependencies, without replacing RV's existing core libraries."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

app = Path(sys.argv[1]).resolve()
lib = app / 'lib'
heif_plugins = lib / 'libheif'
heif_plugins.mkdir(exist_ok=True)
# Use a single known AV1 decoder; do not accidentally depend on system plugins.
decoder = Path('/usr/lib64/libheif/libheif-dav1d.so')
if not decoder.is_file():
    raise SystemExit('libheif dav1d decoder missing; check Rocky/EPEL package layout')
shutil.copy2(decoder, heif_plugins / decoder.name)
queue = list((app / 'plugins/OIIO').glob('*.imageio.so')) + [heif_plugins / decoder.name]
base = re.compile(r'^(ld-linux|lib(c|m|dl|pthread|rt|resolv|gcc_s|stdc\+\+)\.so)')
env = dict(os.environ, LD_LIBRARY_PATH=str(lib))
seen = set()
packages = {'libheif', 'libwebp', 'libdav1d'}
while queue:
    binary = queue.pop()
    if binary in seen:
        continue
    seen.add(binary)
    output = subprocess.check_output(['ldd', str(binary)], env=env, text=True)
    if 'not found' in output:
        raise SystemExit(f'Unresolved runtime dependency for {binary}:\n{output}')
    for name, path in re.findall(r'^\s*(\S+) => (/\S+)', output, re.M):
        if base.match(name):
            continue
        destination = lib / name
        if destination.exists():
            continue
        shutil.copy2(path, destination)
        subprocess.run(['patchelf', '--set-rpath', '$ORIGIN', str(destination)], check=True)
        if path.startswith(('/usr/lib', '/lib')):
            package = subprocess.check_output(['rpm', '-qf', '--qf', '%{NAME}', path], text=True)
            packages.add(package)
        queue.append(destination)
subprocess.run(['patchelf', '--set-rpath', '$ORIGIN/..', str(heif_plugins / decoder.name)], check=True)
# Native libheif locates optional decoders through this variable. Configure all
# RV tcsh launchers, including rvio; paths follow RV_HOME after relocation.
for launcher in (app / 'bin').iterdir():
    if not launcher.is_file() or launcher.is_symlink():
        continue
    with launcher.open('rb') as f:
        if not f.read(64).startswith(b'#!/bin/tcsh'):
            continue
    source = launcher.read_text()
    marker = 'unsetenv BUILD_ROOT'
    if marker in source and 'setenv LIBHEIF_PLUGIN_PATH' not in source:
        source = source.replace(marker, 'setenv LIBHEIF_PLUGIN_PATH "$RV_HOME/lib/libheif"\n\n' + marker, 1)
        launcher.write_text(source)
licenses = app / 'share/licenses/web-image-codecs'
licenses.mkdir(parents=True, exist_ok=True)
for package in sorted(packages):
    for file in subprocess.check_output(['rpm', '-q', '--licensefiles', package], text=True).splitlines():
        p = Path(file)
        if p.is_file():
            dest = licenses / package / p.name
            dest.parent.mkdir(exist_ok=True)
            shutil.copy2(p, dest)
(licenses / 'packages.txt').write_text(subprocess.check_output(
    ['rpm', '-q', *sorted(packages)], text=True))
