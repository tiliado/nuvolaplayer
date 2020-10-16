/*
 * Copyright 2018-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class HeadPhonesWatch: GLib.Object {
    public bool headphones_plugged {get; private set; default = false;}
    public AudioClient client {get; construct;}
    private uint32[] headphone_sink_ids = {};

    public HeadPhonesWatch(AudioClient client) {
        GLib.Object(client: client);
        if (client.state == PulseAudio.Context.State.READY) {
            start();
        } else {
            client.notify["state"].connect_after(on_client_state_changed);
        }
    }

    private void start() {
        client.pulse_event.connect(on_pulse_event);
        client.subscribe.begin(PulseAudio.Context.SubscriptionMask.ALL, (o, res) => {client.subscribe.end(res);});
        client.list_sinks.begin((o, res) => {
            SList<AudioSink?> sinks = client.list_sinks.end(res);
            foreach (unowned AudioSink sink in sinks) {
                debug("Sink %u %s - %s", sink.index, sink.name, sink.description);
                bool headphones_found = false;
                foreach (unowned AudioSinkPort port in sink.ports) {
                    debug("Sink %u Port: %s", sink.index, port.to_string());
                    if (port.are_headphones()) {
                        headphones_found = true;
                        if (port.available == AudioPortAvailable.YES && headphones_plugged == false) {
                            headphones_plugged = true;
                        }
                    }
                }
                if (headphones_found) {
                    headphone_sink_ids += sink.index;
                }
            }
        });
    }

    private void on_pulse_event(AudioClient client, PulseAudio.Context.SubscriptionEventType event, uint32 id, string facility, string type) {
        if ((event & PulseAudio.Context.SubscriptionEventType.FACILITY_MASK) == PulseAudio.Context.SubscriptionEventType.SINK) {
            switch (event & PulseAudio.Context.SubscriptionEventType.TYPE_MASK) {
            case PulseAudio.Context.SubscriptionEventType.NEW:
                break;
            case PulseAudio.Context.SubscriptionEventType.CHANGE:
                if (has_sink_headphones(id)) {
                    client.get_sink_by_index.begin(id, (o, res) => {
                        AudioSink? sink = client.get_sink_by_index.end(res);
                        if (sink != null) {
                            bool plugged = false;
                            foreach (unowned AudioSinkPort port in sink.ports) {
                                debug("Sink %u Port: %s", sink.index, port.to_string());
                                if (port.are_headphones() && port.available == AudioPortAvailable.YES) {
                                    plugged = true;
                                }
                            }
                            if (headphones_plugged != plugged) {
                                headphones_plugged = plugged;
                            }
                        }
                    });
                }
                break;
            case PulseAudio.Context.SubscriptionEventType.REMOVE:
                break;
            default:
                break;
            }
        }
    }

    private bool has_sink_headphones(uint32 sink_id) {
        foreach (var id in headphone_sink_ids) {
            if (id == sink_id) {
                return true;
            }
        }
        return false;
    }

    private void on_client_state_changed(GLib.Object o, ParamSpec p) {
        if (client.state == PulseAudio.Context.State.READY) {
            client.notify["state"].disconnect(on_client_state_changed);
            start();
        }
    }
}

} // namespace Nuvola
