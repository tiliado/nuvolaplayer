# Copyright 2020 Jiří Janoušek <janousek.jiri@gmail.com>
# Licensed under BSD-2-Clause license - see file LICENSE.
from __future__ import annotations
import ctypes
import os
from typing import Any, Union, Dict, List, Tuple, Optional

import trio

INT_SIZE = ctypes.sizeof(ctypes.c_int)
"""The size of an integer in bytes on current platform."""
INT32_SIZE = 4
"""The size of a 32bit integer in bytes."""
INT64_SIZE = 8
"""The size of a 64bit integer in bytes."""
INT32_MAX = 2147483647
"""The value of the largest 32bit signed integer."""
DOUBLE_SIZE = 8
"""The size of a double precision floating point number in bytes."""

Buffer = Union[bytearray, memoryview]
"""Types accepted as read-write byte buffers."""
Bytes = Union[bytes, bytearray, memoryview]
"""Types holding binary data which may be read only."""

Value = Union[
    None, bool, int, float, str, bytes, bytearray, memoryview, 'Fd',
    Dict[str, 'Value'], List['Value'], Tuple['Value', ...]]


class IPCError(Exception):
    """Inter-process communication error."""


class ResponseError(IPCError):
    def __init__(self, code: int, message: str):
        super().__init__(code, message)
        self.code = code
        self.message = message


class Fd:
    """
    File descriptor container with automatic closing.

    Args:
        value: The value of the file descriptor.
        duplicate: Whether to duplicate the file descriptor first.
    """

    _value: int
    _auto_close: bool

    def __init__(self, value: int, *, duplicate: bool = False):
        if value < 0:
            raise ValueError(f'Invalid file descriptor: {value}')
        if duplicate:
            value = os.dup(value)
        self._value = value
        self._auto_close = True

    @property
    def owned(self) -> bool:
        """
        Whether the file descriptor will be closed when the container is destroyed.

        You can transfer ownership with the `take` method.
        """
        return self._auto_close

    def get(self) -> int:
        """Get the value of the file descriptor."""
        return self._value

    def take(self) -> int:
        """
        Take the ownership of the file descriptor.

        Your responsibility is to close the file descriptor when not in use.

        Returns:
             The value of file descriptor.
        Raises:
            ValueError: If the value is empty.
        """
        if self._auto_close:
            self._auto_close = False
            return self._value

        return os.dup(self._value)

    def close(self) -> None:
        """Close the file descriptor early."""
        if self._auto_close:
            self._auto_close = False
            os.close(self._value)

    def __del__(self):
        self.close()

    def __str__(self) -> str:
        return f'fd:{self._value!r}'

    def __repr__(self) -> str:
        return f'Fd({self._value!r}, {self._auto_close!r})'

    def __eq__(self, other: Any) -> bool:
        return isinstance(other, Fd) and other._value == self._value


class Result:
    """
    Synchronization primitive for asynchronous result.

    The initiating tasks waits for the results via `wait` until another task sets value/error
    via `set`/`fail`.

    """

    value: Optional[Value] = None
    """The result of an asynchronous task."""
    error: Optional[Exception] = None
    """The failure of an asynchronous task."""

    def __init__(self):
        self._event = trio.Event()

    def set(self, value: Optional[Value] = None) -> None:
        """Set the result of an asynchronous task and mark it as finished."""
        self.value = value
        self._event.set()

    def fail(self, error: Exception) -> None:
        """Set the failure of an asynchronous task and mark it as finished."""
        self.error = error
        self._event.set()

    async def wait(self) -> None:
        """Wait for the result of an asynchronous task."""
        await self._event.wait()

    def get(self) -> Optional[Value]:
        """
        Get the value or raise an error.

        Returns: The value set with `set`.

        Raises:
            Exception: Any exception set with `fail`.
        """
        if self.error is not None:
            raise self.error
        return self.value
