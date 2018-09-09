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

public errordomain CefFlashDownloaderError {
    DOWNLOAD_FAILED,
    METADATA_ERROR,
    ARCHIVE_OPEN_FAILED,
    PLUGIN_NOT_FOUND,
    IO_ERROR;
}

public class CefFlashDownloader : GLib.Object, CefPluginDownloader {
    public const string FLASH_INFO_URL = "https://get.adobe.com/flashplayer/webservices/json/?platform_type=Linux&platform_arch=x86-64&browser_dist=Chrome";
    public const string FLASH_EULA_URL = "https://wwwimages2.adobe.com/www.adobe.com/content/dam/acom/en/legal/licenses-terms/pdf/PlatformClients_PC_WWEULA-en_US-20150407_1357.pdf";
    public string? latest_version {get; private set; default = null;}
    public string? latest_archive {get; private set; default = null;}
    private const string SECTION = "Flash";
    private const string KEY_CEF = "cef";
    private const string KEY_CHROMIUM = "chromium";
    private const string KEY_VERSION = "version";
    private Connection conn;
    private File target_dir;
    private File libflash_file;
    private File libmanifest_file;
    private File cef_version_file;
    private File version_file;

    public CefFlashDownloader (Connection conn, File target_dir) {
        this.conn = conn;
        this.target_dir = target_dir;
        this.libflash_file = target_dir.get_child(CefGtk.FlashPlugin.PLUGIN_FILENAME);
        this.libmanifest_file = target_dir.get_child(CefGtk.FlashPlugin.MANIFEST_FILENAME);
        this.cef_version_file = target_dir.get_child(CefGtk.FlashPlugin.VERSION_FILENAME);
        this.version_file = target_dir.get_child("version.txt");
    }

    public async void check_latest(Cancellable? cancellable=null) throws CefFlashDownloaderError {
        GLib.Bytes info_data;
        if (!yield conn.download_data(FLASH_INFO_URL, out info_data, null)) {
            throw new CefFlashDownloaderError.DOWNLOAD_FAILED("Cannot download '%s'.", FLASH_INFO_URL);
        }
        progress_text("Reading Flash metadata.");
        unowned string info_json = (string) info_data.get_data();
        string? download_url = null;
        string? version = null;
        try {
            Drt.JsonArray array = Drt.JsonParser.load_array(info_json);
            for (var i = 0; i < array.length; i++) {
                if (array.dotget_string("%d.download_url".printf(i), out download_url)
                && download_url.has_suffix(".x86_64.tar.gz")) {
                    array.dotget_string("%d.Version".printf(i), out version);
                    debug("Latest Flash version: %s", version);
                    break;
                } else {
                    download_url = null;
                }
            }
        } catch (Drt.JsonError e) {
            throw new CefFlashDownloaderError.METADATA_ERROR(
                "Failed to process Flash metadata. %s", Drt.error_to_string(e));
        } finally {
            latest_version = version;
            latest_archive = download_url;
        }
    }

    public bool exists() {
        return libflash_file.query_exists() && version_file.query_exists();
    }

    public bool needs_update() {
        if (!exists()) {
            return false;  // needs installation :-)
        }
        var meta = new KeyFile();
        try {
            meta.load_from_file(version_file.get_path(), GLib.KeyFileFlags.NONE);
            return meta.get_string(SECTION, KEY_VERSION) != latest_version;
        } catch (GLib.Error e) {
            warning("Failed to load flash version info. %s", e.message);
            return true;  // To be sure
        }
    }


    public async void download(Cancellable? cancellable=null) throws GLib.Error {
        yield make_backup(version_file, cancellable);
        yield make_backup(cef_version_file, cancellable);
        yield make_backup(libmanifest_file, cancellable);
        yield make_backup(libflash_file, cancellable);
        yield check_cancelled(cancellable);
        GLib.File tmp_dir = File.new_for_path(DirUtils.make_tmp("nuvola-XXXXXX"));
        try {
            if (latest_archive == null) {
                progress_text("Downloading Flash metadata.");
                yield check_latest(cancellable);
                yield check_cancelled(cancellable);
            }

            GLib.File archive_file = tmp_dir.get_child("flash.x86_64.tar.gz");
            if (!archive_file.query_exists()) {
                progress_text("Downloading Flash plugin.");
                yield check_cancelled(cancellable);
                bool downloaded = yield conn.download_file(latest_archive, archive_file, null);
                if (!downloaded) {
                    throw new CefFlashDownloaderError.DOWNLOAD_FAILED("Cannot download '%s'.", latest_archive);
                }
            }
            progress_text("Reading downloaded archive.");
            yield check_cancelled(cancellable);
            progress_text("Reading downloaded archive.");
            yield check_cancelled(cancellable);
            var reader = new ArchiveReader(archive_file.get_path(), 4 * 1024);
            unowned Archive.Entry? entry = null;
            bool found_plugin = false;
            bool found_manifest = false;
            while (!(found_plugin && found_manifest) && reader.next(out entry)) {
                if (entry.pathname().has_suffix(CefGtk.FlashPlugin.PLUGIN_FILENAME)) {
                    progress_text("Extracting Flash plugin library.");
                    yield check_cancelled(cancellable);
                    Drt.System.make_dirs(target_dir);
                    reader.read_data_to_file(libflash_file.get_path());
                    found_plugin = true;
                } else if (entry.pathname().has_suffix(CefGtk.FlashPlugin.MANIFEST_FILENAME)) {
                    progress_text("Extracting Flash plugin manifest.");
                    yield check_cancelled(cancellable);
                    Drt.System.make_dirs(target_dir);
                    reader.read_data_to_file(libmanifest_file.get_path());
                    found_manifest = true;
                }
                yield check_cancelled(cancellable);
            }
            if (!found_plugin || !found_manifest) {
                throw new CefFlashDownloaderError.PLUGIN_NOT_FOUND(
                    "Plugin not found in a file from '%s'.", latest_archive);
            }

            yield check_cancelled(cancellable);
            Drt.System.make_dirs(target_dir);
            var meta = new KeyFile();
            meta.set_int64(SECTION, "timestamp", new DateTime.now_utc().to_unix());
            meta.set_string(SECTION, "valacef", Cef.get_valacef_version());
            meta.set_string(SECTION, KEY_CEF, Cef.get_cef_version());
            meta.set_string(SECTION, KEY_CHROMIUM, Cef.get_chromium_version());
            meta.set_string(SECTION, KEY_VERSION, latest_version);

            try {
                meta.save_to_file(version_file.get_path());
                yield cef_version_file.replace_contents_async(
                    latest_version.data, null, false, FileCreateFlags.NONE, cancellable, null);
            } catch (GLib.Error e) {
                throw new CefFlashDownloaderError.IO_ERROR("Failed to write metadata. %s", Drt.error_to_string(e));
            }
            yield check_cancelled(cancellable);
        } finally {
            Drt.System.try_purge_dir(tmp_dir);
        }
        progress_text("Finished.");
    }

    private async void make_backup(GLib.File file, Cancellable? cancellable) throws GLib.Error {
        yield check_cancelled(cancellable);
        File target = file.get_parent().get_child(file.get_basename() + "~");
        try {
            file.move(target, GLib.FileCopyFlags.OVERWRITE, cancellable, null);
        } catch (GLib.Error e) {
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
