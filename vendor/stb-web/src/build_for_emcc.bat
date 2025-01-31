@echo off

:: randy: had to run these through emscripten instead of using the ones shipped with odin
:: because they were using libc

call emsdk_env.bat

echo stb_image_wasm
call emcc -c -Os stb_image.c -o ..\lib\stb_image_wasm.o -DSTBI_NO_STDIO

echo stb_image_write_wasm
call emcc -c -Os stb_image_write.c -o ..\lib\stb_image_write_wasm.o -DSTBI_WRITE_NO_STDIO

echo stb_image_resize_wasm
call emcc -c -Os stb_image_resize.c -o ..\lib\stb_image_resize_wasm.o -DSTBI_WRITE_NO_STDIO

echo stb_truetype
call emcc -c -Os stb_truetype.c -o ..\lib\stb_truetype_wasm.o

echo stb_rect_pack
call emcc -c -Os stb_rect_pack.c -o ..\lib\stb_rect_pack_wasm.o