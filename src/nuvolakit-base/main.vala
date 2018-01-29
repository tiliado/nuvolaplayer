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
private extern const string APPNAME;
private extern const string OLDNAME;
private extern const string NAME;
private extern const string WELCOME_SCREEN_NAME;
private extern const string UNIQUE_NAME;
private extern const string APP_ICON;
private extern const string VERSION;
private extern const string REVISION;
private extern const int VERSION_MAJOR;
private extern const int VERSION_MINOR;
private extern const int VERSION_BUGFIX;
private extern const string VERSION_SUFFIX;
private extern const string LIBDIR;

public extern const string HELP_URL;
public extern const string WEB_APP_REQUIREMENTS_HELP_URL;
public extern const string REPOSITORY_INDEX;
public extern const string REPOSITORY_ROOT;
public extern const string TILIADO_OAUTH2_SERVER;
public extern const string TILIADO_OAUTH2_CLIENT_ID;
public const string TILIADO_OAUTH2_TOKEN_ENDPOINT = TILIADO_OAUTH2_SERVER + "/o/token/";
public const string TILIADO_OAUTH2_DEVICE_CODE_ENDPOINT = TILIADO_OAUTH2_SERVER + "/o/device-token/";
public const string TILIADO_OAUTH2_API_ENDPOINT = TILIADO_OAUTH2_SERVER + "/api/";

public const string WEB_APP_DATA_SUBDIR = "apps_data";

public string get_app_uid() {
    return UNIQUE_NAME;
}

public string get_dbus_id() {
    #if GENUINE
    return get_app_uid();
    #else
    return "eu.tiliado.NuvolaOse";
    #endif
}

public string get_dbus_path() {
    return "/" + get_dbus_id().replace(".", "/");
}

public string get_app_icon() {
    return APP_ICON;
}

public string get_app_id() {
    return APPNAME;
}

public string get_old_id() {
    return OLDNAME;
}

public string get_app_name() {
    return NAME;
}

public string get_revision() {
    return REVISION;
}

public string get_version() {
    return VERSION;
}

public string get_short_version() {
    return "%d.%d.%d".printf(VERSION_MAJOR, VERSION_MINOR, VERSION_BUGFIX);
}

public string get_version_suffix() {
    return VERSION_SUFFIX;
}

public int[] get_versions() {
    return {VERSION_MAJOR, VERSION_MINOR, VERSION_BUGFIX};
}

/**
 * Returns versions encoded as integer, e.g. 30105 for 3.1.5.
 */
public int get_encoded_version() {
    return VERSION_MAJOR * 10000 + VERSION_MINOR * 100 + VERSION_BUGFIX;
}

public string get_libdir() {
    return Environment.get_variable("NUVOLA_LIBDIR") ?? LIBDIR;
}

private string? app_runner_path;

public string get_app_runner_path() {
    if (app_runner_path == null) {
        app_runner_path = Environment.get_variable("NUVOLA_APPRUNNER") ?? (get_libdir() + "/apprunner");
    }
    return app_runner_path;
}

public string get_welcome_screen_name() {
    return WELCOME_SCREEN_NAME;
}

} // namespace Nuvola
