#! /bin/sh

#find ./ -maxdepth 1 -path "*package/*" -a  ! -type f -a -exec rm -rf {} \;
#find ./ -maxdepth 2 -path "*package/*" -a -exec rm -rf {} \;
find ./ -maxdepth 1 -type d -print

#find ./ -path "*rootfs/*" -prune -o\
#    -path "*package/*" -prune -o\
#    -path "*MAKE/*" -prune -o\
#    -type d -a -print

