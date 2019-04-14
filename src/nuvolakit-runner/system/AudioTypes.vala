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

public errordomain AudioError {
    GENERIC;
}

public struct AudioCard {
    string name;
    uint32 index;
    string driver;
}

public struct AudioSink {
    string name;
    string description;
    uint32 index;
    AudioSinkPort[] ports;
}

public struct AudioSinkInput {
    string name;
    uint32 index;
    uint32 sink;
    uint32 client;
    string app_process_binary;
    int app_process_id;
}

public struct AudioSinkPort {
    public string name;
    public string description;
    public uint32 priority;
    public AudioPortAvailable available;

    public string to_string() {
        return "%s: %s (priority %u, available: %s, headphones: %s)".printf(
            name, description, priority, available.to_string(), are_headphones() ? "yes" : "no");
    }

    public bool are_headphones() {
        return name.has_suffix("headphones");
    }
}

public enum AudioPortAvailable {
    UNKNOWN, /* This port does not support jack detection \since 2.0 */
    NO, /* This port is not available, likely because the jack is not plugged in. \since 2.0 */
    YES;     /* This port is available, likely because the jack is plugged in. \since 2.0 */

    public string to_string() {
        switch (this) {
        case YES:
            return "yes";
        case NO:
            return "no";
        case UNKNOWN:
            return "unknown";
        default:
            return "invalid value";
        }
    }
}

public static AudioError error_from_ctx(PulseAudio.Context context, string? msg=null) {
    return new AudioError.GENERIC("%d: %s %s", context.errno(), PulseAudio.strerror(context.errno()), msg);
}

int get_ppid(int pid) {
    string path = "/proc/%d/stat".printf(pid);
    string contents = null;
    size_t size;
    try {
        FileUtils.get_contents(path, out contents, out size);
    } catch (GLib.FileError e) {
        return -1;
    }
    if (size <= 0) {
        return -2;
    }

    string[] parts = contents.split(" ", 5);
    if (parts.length >= 3) {
        return int.parse(parts[3]);
    }
    return -3;
}

} // namespace Nuvola
