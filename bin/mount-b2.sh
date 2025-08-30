#!/bin/bash

rclone mount b2:virusport ~/Sync/virusport \
    --vfs-cache-mode writes \
    --vfs-cache-max-size 1G \
    --vfs-cache-max-age 1h \
    --allow-other \
    --dir-cache-time 72h \
    --umask 002 \
    --log-level INFO \
    --log-file ~/rclone-b2-mount.log \
    --daemon

