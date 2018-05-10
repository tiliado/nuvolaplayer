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

#if HAVE_CEF
namespace Nuvola {

public errordomain CefWidevineDownloaderError {
    DOWNLOAD_FAILED,
    ARCHIVE_OPEN_FAILED,
    PLUGIN_NOT_FOUND;
}

public class CefWidevineDownloader : GLib.Object {
    public const string CHROME_EULA_URL = "https://www.google.com/intl/en/chrome/browser/privacy/eula_text.html";
    public const string CHROME_DEB_URL = "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb";
    private Connection conn;
    private File target_dir;
    private File libwidevinecdm_file;
    private File libadapter_file;
    private File version_file;

    public CefWidevineDownloader (Connection conn, File target_dir) {
        this.conn = conn;
        this.target_dir = target_dir;
        this.libwidevinecdm_file = target_dir.get_child("libwidevinecdm.so");
        this.libadapter_file = target_dir.get_child("libwidevinecdmadapter.so");
        this.version_file = target_dir.get_child("version.txt");
    }

    public bool exists() {
        return libwidevinecdm_file.query_exists();
    }

    public signal void progress_text(string text);

    public async void download(Cancellable? cancellable=null) throws GLib.Error {
        yield check_cancelled(cancellable);
        bool found = false;
        bool found_adapter = false;
        GLib.File tmp_dir = File.new_for_path(DirUtils.make_tmp("nuvola-XXXXXX"));
        try {
            // For testing: GLib.File deb_file = target_dir.get_child("chrome.ar");
            GLib.File deb_file = tmp_dir.get_child("chrome.ar");
            if (!deb_file.query_exists()) {
                progress_text("Downloading Google Chrome.");
                yield check_cancelled(cancellable);
                bool downloaded = yield conn.download_file(CHROME_DEB_URL, deb_file, null);
                if (!downloaded) {
                    throw new CefWidevineDownloaderError.DOWNLOAD_FAILED("Cannot download '%s'.", CHROME_DEB_URL);
                }
            }
            progress_text("Reading downloaded archive.");
            yield check_cancelled(cancellable);
            var reader = new ArchiveReader(deb_file.get_path(), 4 * 1024);
            unowned Archive.Entry? entry = null;
            bool found_data = false;
            bool found_control = false;
            while (!(found_data && found_control) && reader.next(out entry)) {
                if (entry.pathname().has_prefix("data.tar.")) {
                    ArchiveReader reader2 = reader.read_archive();
                    unowned Archive.Entry? entry2 = null;
                    while (!(found && found_adapter) && reader2.next(out entry2)) {
                        if (entry2.pathname().has_suffix("/libwidevinecdm.so")) {
                            progress_text("Extracting Widevine plugin library.");
                            yield check_cancelled(cancellable);
                            Drt.System.make_dirs(target_dir);
                            reader2.read_data_to_file(libwidevinecdm_file.get_path());
                            found = true;
                        } else if (entry2.pathname().has_suffix("/libwidevinecdmadapter.so")) {
                            progress_text("Extracting Widevine plugin adapter.");
                            yield check_cancelled(cancellable);
                            Drt.System.make_dirs(target_dir);
                            reader2.read_data_to_file(libadapter_file.get_path());
                            found_adapter = true;
                        }
                        yield check_cancelled(cancellable);
                    }
                    found_data = true;
                } else if (entry.pathname().has_prefix("control.tar")) {
                    ArchiveReader reader2 = reader.read_archive();
                    unowned Archive.Entry? entry2 = null;
                    while (reader2.next(out entry2)) {
                        if (entry2.pathname().has_suffix("/control")) {
                            progress_text("Extracting Widevine plugin metadata.");
                            yield check_cancelled(cancellable);
                            Drt.System.make_dirs(target_dir);
                            reader2.read_data_to_file(version_file.get_path());
                            var meta = new KeyFile();
                            meta.set_int64("Widevine", "timestamp", new DateTime.now_utc().to_unix());
                            meta.set_string("Widevine", "valacef", Cef.get_valacef_version());
                            meta.set_string("Widevine", "cef", Cef.get_cef_version());
                            uint8[] data = null;
                            try {
                                yield version_file.load_contents_async(null, out data, null);
                                unowned string? data_str = (string?) data;
                                if (data_str != null) {
                                    string[] lines = data_str.split("\n");
                                    foreach (unowned string? line in lines) {
                                        if (line.has_prefix("Version:")) {
                                            string[] parts = line.split(":");
                                            if (parts.length > 1) {
                                                parts = parts[1].split("-");
                                                meta.set_string("Widevine", "chrome", parts[0].strip());
                                            }
                                        }
                                    }
                                }
                            } catch (GLib.Error e) {
                                warning("Failed to read metadata. %s", e.message);
                            }
                            try {
                                meta.save_to_file(version_file.get_path());
                            } catch (GLib.Error e) {
                                warning("Failed to write metadata. %s", e.message);
                            }
                            break;
                        }
                        yield check_cancelled(cancellable);
                    }
                    found_control = true;
                }
                yield check_cancelled(cancellable);
            }
        } finally {
            Drt.System.try_purge_dir(tmp_dir);
        }
        if (!found) {
            throw new CefWidevineDownloaderError.PLUGIN_NOT_FOUND(
                "Plugin not found in a file from '%s'.", CHROME_DEB_URL);
        } else {
            progress_text("Finished.");
        }
    }

    private static async void check_cancelled(Cancellable? cancellable) throws GLib.Error {
        Idle.add(check_cancelled.callback);
        yield;
        if (cancellable != null && cancellable.is_cancelled()) {
            throw new GLib.IOError.CANCELLED("Operation has been cancelled");
        }
    }
}

} // namespace Nuvola
#endif
