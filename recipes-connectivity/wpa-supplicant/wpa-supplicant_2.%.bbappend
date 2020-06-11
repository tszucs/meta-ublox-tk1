#
# Copyright (C) u-blox
#
# For additional copyright information see the LICENSE file in the root of this meta layer.
#

PV = "2.9"

LIC_FILES_CHKSUM = " \
    file://COPYING;md5=279b4f5abb9c153c285221855ddb78cc \
    file://README;beginline=1;endline=56;md5=e7d3dbb01f75f0b9799e192731d1e1ff \
    file://wpa_supplicant/wpa_supplicant.c;beginline=1;endline=12;md5=0a8b56d3543498b742b9c0e94cc2d18b \
"

SRC_URI_remove = "file://key-replay-cve-multiple.patch"

SRC_URI[md5sum] = "2d2958c782576dc9901092fbfecb4190"
SRC_URI[sha256sum] = "fcbdee7b4a64bea8177973299c8c824419c413ec2e3a95db63dd6a5dc3541f17"
