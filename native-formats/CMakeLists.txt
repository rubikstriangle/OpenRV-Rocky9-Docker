cmake_minimum_required(VERSION 3.20)
project(OpenRVWebImageReaders LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(PkgConfig REQUIRED)
pkg_check_modules(WEBP REQUIRED IMPORTED_TARGET libwebp libwebpdemux libwebpmux)
pkg_check_modules(HEIF REQUIRED IMPORTED_TARGET libheif)
# Compile the sources and headers already used by this RV build, not a second
# version of OpenImageIO. The plugins are loaded by RV's existing io_oiio reader.
set(OIIO "${RV_BUILD}/RV_DEPS_OIIO")
foreach(format webp heif)
    add_library(${format}.imageio MODULE
        "${OIIO}/src/src/${format}.imageio/${format}input.cpp")
    # Fail at build time on unresolved symbols in standalone plugins.
    target_link_options(${format}.imageio PRIVATE "-Wl,-z,defs")
    target_compile_definitions(${format}.imageio PRIVATE OpenImageIO_EXPORTS)
    target_include_directories(${format}.imageio PRIVATE
        "${OIIO}/install/include" "${RV_BUILD}/RV_DEPS_IMATH/install/include"
        "${RV_BUILD}/RV_DEPS_TIFF/install/include")
    target_link_libraries(${format}.imageio PRIVATE
        "${RV_BUILD}/stage/app/lib/libOpenImageIO.so"
        "${RV_BUILD}/stage/app/lib/libOpenImageIO_Util.so")
    set_target_properties(${format}.imageio PROPERTIES PREFIX ""
        INSTALL_RPATH "$ORIGIN/../../lib" BUILD_WITH_INSTALL_RPATH ON)
    install(TARGETS ${format}.imageio LIBRARY DESTINATION plugins/OIIO)
endforeach()
target_sources(webp.imageio PRIVATE "${OIIO}/src/src/webp.imageio/webpoutput.cpp")
# AVIF is read-only: no AV1 encoder is needed in the portable runtime.
target_link_libraries(webp.imageio PRIVATE PkgConfig::WEBP)
target_link_libraries(heif.imageio PRIVATE PkgConfig::HEIF)
