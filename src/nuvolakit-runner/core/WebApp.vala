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

public class WebApp : GLib.Object {
    /**
     * Name of file with metadata.
     */
    public const string METADATA_FILENAME = "metadata.json";
    public const string DEFAULT_CATEGORY = "Network";

    /**
     * Regular expression to check validity of service identifier
     */
    private static Regex id_regex;

    /**
     * Check if the service identifier is valid
     *
     * @param id service identifier
     * @return true if id is valid
     */
    public static bool validate_id(string id) {
        const string ID_REGEX = "^[a-z0-9]+(?:_[a-z0-9]+)*$";
        if (id_regex == null) {
            try {
                id_regex = new Regex(ID_REGEX);
            } catch (RegexError e) {
                error("Unable to compile regular expression /%s/.", ID_REGEX);
            }
        }
        return id_regex.match(id);
    }

    public static string build_uid_from_app_id(string app_id, string? base_id=null) {
        var buffer = new StringBuilder(base_id ?? Nuvola.get_app_uid());
        buffer.append("App");
        foreach (string part in app_id.split("_")) {
            buffer.append_c(part[0].toupper());
            if (part.length > 1) {
                buffer.append(part.substring(1));
            }
        }
        return buffer.str;
    }

    public string id {get; construct; default = null;}
    public string name {get; construct; default = null;}
    public string maintainer_name {get; construct; default = null;}
    public string maintainer_link {get; construct; default = null;}
    public int version_major {get; construct; default = 0;}
    public int version_minor {get; construct; default = 0;}
    public int version_micro {get; construct; default = 0;}
    public string? version_revision {get; construct; default = null;}
    public int api_major {get; construct; default = 0;}
    public int api_minor {get; construct; default = 0;}
    public string? user_agent {get; set; default = null;}
    public string? requirements {get; construct; default = null;}
    public string? home_url {get; construct; default = null;}
    public int window_width {get; construct; default = 0;}
    public int window_height {get; construct; default = 0;}
    public File? data_dir {get; construct; default = null;}
    public bool hidden {get; set; default = false;}
    public bool allow_insecure_content {get; set; default = false;}
    public double scale_factor {get; set; default = 0.0;}
    public GenericSet<string> categories {get; construct;}
    private List<IconInfo?> icons = null;
    private bool icons_set = false;

    /**
     * Creates new WebApp metadata object
     *
     * @param id    web app id
     * @param name    web app name
     * @param maintainer_name    the name of the maintainer
     * @param maintainer_link    the URL of the maintainer
     * @param version_major      major version of the script
     * @param version_minor      minor version of the script
     * @param api_major          major version of Nuvola API
     * @param api_minor          minor version of Nuvola API
     * @param data_dir    corresponding data directory of the web app to load
     * @param requirements      format requirements of the web app
     * @param categories        desktop app categories
     * @param window_width      default window width
     * @param window_height     default window height
     **/
    public WebApp(string id, string name, string maintainer_name, string maintainer_link,
        int version_major, int version_minor, int version_micro, string? version_revision,
        int api_major, int api_minor, File? data_dir,
        string? requirements, GenericSet<string>? categories, int window_width, int window_height,
        string? home_url=null) throws WebAppError {
        if (!WebApp.validate_id(id)) {
            throw new WebAppError.INVALID_METADATA("Invalid app id '%s'.", id);
        }
        if (name == "") {
            throw new WebAppError.INVALID_METADATA("Empty 'name' entry");
        }
        if (version_major <= 0) {
            throw new WebAppError.INVALID_METADATA("Major version must be greater than zero");
        }
        if (version_minor < 0) {
            throw new WebAppError.INVALID_METADATA("Minor version must be greater or equal to zero");
        }
        if (version_micro < 0) {
            throw new WebAppError.INVALID_METADATA("Micro version must be greater or equal to zero");
        }
        if (api_major <= 0) {
            throw new WebAppError.INVALID_METADATA("Major api_version must be greater than zero");
        }
        if (api_minor < 0) {
            throw new WebAppError.INVALID_METADATA("Minor api_version must be greater or equal to zero");
        }
        if (!JSApi.is_supported(api_major, api_minor)) {
            throw new WebAppError.INVALID_METADATA(
                "Requested unsupported NuvolaKit API '%d.%d'.".printf(api_major, api_minor));
        }
        if (maintainer_name == "") {
            throw new WebAppError.INVALID_METADATA("Empty 'maintainer_name' entry");
        }
        if (!maintainer_link.has_prefix("http://")
        &&  !maintainer_link.has_prefix("https://")
        &&  !maintainer_link.has_prefix("mailto:")) {
            throw new WebAppError.INVALID_METADATA("Empty or invalid 'maintainer_link' entry: '%s'", maintainer_link);
        }
        if (window_width < 0) {
            throw new WebAppError.INVALID_METADATA("Property window_width must be greater or equal to zero");
        }
        if (window_height < 0) {
            throw new WebAppError.INVALID_METADATA("Property window_height must be greater or equal to zero");
        }

        GLib.Object(id: id, name: name, maintainer_name: maintainer_name, maintainer_link: maintainer_link,
            version_major: version_major, version_minor: version_minor, version_micro: version_micro,
            version_revision: version_revision, api_major: api_major, api_minor: api_minor,
            data_dir: data_dir, window_width: window_width, window_height: window_height,
            categories: categories ?? new GenericSet<string>(str_hash, str_equal),
            requirements: requirements, home_url: home_url);
    }

    /**
     * Load web app metadata from data directory
     *
     * @param dir   data directory of the web app to load
     **/
    public WebApp.from_dir(File dir) throws WebAppError {
        if (dir.query_file_type(0) != FileType.DIRECTORY) {
            throw new WebAppError.LOADING_FAILED(@"$(dir.get_path()) is not a directory");
        }

        File metadata_file = dir.get_child(METADATA_FILENAME);
        if (metadata_file.query_file_type(0) != FileType.REGULAR) {
            throw new WebAppError.LOADING_FAILED(@"$(metadata_file.get_path()) is not a file");
        }

        string metadata;
        try {
            metadata = Drt.System.read_file(metadata_file).strip();
        }
        catch (GLib.Error e) {
            throw new WebAppError.LOADING_FAILED("Cannot read '%s'. %s", metadata_file.get_path(), e.message);
        }
        this.from_metadata(metadata, dir);
    }

    /**
     * Load web app metadata from a data string
     *
     * @param metadata    metadata string in JSON format
     * @param data_dir    corresponding data directory of the web app to load
     **/
    public WebApp.from_metadata(string metadata, File? data_dir) throws WebAppError {
        Drt.JsonObject meta;
        try {
            meta = Drt.JsonParser.load_object(metadata);
        }
        catch (Drt.JsonError e) {
            throw new WebAppError.INVALID_METADATA("Invalid metadata file. %s", e.message);
        }

        string id;
        if (!meta.get_string("id", out id)) {
            throw new WebAppError.INVALID_METADATA("The id key is missing or is not a string.");
        }
        string name;
        if (!meta.get_string("name", out name)) {
            throw new WebAppError.INVALID_METADATA("The name key is missing or is not a string.");
        }
        string maintainer_name;
        if (!meta.get_string("maintainer_name", out maintainer_name)) {
            throw new WebAppError.INVALID_METADATA("The maintainer_name key is missing or is not a string.");
        }
        string maintainer_link;
        if (!meta.get_string("maintainer_link", out maintainer_link)) {
            throw new WebAppError.INVALID_METADATA("The maintainer_link key is missing or is not a string.");
        }
        int version_major;
        if (!meta.get_int("version_major", out version_major)) {
            throw new WebAppError.INVALID_METADATA("The version_major key is missing or is not an integer.");
        }
        int version_minor;
        if (!meta.get_int("version_minor", out version_minor)) {
            throw new WebAppError.INVALID_METADATA("The version_minor key is missing or is not an integer.");
        }
        int version_micro;
        if (!meta.get_int("version_micro", out version_micro)) {
            version_micro = 0;
        }
        string? version_revision = null;
        if (!meta.get_string("version_revision", out version_revision)) {
            version_revision = null;
        }
        int api_major;
        if (!meta.get_int("api_major", out api_major)) {
            throw new WebAppError.INVALID_METADATA("The api_major key is missing or is not an integer.");
        }
        int api_minor;
        if (!meta.get_int("api_minor", out api_minor)) {
            throw new WebAppError.INVALID_METADATA("The api_minor key is missing or is not an integer.");
        }
        if (!meta.get_bool_or("has_desktop_launcher", false)) {
            throw new WebAppError.INVALID_METADATA("Web apps without a desktop launcher are no longer supported. Upgrade Nuvola SDK.");
        }
        string? categories = meta.get_string_or("categories");
        if (Drt.String.is_empty(categories)) {
            warning("Empty 'categories' entry for web app '%s'. Using '%s' as a fallback.", id, DEFAULT_CATEGORY);
            categories = DEFAULT_CATEGORY;
        }
        string? requirements = meta.get_string_or("requirements");

        this(id, name, maintainer_name, maintainer_link,
            version_major, version_minor, version_micro, version_revision, api_major, api_minor, data_dir,
            requirements, Drt.String.semicolon_separated_set(categories, true),
            meta.get_int_or("window_width"), meta.get_int_or("window_height"),
            meta.get_string_or("home_url"));

        hidden = meta.get_bool_or("hidden", false);
        allow_insecure_content = meta.get_bool_or("allow_insecure_content", false);
        user_agent = meta.get_string_or("user_agent");
    }

    public string get_uid() {
        return build_uid_from_app_id(this.id, Nuvola.get_app_uid());
    }

    public string get_dbus_id() {
        return build_uid_from_app_id(this.id, Nuvola.get_dbus_id());
    }

    public string get_icon_name() {
        return get_uid();
    }

    /**
     * Returns true if web app belongs to given category
     *
     * @param category    category id
     * @return true if web app belongs to given category
     */
    public bool in_category(string category) {
        return categories.contains(category.down());
    }

    public List<unowned string> list_categories() {
        return categories.get_values();
    }



    /**
     * Returns icon pixbuf for the given size.
     *
     * @return        pixbuf with icon scaled to the given size
     */
    public Gdk.Pixbuf? get_icon_pixbuf(int size) requires (size > 0) {
        Gtk.IconInfo info = lookup_theme_icon(size, Gtk.IconLookupFlags.FORCE_SIZE);
        if (info != null) {
            try {
                return info.load_icon().copy();
            }
            catch (GLib.Error e) {
                warning("Icon pixbuf %d: %s", size, e.message);
            }
        }

        lookup_icons();
        /* Return the first icon >= size */
        foreach (IconInfo icon in icons) {
            if (icon.size <= 0 || icon.size >= size) {
                try {
                    var pixbuf =  new Gdk.Pixbuf.from_file_at_scale(icon.path, size, size, false);
                    if (pixbuf != null) {
                        return pixbuf;
                    }
                }
                catch (GLib.Error e) {
                    warning("Failed to load icon from file %s: %s", icon.path, e.message);
                }
            }
        }
        return Drtgtk.Icons.load_theme_icon( {Nuvola.get_app_icon()}, size);
    }

    private Gtk.IconInfo? lookup_theme_icon(int size, Gtk.IconLookupFlags flags=0) {
        if (size <= 0) {
            /* Any large icon requested */
            size = 1024;
        } else if (size <= 32) {
            /* Avoid use of SVG icon for small icon sizes because of a too large borders for this icon sizes */
            flags |= Gtk.IconLookupFlags.NO_SVG;
        }

        Gtk.IconInfo? icon = Gtk.IconTheme.get_default().lookup_icon(get_icon_name(), size, flags);
        if (icon == null) {
            debug("Theme icon %s %d not found.", get_icon_name(), size);
        }
        return icon;
    }

    private void lookup_icons(bool refresh=false) {
        if (data_dir == null || icons_set && !refresh) {
            return;
        }

        icons = null;
        File icons_dir = data_dir.get_child("icons");
        try {
            FileInfo file_info;
            FileEnumerator enumerator = icons_dir.enumerate_children(FileAttribute.STANDARD_NAME, 0);
            while ((file_info = enumerator.next_file()) != null) {
                int width = 0;
                int height = 0;
                string path = icons_dir.get_child(file_info.get_name()).get_path();
                unowned Gdk.PixbufFormat? format = Gdk.Pixbuf.get_file_info(path, out width, out height);
                if (format == null) {
                    continue;
                }

                int size = path.has_suffix(".svg") ? 0 : int.min(width, height);
                icons.prepend( {path, size});
            }
        }
        catch (GLib.Error e) {
            if (!(e is GLib.IOError.NOT_FOUND)) {
                warning("Enumeration of icons failed (%s): %s", icons_dir.get_path(), e.message);
            }
        }

        icons.sort(IconInfo.compare);
        icons_set = true;
    }

    public Variant to_variant() {
        var builder = new VariantBuilder(new VariantType("a{sv}"));
        builder.add("{sv}", "id", new Variant.string(id));
        builder.add("{sv}", "name", new Variant.string(name));
        builder.add("{sv}", "version", new Variant.string("%u.%u".printf(version_major, version_minor)));
        builder.add("{sv}", "maintainer", new Variant.string(maintainer_name));
        builder.add("{sv}", "categories", new Variant.strv(Drt.Utils.list_to_strv(list_categories())));
        return builder.end();
    }

    public static inline int cmp_by_name(WebApp a, WebApp b) {
        return strcmp(a.name, b.name);
    }

    private struct IconInfo {
        string path;
        int size;

        public static int compare(IconInfo? icon1, IconInfo? icon2) {
            return_val_if_fail(icon1 != null && icon2 != null, 0);

            if (icon1.size == icon2.size) {
                return 0;
            }
            if (icon1.size <= 0) {
                return 1;
            }
            if (icon2.size <= 0) {
                return -1;
            }

            return icon1.size - icon2.size;
        }
    }
}

} // namespace Nuvola
