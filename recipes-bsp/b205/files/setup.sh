#!/bin/sh

opkg update && \
opkg install \
        gcc \
        binutils \
        python-dev && \

pip install --upgrade pip && \
pip install \
        spidev \
        pyftdi && \

echo Setup successfully completed
