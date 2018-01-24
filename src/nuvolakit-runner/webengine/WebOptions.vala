/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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
    public static WebOptions? create(Type type, WebAppStorage storage) {
        return GLib.Object.@new(type, "storage", storage) as WebOptions;
    }

    public WebAppStorage storage {get; construct;}
    public abstract VersionTuple engine_version {get; protected set;}

    public WebOptions(WebAppStorage storage) {
        GLib.Object (storage: storage);
    }

    public virtual async void gather_format_support_info(WebApp web_app) {
    }

    public bool check_engine_version(VersionTuple min, VersionTuple max={0,0,0,0}) {
        var version = engine_version;
        return version.gte(min) && (max.empty() || version.lt(max));
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
        const string APPLE_WEBKIT_VERSION = "604.1";
        const string SAFARI_VERSION = "11.0";
        const string FIREFOX_VERSION = "57.0";
        const string CHROME_VERSION = "63.0.3239.108";
        string? agent = null;
        string? browser = null;
        string? version = null;
        if (user_agent != null) {
            agent = user_agent.strip();
            if (agent[0] == '\0')
            agent = null;
        }

        if (agent != null) {
            var parts = agent.split_set(" \t", 2);
            browser = parts[0];
            if (browser != null) {
                browser = browser.strip();
                if (browser[0] == '\0') {
                    browser = null;
                }
            }
            version = parts[1];
            if (version != null) {
                version = version.strip();
                if (version[0] == '\0') {
                    version = null;
                }
            }
        }

        switch (browser) {
        case "CHROME":
            var s = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/%s Safari/537.36";
            agent = s.printf(version ?? CHROME_VERSION);
            break;
        case "FIREFOX":
            var s = "Mozilla/5.0 (X11; Linux x86_64; rv:%1$s) Gecko/20100101 Firefox/%1$s";
            agent = s.printf(version ?? FIREFOX_VERSION);
            break;
        case "SAFARI":
            var s = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_2) AppleWebKit/%1$s (KHTML, like Gecko) Version/%2$s Safari/%1$s";
            agent = s.printf(APPLE_WEBKIT_VERSION, version ?? SAFARI_VERSION);
            break;
        case "WEBKIT":
            var s = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/%1$s (KHTML, like Gecko) Version/%2$s Safari/%1$s";
            agent = s.printf(APPLE_WEBKIT_VERSION, version ?? SAFARI_VERSION);
            break;
        }
        return agent;
    }
}

} // namespace Nuvola
