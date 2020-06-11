#!/usr/bin/env python
"""
    CRC-32 forcer (Python)
    Compatible with Python 2 and 3.

    Author: Robert Noack (robert.noack@u-blox.com)

    Copyright notice of the original algorithm:

    Copyright (c) 2016 Project Nayuki
    https://www.nayuki.io/page/forcing-a-files-crc-to-any-value

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program (see COPYING.txt).
    If not, see <http://www.gnu.org/licenses/>.
"""
import argparse
import logging
import os.path as path
import shutil
import struct
import sys
import zlib

log = logging.getLogger('forcecrc32')


def get_arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument('newcrc',
                        help='The new checksum of the created file.')
    parser.add_argument('input', metavar='file', nargs='+',
                        help='Files to modify.')
    parser.add_argument('-d', dest='debug', action='store_true',
                        help='Enable debug output.')
    parser.add_argument('-o', dest='outdir', default=None,
                        help='Specify where to store modified files. Default is the current directory.')
    return parser.parse_args()


def main():
    args = get_arguments()

    loglevel = logging.DEBUG if args.debug else logging.INFO
    logging.basicConfig(level=loglevel)

    newcrc = arg_to_crc32(args.newcrc)
    if not newcrc:
        return 'Invalid new CRC-32 value.'

    try:
        for filename in args.input:
            newfile = create_file(path.abspath(filename), args.outdir)
            update_file(newfile, newcrc)
    except RuntimeError:
        return 'An error occurred.'

    return 0


def create_file(filename, outdir):
    """
    Make a copy of filename in outdir, additionally append 4 null-bytes to the file.

    :return Path to the created file.
    """
    if not path.exists(filename):
        raise RuntimeError('File does not exist: {}'.format(filename))

    if outdir is None:
        outdir = path.dirname(filename)
    elif not path.exists(outdir):
        raise RuntimeError('Output directory does not exist: {}'.format(outdir))

    log.debug('Looking at file: {}'.format(filename))

    newfilename = '{}/{}.crc32'.format(outdir, path.basename(filename))
    shutil.copyfile(filename, newfilename)
    log.debug('New file: {}'.format(newfilename))

    with open(newfilename, 'ab') as raf:
        raf.write(struct.pack('I', 0))

    return newfilename


def update_file(filename, newcrc):
    """
        Update filename so that its crc is equal to newcrc. The last four bytes will be updated.
    """
    with open(filename, 'r+b') as raf:
        length = path.getsize(filename)
        offset = length - 4

        # Read entire file and calculate original CRC-32 value
        crc = get_crc32(raf)
        log.debug('Original CRC-32: {:08X}'.format(reverse32(crc)))

        # compute the change to make
        delta = crc ^ newcrc
        delta = multiply_mod(reciprocal_mod(pow_mod(2, (length - offset) * 8)), delta)

        # patch 4 bytes in the file
        raf.seek(offset)
        bytes4 = bytearray(raf.read(4))
        for i in range(4):
            bytes4[i] ^= (reverse32(delta) >> (i * 8)) & 0xFF
        raf.seek(offset)
        raf.write(bytes4)

        log.debug('Patched new file.')

        # Recheck entire file
        if get_crc32(raf) != newcrc:
            raise AssertionError('Failed to update CRC-32 to desired value.')
        log.debug('New CRC-32 successfully verified.')
        # with


POLYNOMIAL = 0x104C11DB7  # Generator polynomial. Do not modify, because there are many dependencies
MASK = (1 << 32) - 1


def arg_to_crc32(crc):
    """
        Create a proper crc32 integer from the input argument.
    """
    result = False
    try:
        if isinstance(crc, str):
            if len(crc) != 8 or crc.startswith(('+', '-')):
                return result
            temp = int(crc, 16)
        else:
            temp = crc
        if temp & MASK != temp:
            return result
        return reverse32(temp)
    except ValueError:
        return result


def get_crc32(raf):
    raf.seek(0)
    crc = 0
    while True:
        buf = raf.read(128 * 1024)
        if len(buf) == 0:
            return reverse32(crc & MASK)
        else:
            crc = zlib.crc32(buf, crc)


def reverse32(x):
    y = 0
    for i in range(32):
        y = (y << 1) | (x & 1)
        x >>= 1
    return y


def multiply_mod(x, y):
    """
        Returns polynomial x multiplied by polynomial y modulo the generator polynomial.
    """
    # Russian peasant multiplication algorithm
    z = 0
    while y != 0:
        z ^= x * (y & 1)
        y >>= 1
        x <<= 1
        if x & (1 << 32) != 0:
            x ^= POLYNOMIAL
    return z


def pow_mod(x, y):
    """
        Returns polynomial x to the power of natural number y modulo the generator polynomial.
    """
    # Exponentiation by squaring
    z = 1
    while y != 0:
        if y & 1 != 0:
            z = multiply_mod(z, x)
        x = multiply_mod(x, x)
        y >>= 1
    return z


def reciprocal_mod(x):
    """
        Returns the reciprocal of polynomial x with respect to the modulus polynomial m.
    """
    # Based on a simplification of the extended Euclidean algorithm
    y = x
    x = POLYNOMIAL
    a = 0
    b = 1
    while y != 0:
        divrem = divide_and_remainder(x, y)
        c = a ^ multiply_mod(divrem[0], b)
        x = y
        y = divrem[1]
        a = b
        b = c
    if x == 1:
        return a
    else:
        raise ValueError("Reciprocal does not exist")


def divide_and_remainder(x, y):
    """
        Computes polynomial x divided by polynomial y, returning the quotient and remainder.
    """
    if y == 0:
        raise ValueError("Division by zero")
    if x == 0:
        return 0, 0

    ydeg = get_degree(y)
    z = 0
    for i in range(get_degree(x) - ydeg, -1, -1):
        if x & (1 << (i + ydeg)) != 0:
            x ^= y << i
            z |= 1 << i
    return z, x


def get_degree(x):
    if x == 0:
        return -1
    i = 0
    while True:
        if x >> i == 1:
            return i
        i += 1


if __name__ == '__main__':
    sys.exit(main())
