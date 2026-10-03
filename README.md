# OpenRV on Ubuntu using Rocky 9 Docker

Build [OpenRV](https://github.com/AcademySoftwareFoundation/OpenRV) inside Rocky Linux 9, then extract and run the application on a compatible Linux host. The default is **OpenRV v4.0.2, CY2024, Qt 6.5.3, and FFmpeg 8**. You need Docker Engine access and an x86-64 machine.

The corrected Dockerfile completed a build on Ubuntu 25.04 with 128 logical CPUs and 123 GiB RAM. The archive was approximately 539 MiB. Allow substantial additional disk space for sources, dependencies, build layers, and the loaded image; the archive size is not the build's disk requirement. Use `df -h` and `docker system df` to check capacity. Build time depends heavily on hardware, downloads, and cache state.

## Build and export

```bash
git clone https://github.com/rubikstriangle/OpenRV-Rocky9-Docker.git
cd OpenRV-Rocky9-Docker
./build_openrv.sh
```

Outputs go to `out/`: a tarball, its SHA-256 checksum, and source/image metadata. The script works from any current directory. Set `-o /path/to/output` to choose another output directory. Existing artifacts are not overwritten.

```bash
# Save readable build output and preserve the build exit status.
set -o pipefail
./build_openrv.sh 2>&1 | tee build.log

# Re-export a successfully built image without compiling again.
./build_openrv.sh --extract-only -o ./another-output-directory

# Rebuild without Docker's layer cache (slow; generally unnecessary).
./build_openrv.sh -n -o ./fresh-output
```

`IMAGE_NAME` overrides the default `openrv_rocky9` image tag. Use different image names and output directories for concurrent builds. Extraction uses an anonymous stopped container and removes only that container on exit; it does not stop or delete unrelated containers.

## Extract and run

Use the actual filenames printed by the script:

```bash
cd out
sha256sum -c OpenRV-Rocky9-x86_64-4.0.0-27db5464a90c.tar.gz.sha256
tar -xzf OpenRV-Rocky9-x86_64-4.0.0-27db5464a90c.tar.gz
./OpenRV-Rocky9-x86_64-4.0.0/bin/rv
```

**Version naming:** upstream's v4.0.2 tag still reports `4.0.0` through `rv -version`. This build records the actual source commit (`27db5464a90ca19a9a30d540988ee109ee06bb7e`) and includes its prefix in the archive filename. The directory inside the archive retains upstream's version string. The metadata comes from the built image, including when using `--extract-only`.

The host needs working graphics/audio drivers and the libraries required by the application. Its launch scripts use `tcsh`; install it if missing. Copying a Rocky build to another distribution does not guarantee runtime compatibility.

## What changed for OpenRV 4

- Replaced removed Rocky package names `mesa-libOSMesa` / `mesa-libOSMesa-devel` with `mesa-compat-libOSMesa` / `mesa-compat-libOSMesa-devel`.
- Selected the release with `ARG OPENRV_REF=v4.0.2` instead of implicitly cloning the default branch.
- Used one explicit CMake configuration rather than sourcing interactive `rvcmds.sh`. That script prompts for `RV_VFX_PLATFORM`; setting `VFX_PLATFORM` or passing a later CMake option does not answer the prompt.
- Built the `dependencies` target before `main_executable`. A parallel first build otherwise failed in `ALSASafeAudioRenderer.cpp` on missing `gc/gc.h` before its dependency installation finished.
- Kept configuration, dependency compilation, application compilation, and packaging in separate Docker layers. Successfully completed stages can be reused.
- Kept `cmake --install` for packaging and the existing libcrypt copy used by this workflow.

CY2024 remains supported by OpenRV 4.0.2. There is no requirement to select CY2026 merely because the application version is 4.x. Build Python 3.11.8 and application Python 3.11.9 serve different roles; OpenRV builds the latter itself.

## Validation performed

After extraction on Ubuntu 25.04:

- `rv -version` and `rvio -version` succeeded.
- Bundled Python imported `ssl`, `numpy`, `opentimelineio`, `OpenGL`, and `cryptography`.
- `rv.bin` had no unresolved libraries with the bundled library directory supplied to the loader.
- `rvio` converted a generated PPM to EXR, EXR to PNG, EXR to ProRes MOV, and that MOV back to EXR.

Interactive GUI playback, audio output, and all other codec combinations still need testing with your own media. The codec options retained in the Dockerfile are exceptions to OpenRV's disabled-codec lists; they do not independently install arbitrary encoders. Do not infer HEVC encoding support solely from a name in that list.

## Updating and caching

```bash
# Choose an upstream tag or branch; changing releases may need toolchain changes.
OPENRV_REF=v4.0.2 ./build_openrv.sh -o ./release-output
```

Review the chosen release's `cmake/defaults/CY2024.cmake`, `dockerfiles/Dockerfile.Linux-Rocky9-CY2024`, and build documentation together when updating. Retest the extracted package on the host.

The release tag is pinned by default, but the environment is not fully reproducible: the Rocky `9` image, package repositories, pyenv, Rust, and Python helper packages can change. For stricter repeatability, pin an approved base-image digest, verify the expected source commit, and lock helper tool versions. Update those pins deliberately rather than leaving them indefinitely.

Docker can reuse completed layers, but a failed compilation layer loses its partial build work. A persistent builder with mounted build/dependency directories, or carefully scoped BuildKit caches and ccache, is a useful next improvement. Keep caches separated by platform and toolchain. The current Dockerfile uses all available CPUs; on smaller-memory hosts, review both top-level and dependency-build parallelism before starting.

The script uses `--load`, so Docker exports the full builder image before the archive can be copied out. That took several minutes in the validated run. A dedicated artifact-export stage is another potential improvement; the current method is retained because it was tested end to end.

## Troubleshooting and cleanup

```bash
# Inspect the completed builder.
docker run --rm -it openrv_rocky9 /bin/bash

# Inspect disk usage before choosing what to remove.
docker system df -v

# Remove this image when no longer needed; build cache is separate.
docker image rm openrv_rocky9
```

Do not use global Docker pruning just to clean up one build. The wrapper automatically removes its temporary extraction container. Keep your output archive before deleting builder resources.
