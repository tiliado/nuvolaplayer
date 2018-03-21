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

public class AudioOperation {
    private SourceFunc callback;
    protected PulseAudio.Operation? operation = null;

    public AudioOperation(owned SourceFunc callback) {
        this.callback = (owned) callback;
    }

    protected void finished() {
        if (operation != null) {
            if (operation.get_state() == PulseAudio.Operation.State.RUNNING) {
                operation.cancel();
            }
            operation = null;
        }
        Idle.add((owned) callback);
        callback = null;
    }
}

public class AudioSinkInfoOperation: AudioOperation {
    private SList<AudioSink?> sinks = null;

    public AudioSinkInfoOperation(owned SourceFunc callback) {
        base((owned) callback);
    }

    public void get_all(PulseAudio.Context context) {
        operation = context.get_sink_info_list(on_sink_info);
    }

    public void get_by_index(PulseAudio.Context context, uint32 index) {
        operation = context.get_sink_info_by_index(index, on_sink_info);
    }

    private void on_sink_info(PulseAudio.Context context, PulseAudio.SinkInfo? info, int eol) {
        if (eol > 0 || info == null) {
            sinks.reverse();
            finished();
            return;
        }
        AudioSinkPort[] ports = new AudioSinkPort[info.ports.length];
        for (var i = 0; i < ports.length; i++) {
            PulseAudio.SinkPortInfo* port = info.ports[i];
            ports[i] = {port->name, port->description, port->priority, (AudioPortAvailable) port->available};
        }
        AudioSink sink = {info.name, info.description, info.index, (owned) ports};
        sinks.prepend((owned) sink);
    }

    public SList<AudioSink?> get_result() {
        return (owned) sinks;
    }
}

public class AudioSinkInputListOperation: AudioOperation {
    private SList<AudioSinkInput?> inputs = null;

    public AudioSinkInputListOperation(owned SourceFunc callback) {
        base((owned) callback);
    }

    public void run(PulseAudio.Context context) {
        operation = context.get_sink_input_info_list(on_sink_input_info_list);
    }

    private void on_sink_input_info_list(PulseAudio.Context context, PulseAudio.SinkInputInfo? info, int eol) {
        if (eol > 0 || info == null) {
            inputs.reverse();
            finished();
            return;
        }

        unowned PulseAudio.Proplist props = info.proplist;
        unowned string? app_process_binary = props.gets(PulseAudio.Proplist.PROP_APPLICATION_PROCESS_BINARY) ?? "";
        unowned string? app_process_id = props.gets(PulseAudio.Proplist.PROP_APPLICATION_PROCESS_ID) ?? "0";
        AudioSinkInput input = {info.name, info.index, info.sink, info.client, app_process_binary, int.parse(app_process_id)};
        inputs.prepend((owned) input);
    }

    public SList<AudioSinkInput?> get_result() {
        return (owned) inputs;
    }
}

public class AudioCardInfoListOperation: AudioOperation {
    private SList<AudioCard?> cards = null;

    public AudioCardInfoListOperation(owned SourceFunc callback) {
        base((owned) callback);
    }

    public void run(PulseAudio.Context context) {
        operation = context.get_card_info_list(on_card_info_list);
    }

    private void on_card_info_list(PulseAudio.Context context, PulseAudio.CardInfo? info, int eol) {
        if (eol > 0 || info == null) {
            cards.reverse();
            finished();
            return;
        }

        AudioCard card = {info.name, info.index, info.driver};
        cards.prepend((owned) card);
    }

    public SList<AudioCard?> get_result() {
        return (owned) cards;
    }
}

public class AudioSubscribeOperation: AudioOperation {
    private int success = -1;

    public AudioSubscribeOperation(owned SourceFunc callback) {
        base((owned) callback);
    }

    public void run(PulseAudio.Context context, PulseAudio.Context.SubscriptionMask mask) {
        operation = context.subscribe(mask, on_subscribe);
    }

    private void on_subscribe(PulseAudio.Context context, int success) {
        this.success = success;
        finished();
    }

    public int get_result() {
        return success;
    }
}

public class AudioSinkInputMuteOperation: AudioOperation {
    private int success = -1;

    public AudioSinkInputMuteOperation(owned SourceFunc callback) {
        base((owned) callback);
    }

    public void run(PulseAudio.Context context, uint32 idx, bool mute) {
        operation = context.set_sink_input_mute(idx, mute, on_done);
    }

    private void on_done(PulseAudio.Context context, int success) {
        this.success = success;
        finished();
    }

    public int get_result() {
        return success;
    }
}

} // namespace Nuvola
