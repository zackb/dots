#!/bin/bash

wall=$1

if [ -n "$wall" ]; then
    matugen image --source-color-index 0 $wall
    qs ipc call shell reloadColors
fi

