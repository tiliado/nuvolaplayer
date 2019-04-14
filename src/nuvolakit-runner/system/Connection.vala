/*
 * Copyright 2011-2019 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class Connection : GLib.Object {
    public const string PROXY_DIRECT = "direct://";
    private const string PROXY_TYPE_CONF = "webview.proxy.type";
    private const string PROXY_HOST_CONF = "webview.proxy.host";
    private const string PROXY_PORT_CONF = "webview.proxy.port";

    public Soup.Session session {get; construct set;}
    public File cache_dir {get; construct set;}
    public string? proxy_uri {get; private set; default = null;}
    private Config config;

    public Connection(Soup.Session session, File cache_dir, Config config) {
        Object(session: session, cache_dir: cache_dir);
        this.config = config;
        config.set_default_value(PROXY_TYPE_CONF, NetworkProxyType.SYSTEM.to_string());
        config.set_default_value(PROXY_HOST_CONF, "");
        config.set_default_value(PROXY_PORT_CONF, 0);
        apply_network_proxy();
    }

    public async bool download_file(string uri, File local_file, out Soup.Message msg=null) {
        GLib.Bytes data;
        if (!yield download_data(uri, out data, out msg)) {
            return false;
        }
        File dir = local_file.get_parent();
        if (!dir.query_exists(null)) {
            try {
                dir.make_directory_with_parents(null);
            } catch (GLib.Error e) {
                critical("Unable to create directory: %s", e.message);
            }
        }

        FileOutputStream stream;
        try {
            stream = local_file.replace(null, false, FileCreateFlags.REPLACE_DESTINATION, null);
        } catch (GLib.Error e) {
            critical("Unable to create local file: %s", e.message);
            return false;
        }

        try {
            stream.write_all(data.get_data(), null, null);
        } catch (IOError e) {
            critical("Unable to store remote file: %s", e.message);
            return false;
        }
        try {
            stream.close();
        } catch (IOError e) {
            warning("Unable to close stream: %s", e.message);
        }
        return true;
    }

    public async bool download_data(string uri, out GLib.Bytes data, out Soup.Message msg=null) {
        msg = new Soup.Message("GET", uri);
        data = null;
        SourceFunc resume = download_data.callback;
        session.queue_message(msg, (session, msg) => {resume();});
        yield;

        if (msg.status_code < 200 && msg.status_code >= 300) {
            return false;
        }

        unowned Soup.MessageBody body = msg.response_body;
        data = body.flatten().get_as_bytes();
        return true;
    }

    private void apply_network_proxy() {
        string? host;
        int port;
        NetworkProxyType type = get_network_proxy(out host, out port);
        if (type != NetworkProxyType.SYSTEM) {
            if (host == null || host == "") {
                host = "127.0.0.1";
            }
            switch (type) {
            case NetworkProxyType.HTTP:
                proxy_uri = "http://%s:%d/".printf(host, port);
                break;
            case NetworkProxyType.SOCKS:
                proxy_uri = "socks://%s:%d/".printf(host, port);
                break;
            default:
                proxy_uri = PROXY_DIRECT;
                break;
            }
            debug("Network Proxy: '%s'", proxy_uri);
            session.proxy_uri = new Soup.URI(proxy_uri);
        } else {
            debug("Network Proxy: system settings");
            proxy_uri = null;
            session.add_feature_by_type(typeof(Soup.ProxyResolverDefault));
        }
    }

    public void set_network_proxy(NetworkProxyType type, string? server, int port) {
        config.set_string(PROXY_TYPE_CONF, type.to_string());
        config.set_string(PROXY_HOST_CONF, server);
        config.set_int64(PROXY_PORT_CONF, (int64) port);
        apply_network_proxy();
    }

    public NetworkProxyType get_network_proxy(out string? host, out int port) {
        host = config.get_string(PROXY_HOST_CONF);
        port = (int) config.get_int64(PROXY_PORT_CONF);
        return NetworkProxyType.from_string(config.get_string(PROXY_TYPE_CONF));
    }
}

} // namespace Nuvola
