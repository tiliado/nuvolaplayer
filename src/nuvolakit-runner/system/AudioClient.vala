/*
 * Copyright 2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class AudioClient: GLib.Object {
    public PulseAudio.Context.State state {get; private set; default = PulseAudio.Context.State.UNCONNECTED;}
    public bool global_mute {get; set; default = false;}
    private PulseAudio.GLibMainLoop pa_loop;
    private PulseAudio.Context pa_context {get; private set; default = null;}

    public AudioClient() {
        pa_loop = new PulseAudio.GLibMainLoop();
        pa_context = new PulseAudio.Context(pa_loop.get_api(), null);
        pa_context.set_state_callback(on_pa_state_changed);
        pa_context.set_event_callback(on_pa_event);
        pa_context.set_subscribe_callback(on_pa_subscription);
        notify["global-mute"].connect_after(on_global_mute_changed);
    }

    ~AudioClient() {
        notify["global-mute"].disconnect(on_global_mute_changed);
    }

    public void start() throws AudioError {
        if (pa_context.connect(null, PulseAudio.Context.Flags.NOFAIL, null) < 0) {
            pa_context.disconnect();
            throw error_from_ctx(pa_context, "pa_context_connect() failed.");
        }
    }

    public async SList<AudioSink?> list_sinks() {
        var op = new AudioSinkInfoOperation(list_sinks.callback);
        op.get_all(pa_context);
        yield;
        return op.get_result();
    }

    public async AudioSink? get_sink_by_index(uint32 index) {
        var op = new AudioSinkInfoOperation(get_sink_by_index.callback);
        op.get_by_index(pa_context, index);
        yield;
        SList<AudioSink?> result = op.get_result();;
        if (result == null) {
            return null;
        }
        return result.data;
    }

    public async SList<AudioSinkInput?> list_sink_inputs() {
        var op = new AudioSinkInputListOperation(list_sink_inputs.callback);
        op.run(pa_context);
        yield;
        return op.get_result();
    }

    public async SList<AudioSinkInput?> list_own_sink_inputs() {
        SList<AudioSinkInput?>  inputs = yield list_sink_inputs();
        stdout.printf("inputs: %u\n", inputs.length());
        int own_pid = (int) Posix.getpid();
        SList<AudioSinkInput?>  own_inputs = null;
        foreach (unowned AudioSinkInput? input in inputs) {
            debug("Input %u.%u %s %s %i",
                input.sink, input.index, input.name, input.app_process_binary, input.app_process_id);
            int pid = input.app_process_id;
            do {
                if (pid == own_pid) {
                    own_inputs.prepend(input);
                    break;
                }
                pid = get_ppid(pid);
            } while (pid > 0);
        }
        own_inputs.reverse();
        return (owned) own_inputs;
    }

    public async int mute_sink_input(uint32 idx, bool mute) {
        var op = new AudioSinkInputMuteOperation(mute_sink_input.callback);
        op.run(pa_context, idx, mute);
        yield;
        return op.get_result();
    }

    public async int subscribe(PulseAudio.Context.SubscriptionMask mask) {
        var op = new AudioSubscribeOperation(subscribe.callback);
        op.run(pa_context, mask);
        yield;
        return op.get_result();
    }

    public signal void pulse_event(PulseAudio.Context.SubscriptionEventType event, uint32 id, string facility, string type);

    private void on_pa_state_changed(PulseAudio.Context context) {
        PulseAudio.Context.State state = context.get_state();
        this.state = state;
    }

    private void on_pa_event(PulseAudio.Context context, string name, PulseAudio.Proplist? proplist) {
        debug("PulseAudio Event %s: %s", name, proplist != null ? proplist.to_string() : null);
    }

    public static void parse_pulse_event(PulseAudio.Context.SubscriptionEventType event, out string facility, out string type) {
        switch (event & PulseAudio.Context.SubscriptionEventType.FACILITY_MASK) {
        case PulseAudio.Context.SubscriptionEventType.SINK_INPUT:
            facility = "sink-input";
            break;
        case PulseAudio.Context.SubscriptionEventType.SINK:
            facility = "sink";
            break;
        case PulseAudio.Context.SubscriptionEventType.SOURCE_OUTPUT:
            facility = "source-output";
            break;
        case PulseAudio.Context.SubscriptionEventType.SOURCE:
            facility = "source";
            break;
        case PulseAudio.Context.SubscriptionEventType.MODULE:
            facility = "module";
            break;
        case PulseAudio.Context.SubscriptionEventType.CLIENT:
            facility = "client";
            break;
        case PulseAudio.Context.SubscriptionEventType.SERVER:
            facility = "server";
            break;
        case PulseAudio.Context.SubscriptionEventType.SAMPLE_CACHE:
            facility = "sample-cache";
            break;
        case PulseAudio.Context.SubscriptionEventType.CARD:
            facility = "card";
            break;
        default:
            facility = "unknown";
            break;
        }

        switch (event & PulseAudio.Context.SubscriptionEventType.TYPE_MASK) {
        case PulseAudio.Context.SubscriptionEventType.NEW:
            type = "new";
            break;
        case PulseAudio.Context.SubscriptionEventType.CHANGE:
            type = "change";
            break;
        case PulseAudio.Context.SubscriptionEventType.REMOVE:
            type = "remove";
            break;
        default:
            type = "unknown";
            break;
        }
    }

    private void on_pa_subscription(PulseAudio.Context context, PulseAudio.Context.SubscriptionEventType event, uint32 id) {
        string facility = null;
        string type = null;
        parse_pulse_event(event, out facility, out type);
        pulse_event(event, id, facility, type);
        switch (event & PulseAudio.Context.SubscriptionEventType.FACILITY_MASK) {
        case PulseAudio.Context.SubscriptionEventType.SINK_INPUT:
            switch (event & PulseAudio.Context.SubscriptionEventType.TYPE_MASK) {
            case PulseAudio.Context.SubscriptionEventType.NEW:
                // PulseAudio remembers mute state, let's do reset.
                apply_global_mute.begin((o, res) => apply_global_mute.end(res));
                break;
            }
            break;
        }
    }

    private void on_global_mute_changed(GLib.Object? emitter, ParamSpec parameter) {
        apply_global_mute.begin((o, res) => apply_global_mute.end(res));
    }

    private async void apply_global_mute() {
        SList<AudioSinkInput?> inputs = yield list_own_sink_inputs();
        bool mute = global_mute;
        debug("Global mute: %s", mute.to_string());
        foreach (unowned AudioSinkInput? input in inputs) {
            yield mute_sink_input(input.index, mute);
        }
    }
}

} // namespace Nuvola
