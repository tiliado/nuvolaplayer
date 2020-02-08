/*
 * Copyright 2014-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public abstract class WebOptions : GLib.Object {
    public static WebOptions? create(Type type, WebAppStorage storage, Connection? connection) {
        return GLib.Object.@new(type, "storage", storage, "connection", connection) as WebOptions;
    }

    public WebAppStorage storage {get; construct;}
    public Connection? connection {get; construct;}
    public abstract VersionTuple engine_version {get; protected set;}

    protected WebOptions(WebAppStorage storage, Connection? connection) {
        GLib.Object(storage: storage, connection: connection);
    }

    public virtual async void gather_format_support_info(WebApp web_app) {
    }

    public bool check_engine_version(VersionTuple min, VersionTuple max= {0, 0, 0, 0}) {
        VersionTuple  version = engine_version;
        return version.is_greater_or_equal_to(min) && (max.empty() || version.is_lesser_than(max));
    }

    public abstract string get_name_version();
    public abstract string get_name();
    public abstract Drt.RequirementState supports_requirement(string type, string? parameter, out string? error);
    public abstract Drt.RequirementState supports_codec(string name, out string? error);
    public abstract Drt.RequirementState supports_feature(string name, out string? error);
    public abstract string[] get_format_support_warnings();

    public abstract WebEngine create_web_engine(WebApp web_app);

    public virtual void shutdown() {

    }

    public static string? make_user_agent(string? user_agent) {
        if (user_agent == null) {
            return null;
        }
        string agent = user_agent.split(" ")[0];
        switch (agent) {
        case "CHROME":
            return "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36";
        case "FIREFOX":
            return "Mozilla/5.0 (X11; Linux i586; rv:31.0) Gecko/20100101 Firefox/72.0";
        case "SAFARI":
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Safari/605.1.15";
        default:
            return user_agent;
        }
    }
}

} // namespace Nuvola
