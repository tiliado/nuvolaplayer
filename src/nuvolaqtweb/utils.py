# Copyright 2020 Jiří Janoušek <janousek.jiri@gmail.com>
# Licensed under BSD-2-Clause license - see file LICENSE.
from typing import Iterator


class WrappedCounter(Iterator[int]):
    """
    A counter that wraps after the maximal value is reached.

    Args:
        start: The initial value.
        limit: The maximal value.

    Raises:
        ValueError: If start is not lesser than limit.
    """

    start: int
    """Initial value."""
    limit: int
    """The maximal value."""
    value: int
    """The next value to yield."""

    def __init__(self, start: int, limit: int):
        if start >= limit:
            raise ValueError(f'Start ({start}) must be lesser than limit ({limit}).')
        self.start = start
        self.limit = limit
        self.value = start

    def next(self) -> int:
        """Return the next value."""
        if self.value >= self.limit:
            self.value = self.start
            return self.limit

        value = self.value
        self.value += 1
        return value

    __next__ = next
