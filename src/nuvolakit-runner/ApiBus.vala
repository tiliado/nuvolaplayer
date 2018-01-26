/*
 * Copyright 2016-2018 Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

namespace Nuvola {

const int IPC_TIMEOUT = 60000;

public class IpcBus: Drt.RpcBus {
    public Drt.RpcChannel? master {get; private set; default = null;}
    public Drt.RpcChannel? web_worker {get; private set; default = null;}

    public IpcBus(string bus_name, Drt.RpcRouter? router=null) {
        base(bus_name, router ?? new Drt.RpcRouter(), IPC_TIMEOUT);
    }

    public Drt.RpcChannel? connect_master(string bus_name, string? api_token) throws Drt.IOError {
        return_val_if_fail(master == null, null);
        master = connect_channel(bus_name, IPC_TIMEOUT);
        master.api_token = api_token;
        return master;
    }

    public Drt.RpcChannel? connect_master_socket(Socket socket, string? api_token) throws Drt.IOError {
        return_val_if_fail(master == null, null);
        master = connect_channel_socket(socket, IPC_TIMEOUT);
        master.api_token = api_token;
        return master;
    }

    public void connect_web_worker(Drt.RpcChannel channel) {
        web_worker = channel;
    }
}

} // namespace Nuvola
