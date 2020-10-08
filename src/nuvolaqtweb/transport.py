# Copyright 2020 Jiří Janoušek <janousek.jiri@gmail.com>
# Licensed under BSD-2-Clause license - see file LICENSE.
from __future__ import annotations
from abc import ABC, abstractmethod
import array
from socket import AF_UNIX, SOCK_SEQPACKET, CMSG_SPACE, SOL_SOCKET, SCM_RIGHTS, MSG_EOR
from typing import NamedTuple, List, Tuple, cast

import trio
from trio import MemorySendChannel, MemoryReceiveChannel
from trio.socket import socket as create_socket


try:
    from trio._socket import _SocketType as SocketType
except ImportError:
    # This class is just a dummy without any methods.
    from trio.socket import SocketType

from nuvolaqtweb.types import Bytes, Fd, IPCError, INT_SIZE, INT32_SIZE
from nuvolaqtweb.convert import int32_to_bytes, int_from_bytes

HEADER_SIZE = 4 * INT32_SIZE


class Message(NamedTuple):
    """Message sent/received over a transport."""

    num: int
    """Message number."""
    flags: int
    """Arbitrary flags depending on the protocol."""
    data: Bytes
    """Message data."""
    fds: List[Fd]
    """File descriptors passed along with the msg."""


class TransportError(IPCError):
    pass


class NoDataError(TransportError):
    pass


class WrongSocketError(TransportError):
    pass


class ReadError(TransportError):
    pass


class WriteError(TransportError):
    pass


class WrongDataError(TransportError):
    pass


class Transport(ABC):
    """
    A class capable of reading/writing a message from/to a socket.

    Args:
        socket: The socket to read from/write to. The implementations may require a specific socket type.
    """
    SOCKET_TYPE = None, None
    socket: SocketType

    def __init__(self, socket: SocketType):
        self.socket = socket

        if self.SOCKET_TYPE == (None, None):
            raise NotImplementedError('SOCKET_TYPE must be overridden.')

    @classmethod
    def create_socket(cls) -> SocketType:
        """
        Create a socket suitable for this implementation.

        Returns:
            New socket.
        """
        return create_socket(*cls.SOCKET_TYPE)

    async def run(
        self,
        outgoing_payload_receiver: MemoryReceiveChannel[Message],
        incoming_payload_sender: MemorySendChannel[Message],
    ) -> None:
        await trio.sleep(0)

        async def reader():
            while True:
                await incoming_payload_sender.send(await self.read())

        async def writer():
            while True:
                msg = await outgoing_payload_receiver.receive()
                await self.write(cast(Message, msg))

        async with trio.open_nursery() as n:
            n.start_soon(writer)
            n.start_soon(reader)
        #outgoing_payload_sender, self._outgoing_payload_receiver = trio.open_memory_channel(0)
        #self._incoming_payload_sender, incoming_payload_receiver = trio.open_memory_channel(0)
        #return outgoing_payload_sender, incoming_payload_receiver

    @abstractmethod
    async def read(self) -> Message:
        """
        Read a message from a socket.

        Returns:
            A message.

        Raises:
            TransportError: Implementations typically return only subclasses of TransportError when an error occurs.
        """
        raise NotImplementedError

    @abstractmethod
    async def write(self, msg: Message) -> None:
        """
        Write a message to a socket.

        Args:
            msg: The message to send.

        Raises:
            TransportError: Implementations typically return only subclasses of TransportError when an error occurs.
        """
        raise NotImplementedError


class PacketTransport(Transport):
    """
    A transport backed by AF_UNIX SOCK_SEQPACKET socket.

    See Transport for information about parameters.

    Raises:
        WrongSocketError: If the passed socket is of a wrong type.

    Protocol:
        The first SEQPACKET record contains a msg header consisting of four 32bit integer values
        in machine byte order:

        1. Message number: May be used by a higher level protocol.
        2. Flags: May be used by a higher level protocol.
        3. Body size: the size of msg body in bytes.
        4. FDs count: the count of file descriptors passed with msg body.

        No ancillary data are sent in the first record.

        The second record contains both packet data and ancillary data.

        1. Packet data contain msg body of the size specified in the header.
        2. If fds count is greater than zero, ancillary data contain that number of file
          descriptors. Otherwise, no ancillary data is sent.

        The format of msg body is not defined by the transport protocol but by a higher level
        protocols. The meaning of message number and flags is also opaque for the transport protocol.

        Note that each SEQPACKET record must be read with with a single `recv`/`recvmsg` call.
        Otherwise, it is not considered as read and the same data are returned in the next call.
    """

    # The benefit of SOCK_SEQPACKET is that we can separate individual records with MSG_EOR, e.g.
    # to send msg header first and then msg body with file descriptors.
    SOCKET_TYPE = AF_UNIX, SOCK_SEQPACKET

    def __init__(self, socket: SocketType):
        super().__init__(socket)
        type_ = socket.family, socket.type
        if type_ != self.SOCKET_TYPE:
            raise WrongSocketError(f'Unsupported socket: {self.SOCKET_TYPE} expected, {type_} passed.')

    async def read(self) -> Message:
        """
        Read a message from a SEQPACKET socket.

        See Transport.read for information about returned values.

        This method is an unconditional trio checkpoint.

        Raises:
            NoDataError: If a read of zero bytes occurs. It may signalize a closed connection.
            ReadError: If an incomplete read of header/body occurs.
            WrongDataError: If socket msg contains unsupported ancillary data or the number
                of file descriptors is wrong.
        """
        await trio.sleep(0)

        # The first record is a msg header without any ancillary data. Each SEQPACKET record
        # must be read with with a single recv/recvmsg call with sufficient buffer size.
        header = await self.socket.recv(HEADER_SIZE)
        if len(header) == 0:
            raise NoDataError('Cannot read header.')  # Probably EOF
        if len(header) != HEADER_SIZE:
            raise ReadError(f'Incomplete header read: {header}.')

        num = int_from_bytes(header[0:INT32_SIZE])
        flags = int_from_bytes(header[INT32_SIZE:2 * INT32_SIZE])
        data_size = int_from_bytes(header[2 * INT32_SIZE:3 * INT32_SIZE])
        data = bytearray(data_size)
        n_fds = int_from_bytes(header[3 * INT32_SIZE:4 * INT32_SIZE])
        ancillary_size = CMSG_SPACE(INT_SIZE * n_fds) if n_fds else 0

        # The second record contains a msg body and file descriptors. Each SEQPACKET record
        # must be read with with a single recv/recvmsg call with sufficient buffer size.
        received, ancillary, _flags, _address = await self.socket.recvmsg_into([data], ancillary_size)
        if received != data_size:
            raise ReadError(f'Incomplete body received: {received}/{data_size} bytes.')

        fds: List[Fd] = []
        for level, type_, extra_data in ancillary:
            if level != SOL_SOCKET or type_ != SCM_RIGHTS:
                raise WrongDataError(
                    f'Unsupported ancillary data: level={level}, type={type_}, data={extra_data}')

            # File descriptors are received as native integer array.
            fds += [Fd(i) for i in array.array('i', extra_data)]

        if len(fds) != n_fds:
            raise WrongDataError(f'Wrong number of fds: {n_fds} expected, {len(fds)} received.')

        return Message(num, flags, data, fds)

    async def write(self, msg: Message) -> None:
        """
        Write a message to a SEQPACKET socket.

        See Transport.write for information about parameters.

        This method is an unconditional trio checkpoint.

        Raises:
            WriteError: When a socket write fails.
        """
        await trio.sleep(0)

        if msg.fds:
            # File descriptors are sent as native integer array.
            ancillary = [(SOL_SOCKET, SCM_RIGHTS, array.array('i', [fd.get() for fd in msg.fds]))]
            n_fds = len(msg.fds)
        else:
            ancillary = []
            n_fds = 0

        body_size = len(msg.data)
        header = int32_to_bytes(msg.num) + int32_to_bytes(msg.flags) + int32_to_bytes(body_size) + int32_to_bytes(n_fds)

        # The first record is a msg header without any ancillary data. MSG_EOR ends the record.
        sent = await self.socket.send(header, MSG_EOR)
        if sent != HEADER_SIZE:
            raise WriteError(f'Incomplete header written: {sent}/{HEADER_SIZE} bytes.')

        # The second record contains a msg body and file descriptors. MSG_EOR ends the record.
        sent = await self.socket.sendmsg([msg.data], ancillary, MSG_EOR)
        if sent != body_size:
            raise WriteError(f'Incomplete body written: {sent}/{body_size} bytes.')
