#!/bin/sh
docker run --privileged -it --rm -v `pwd`/image:/output builder sh -e -c "BOARD_SHORT=licheervnano ./make_image.sh"
