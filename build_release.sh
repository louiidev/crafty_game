#!/bin/bash

# Step 1: Build the Odin project
echo "Building the project with Odin..."
odin build src -o:speed
if [ $? -ne 0 ]; then
    echo "Build failed. Exiting..."
    exit 1
fi
echo "Build succeeded."

# Step 2: Delet old stuff
GAME_DIR="./game"
GAME_EXECUTABLE="$GAME_DIR/game.exe"
if [ -f "$GAME_EXECUTABLE" ]; then
    echo "Deleting existing game.exe..."
    rm "$GAME_EXECUTABLE"
fi

GAME_ASSETS_FOLDER="$GAME_DIR/assets"
if [ -d "$GAME_ASSETS_FOLDER" ]; then
    echo "Deleting existing assets folder in game directory..."
    rm -rf "$GAME_ASSETS_FOLDER"
fi

GAME_BUILD_OLD="./game.zip"
if [ -f "$GAME_BUILD_OLD" ]; then
    echo "Deleting old build"
    rm "$GAME_BUILD_OLD"
fi

ROOT_ASSETS="./assets"
if [ -d "$ROOT_ASSETS" ]; then
    echo "Copying assets into the game/assets..."
    mkdir -p "$GAME_ASSETS_FOLDER"
    cp -r "$ROOT_ASSETS/"* "$GAME_ASSETS_FOLDER" 
else
    echo "No assets folder found in the root. Skipping assets move."
fi



SOURCE_EXECUTABLE="./src.exe"
if [ -f "$SOURCE_EXECUTABLE" ]; then
    echo "Renaming and moving the new executable..."
    mv "$SOURCE_EXECUTABLE" "$GAME_EXECUTABLE"
else
    echo "Error: src.exe not found. Exiting..."
    exit 1
fi
