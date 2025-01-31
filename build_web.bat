@echo off
setlocal

set OUT_DIR=build\web_release

if not exist %OUT_DIR% mkdir %OUT_DIR%

set EMSDK_QUIET=1
:: call "C:/rando/dev/emsdk/emsdk_env.bat"

:: debug, maybe even -Og ? makes it like -O1 but improved debug.
::set EMCC_FLAGS=-g -gsource-map

:: good for profiling
::set EMCC_FLAGS=-O2 --profiling


:: -o:speed -debug
set ODIN_FLAGS=-define:PLATFORM=web


:: setsup emcc
:: call "../../emsdk/emsdk_env.sh"


:: https://github.com/floooh/sokol-tools/blob/master/docs/sokol-shdc.md
::sokol-shdc -i source/shader.glsl -o source/shader.odin -l hlsl5:wgsl -f sokol_odin

:: odin build source\main_web -target:freestanding_wasm32 -build-mode:obj -define:RAYLIB_WASM_LIB=env.o -vet -strict-style -o:speed -out:%OUT_DIR%\game



:: -extra-linker-flags:"-matomics -mbulk-memory"

odin build src %ODIN_FLAGS% -target:freestanding_wasm32 -build-mode:obj -out:%OUT_DIR%\game 

if %ERRORLEVEL% neq 0 (
    exit /b %ERRORLEVEL%
)

set DEBUG_LIBS=vendor/sokol/gfx/sokol_gfx_wasm_gl_debug.a vendor/sokol/log/sokol_log_wasm_gl_debug.a vendor/sokol/app/sokol_app_wasm_gl_debug.a vendor/sokol/glue/sokol_glue_wasm_gl_debug.a vendor/stb-web/lib/stb_image_wasm.o vendor/stb-web/lib/stb_rect_pack_wasm.o vendor/stb-web/lib/stb_truetype_wasm.o vendor/fmod/studio/lib/wasm/fmodstudioL_wasm.a vendor/fmod/core/lib/wasm/fmodL_wasm.a

set RELEASE_LIBS=vendor/sokol/gfx/sokol_gfx_wasm_gl_release.a vendor/sokol/log/sokol_log_wasm_gl_release.a vendor/sokol/app/sokol_app_wasm_gl_release.a vendor/sokol/glue/sokol_glue_wasm_gl_release.a vendor/stb-web/lib/stb_image_wasm.o vendor/stb-web/lib/stb_rect_pack_wasm.o vendor/stb-web/lib/stb_truetype_wasm.o vendor/fmod/studio/lib/wasm/fmodstudioL_wasm.a vendor/fmod/core/lib/wasm/fmodL_wasm.a

:: https://emscripten.org/docs/optimizing/Optimizing-Code.html
::set RELEASE_FLAGS=-O1

:: TODO !!!
:: optimise in odin as well bucko.
:: 

:: call emcc -o %OUT_DIR%\index.html  -sERROR_ON_UNDEFINED_SYMBOLS=1 -sMAX_WEBGL_VERSION=2 src/main.c %OUT_DIR%\src.wasm.o %RELEASE_LIBS% --shell-file src\web_stuff\shell.html %EMCC_FLAGS% --preload-file assets -sFORCE_FILESYSTEM=1 -lidbfs.js -sASSERTIONS -DPLATFORM_WEB -sINITIAL_MEMORY=512MB -sASYNCIFY -sASYNCIFY_IMPORTS=["push_syncfs_blocking","pull_syncfs_blocking"] -sJSPI_EXPORTS=["main","push_syncfs_blocking","pull_syncfs_blocking"] -sEXPORTED_RUNTIME_METHODS=['cwrap','setValue','getValue'] -sFETCH=1 

set EMCC_FLAGS=-O3 --preload-file assets -sFORCE_FILESYSTEM=1 -lidbfs.js -sASSERTIONS -DPLATFORM_WEB -sINITIAL_MEMORY=512MB -sASYNCIFY -sASYNCIFY_IMPORTS=["push_syncfs_blocking","pull_syncfs_blocking"] -sJSPI_EXPORTS=["main","push_syncfs_blocking","pull_syncfs_blocking"] -sEXPORTED_RUNTIME_METHODS=['setValue','getValue']


call emcc -o %OUT_DIR%\index.html -sERROR_ON_UNDEFINED_SYMBOLS=1 -sMAX_WEBGL_VERSION=2 src/main.c %OUT_DIR%\game.wasm.o %RELEASE_LIBS% --shell-file src\web_stuff\shell.html %EMCC_FLAGS% 


:: -sFULL_ES3 ??

:: -sFETCH_DEBUG=1

:: --use-preload-plugins ???




:: -sEXPORTED_FUNCTIONS=["_set_sync_result","_main"]
:: -sGL_DEBUG=1

del %OUT_DIR%\game.wasm.o

:: for mem stuff later ??
:: -sINITIAL_MEMORY=64MB -sMAXIMUM_MEMORY=2GB -sALLOW_MEMORY_GROWTH=1

:: for all flags
:: https://github.com/emscripten-core/emscripten/blob/dde19fae5259ab53942c52d67cf3edb360bda28a/src/settings.js