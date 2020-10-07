# Copyright 2020 Jiří Janoušek <janousek.jiri@gmail.com>
# Licensed under BSD-2-Clause license - see file LICENSE.
import struct
import sys

from nuvolaqtweb.types import Bytes, INT32_SIZE, INT64_SIZE, DOUBLE_SIZE


def int32_to_bytes(value: int) -> bytes:
    """Convert int32 into bytes in system byte order."""
    return value.to_bytes(INT32_SIZE, sys.byteorder)


def int64_to_bytes(value: int) -> bytes:
    """Convert int64 into bytes in system byte order."""
    return value.to_bytes(INT64_SIZE, sys.byteorder)


def int_from_bytes(value: Bytes) -> int:
    """
    Create int from bytes in system byte order.

    Args:
        value: The value to convert to int.

    Raises:
        ValueError: If the value is an empty buffer.
    """
    if not value:
        raise ValueError('Cannot convert empty buffer.')
    return int.from_bytes(value, sys.byteorder)


def float_to_bytes(value: float) -> bytes:
    """Convert float to bytes as double precision floating point number."""
    return struct.pack('d', value)


def float_from_bytes(value: Bytes) -> float:
    """
    Create float from bytes as double precision floating point number.

    Args:
        value: The value to convert. The length must be `DOUBLE_SIZE`.

    Return:
        The value as float.

    Raises:
        ValueError: On wrong value size.
    """
    if len(value) != DOUBLE_SIZE:
        raise ValueError(f'Wrong value size: {DOUBLE_SIZE} bytes expected, got {len(value)} bytes.')
    return struct.unpack('d', value)[0]
