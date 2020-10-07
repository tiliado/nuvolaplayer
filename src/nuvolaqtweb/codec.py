# Copyright 2020 Jiří Janoušek <janousek.jiri@gmail.com>
# Licensed under BSD-2-Clause license - see file LICENSE.
from __future__ import annotations
import struct
from abc import ABC, abstractmethod
from collections import OrderedDict
from enum import unique, IntEnum
from typing import Union, List, Tuple, cast

from nuvolaqtweb.types import Fd, Bytes, IPCError
from nuvolaqtweb.convert import int32_to_bytes, int64_to_bytes, int_from_bytes, float_to_bytes, float_from_bytes

from nuvolaqtweb.types import Value


@unique
class Marker(IntEnum):
    """Markers of data types and data structures in encoded message."""
    FALSE = 0
    TRUE = 1
    NONE = 2
    INT64 = 3
    DOUBLE = 4
    STRING = 5
    BYTES = 6
    ARRAY_START = 7
    ARRAY_END = 8
    DICT_START = 9
    DICT_END = 10
    FD = 11


class CodecError(IPCError):
    """An error occurring during encoding/decoding."""


class EncoderError(CodecError):
    """An error occurring during encoding."""


class DecoderError(CodecError):
    """An error occurring during decoding."""


class Codec(ABC):
    """A codec encodes a message to bytes and decodes bytes to a message."""

    @abstractmethod
    def encode(self, msg: Value) -> Tuple[Bytes, List[Fd]]:
        """
        Encode message as binary data.

        Implementations may differ in the exact type of the message.

        Args:
            msg: A message to encode.

        Returns:
            A tuple (data, fds) where data are encoded data and fds are file descriptors
            to send along with the data.

        Raises:
            EncoderError: On failure.
        """
        raise NotImplementedError

    @abstractmethod
    def decode(self, data: Bytes, fds: List[Fd]) -> Value:
        """
        Decode message from binary data.

        Implementations may differ in the exact type of the message.

        Args:
            data: Data to deserialize.
            fds: File descriptors to attach to decoded message.

        Returns:
             Decoded message.

        Raises:
            DecoderError: On failure.
        """
        raise NotImplementedError


class BinaryCodec(Codec):
    """Binary codec packs data in a binary structure."""

    def encode(self, msg: Value) -> Tuple[Bytes, List[Fd]]:
        """
        Encode a message.

        See function serialize for details.
        """
        return serialize(msg)

    def decode(self, data: Bytes, fds: List[Fd]) -> Value:
        """
        Decode a message.

        See function deserialize for details.
        """
        return deserialize(data, fds)


def serialize(value: Value) -> Tuple[bytearray, List[Fd]]:
    """
    Serialize a subset of native Python types.

    See Value for supported types.

    Args:
        value: Data to serialize.

    Returns:
        A tuple (data, fds) where data are serialized data and fds are file descriptors
        to send along with the data.

    Raises:
        EncoderError: On failure.
    """
    data = bytearray()
    fds: List[Fd] = []
    _serialize(data, fds, value)
    return data, fds


def _serialize(buffer: bytearray, fds: List[Fd], value: Value) -> None:
    # TODO: refactor to reduce complexity
    if value is None:
        buffer += int32_to_bytes(Marker.NONE)
    elif value is True:
        buffer += int32_to_bytes(Marker.TRUE)
    elif value is False:
        buffer += int32_to_bytes(Marker.FALSE)
    elif isinstance(value, int):
        buffer += int32_to_bytes(Marker.INT64)
        buffer += int64_to_bytes(value)
    elif isinstance(value, float):
        buffer += int32_to_bytes(Marker.DOUBLE)
        buffer += float_to_bytes(value)
    elif isinstance(value, str):
        value = value.encode('utf-8')
        buffer += int32_to_bytes(Marker.STRING)
        buffer += int32_to_bytes(len(value))  # Without terminating \0
        buffer += value  # Without terminating \0
        buffer += b"\0"
    elif isinstance(value, (bytes, memoryview)):
        buffer += int32_to_bytes(Marker.BYTES)
        buffer += int32_to_bytes(len(value))
        buffer += value
    elif isinstance(value, (list, tuple)):
        buffer += int32_to_bytes(Marker.ARRAY_START)
        for item in value:
            _serialize(buffer, fds, item)
        buffer += int32_to_bytes(Marker.ARRAY_END)
    elif isinstance(value, (dict, OrderedDict)):
        buffer += int32_to_bytes(Marker.DICT_START)
        for key, value in value.items():
            _serialize(buffer, fds, key)
            _serialize(buffer, fds, value)
        buffer += int32_to_bytes(Marker.DICT_END)
    elif isinstance(value, Fd):
        buffer += int32_to_bytes(Marker.FD)
        buffer += int32_to_bytes(len(fds))
        fds.append(value)
    else:
        raise EncoderError(f'Unsupported type {type(value)} for value {value!r}.')


def deserialize(data: Union[bytes, bytearray, memoryview], fds: List[Fd]) -> Value:
    """
    Deserialize data to subset of native Python types.

    See Value for supported types.

    Args:
        data: Data to deserialize.
        fds: File descriptors to attach to deserialized data.

    Returns:
         Deserialized data.

    Raises:
        DecoderError: On failure.
    """
    if not isinstance(data, memoryview):
        data = memoryview(data)

    try:
        end, value = _deserialize(fds, data)
    except (ValueError, IndexError, struct.error) as e:
        raise DecoderError(f'Decoder failure: {e}')
    if end:
        raise DecoderError(f'Decoding ended with extra data: {end.tobytes()}.')
    if isinstance(value, Marker):
        raise DecoderError(f'Value cannot be {value}.')
    return value


def _deserialize(fds: List[Fd], data: memoryview) -> Tuple[memoryview, Union[Marker, Value]]:
    # TODO: refactor to reduce complexity
    type_ = int_from_bytes(data[0:4])
    if type_ == Marker.NONE:
        return data[4:], None
    if type_ == Marker.FALSE:
        return data[4:], False
    if type_ == Marker.TRUE:
        return data[4:], True
    if type_ == Marker.FD:
        return data[8:], fds[int_from_bytes(data[4:8])]
    if type_ == Marker.INT64:
        return data[12:], int_from_bytes(data[4:12])
    if type_ == Marker.DOUBLE:
        return data[12:], float_from_bytes(data[4:12])
    if type_ == Marker.STRING:
        end = 8 + int_from_bytes(data[4:8]) + 1  # String + terminating \0
        return data[end:], str(cast(bytes, data[8:end - 1]), encoding='utf-8')  # Without \0
    if type_ == Marker.BYTES:
        end = 8 + int_from_bytes(data[4:8])
        return data[end:], data[8:end].tobytes()
    if type_ == Marker.ARRAY_START:
        result = []
        data = data[4:]

        while True:
            data, value = _deserialize(fds, data)
            if value is Marker.ARRAY_END:
                break
            if isinstance(value, Marker):
                raise DecoderError(f'Value cannot be {value}.')
            result.append(value)
        return data, result
    if type_ == Marker.DICT_START:
        result = {}
        data = data[4:]

        while True:
            data, key = _deserialize(fds, data)
            if key is Marker.DICT_END:
                break
            if isinstance(key, Marker):
                raise DecoderError(f'Value cannot be {key}.')

            data, value = _deserialize(fds, data)
            if isinstance(value, Marker):
                raise DecoderError(f'Value cannot be {value}.')
            result[key] = value
        return data, result

    if type_ == Marker.DICT_END:
        return data[4:], Marker.DICT_END
    if type_ == Marker.ARRAY_END:
        return data[4:], Marker.ARRAY_END
    raise DecoderError(f'Unknown data type: {type_}.')


