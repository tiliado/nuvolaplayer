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

private const string XDG_DESKTOP_PORTAL_SIGSEGV = "GDBus.Error:org.freedesktop.DBus.Error.Spawn.ChildSignaled: " +
"Process org.freedesktop.portal.Desktop received signal 11";

/**
 * Class performing a system check on start-up of Nuvola
 */
public class StartupCheck : GLib.Object {
    [Description (nick="XDG Desktop Portal status", blurb="XDG Desktop Portal is required for proxy settings and opening URIs.")]
    public Status xdg_desktop_portal_status {get; set; default = Status.UNKNOWN;}
    [Description (nick="XDG Desktop Portal message", blurb="Null unless the check went wrong.")]
    public string? xdg_desktop_portal_message {get; set; default = null;}
    [Description (nick="Nuvola Service status", blurb="Status of the connection to Nuvola Service (master process).")]
    public Status nuvola_service_status {get; set; default = Status.UNKNOWN;}
    [Description (nick="Nuvola Service message", blurb="Null unless the check went wrong.")]
    public string? nuvola_service_message {get; set; default = null;}
    [Description (nick="OpenGL driver status", blurb="If OpenGL driver is misconfigured, WebKitGTK may crash.")]
    public Status opengl_driver_status {get; set; default = Status.UNKNOWN;}
    [Description (nick="OpenGL driver message", blurb="Null unless the check went wrong.")]
    public string? opengl_driver_message {get; set; default = null;}
    [Description (nick="VA-API driver status", blurb="One of the two APIs for video acceleration.")]
    public Status vaapi_driver_status {get; set; default = Status.UNKNOWN;}
    [Description (nick="VA-API driver message", blurb="Null unless the check went wrong.")]
    public string? vaapi_driver_message {get; set; default = null;}
    [Description (nick="VDPAU driver status", blurb="One of the two APIs for video acceleration.")]
    public Status vdpau_driver_status {get; set; default = Status.UNKNOWN;}
    [Description (nick="VDPAU driver message", blurb="Null unless the check went wrong.")]
    public string? vdpau_driver_message {get; set; default = null;}
    [Description (nick="Web App Requirements status", blurb="A web app may have certain requirements, e.g. Flash plugin, MP3 codec, etc.")]
    public Status app_requirements_status {get; set; default = Status.UNKNOWN;}
    [Description (nick="Web App Requirements message", blurb="Null unless the check went wrong.")]
    public string? app_requirements_message {get; set; default = null;}
    [Description (nick="Number of running tasks", blurb="The current number of running checks.")]
    public int running_tasks {get; private set; default = 0;}
    [Description (nick="Number of finished tasks", blurb="The current number of finished checks.")]
    public int finished_tasks {get; private set; default = 0;}
    [Description (nick="Final status of all checks.", blurb="Set after mark_finished is called.")]
    public StartupCheck.Status final_status {get; private set; default = StartupCheck.Status.UNKNOWN;}
    [Description (nick="Format support info", blurb="Associated format support information to check web app requirements.")]
    public FormatSupport format_support {get; construct;}
    #if TILIADO_API
    [Description (nick="Tiliado Account status", blurb="Tiliado account is required for premium features.")]
    public Status tiliado_account_status {get; set; default = Status.UNKNOWN;}
    [Description (nick="Tiliado Account message", blurb="Null unless the check went wrong.")]
    public string? tiliado_account_message {get; set; default = null;}
    [Description (nick="Tiliado activation", blurb="Tiliado account activation.")]
    public TiliadoActivation activation {get; private set;}
    #endif
    [Description (nick="Web App object", blurb="Currently loaded web application")]
    public WebApp web_app {get; construct;}
    public WebOptions? web_options {get; private set; default = null;}

    /**
     * Create new StartupCheck object.
     *
     * @param web_app           Web application to check its requirements.
     * @param format_support    Information about supported formats and technologies.
     */
    public StartupCheck(WebApp web_app, FormatSupport format_support) {
        GLib.Object(format_support: format_support, web_app: web_app);
    }

    ~StartupCheck() {
    }

    /**
     * Emitted when a check is started.
     *
     * @param name    The name of the check.
     */
    public virtual signal void task_started(string name) {
        running_tasks++;
    }

    /**
     * Emitted when a check is finished.
     *
     * @param name    The name of the check.
     */
    public virtual signal void task_finished(string name) {
        running_tasks--;
        finished_tasks++;
    }

    /**
     * Emitted when all checks are considered finished.
     */
    public signal void finished(Status final_status);

    /**
     * Mark all checks as finished.
     *
     * Emits {@link finished} signal.
     *
     * @return {@link Status.ERROR} if any of checks ended up with {@link Status.ERROR},
     * {@link Status.WARNING} if there was any warning, finally {@link Status.OK} otherwise.
     */
    public Status mark_as_finished() {
        Status status = get_overall_status();
        final_status = status;
        finished(status);
        return status;
    }

    /**
     * Get overall status based on statuses of all checks.
     *
     * @return {@link Status.ERROR} if any of checks ended up with {@link Status.ERROR},
     * {@link Status.WARNING} if there was any warning, finally {@link Status.OK} otherwise.
     */
    public Status get_overall_status() {
        Status result = Status.OK;
        (unowned ParamSpec)[] properties = get_class().list_properties();
        foreach (weak ParamSpec property in properties) {
            if (property.name != "final-status" && property.name.has_suffix("-status")) {
                Status status = Status.UNKNOWN;
                this.get(property.name, out status);
                if (status == Status.ERROR) {
                    return status;
                }
                if (status == Status.WARNING) {
                    result = status;
                }
            }
        }
        return result;
    }

    /**
     * Check whether XDG desktop portal is available.
     *
     * The {@link xdg_desktop_portal_status} property is populated with the result of this check.
     */
    public async void check_desktop_portal_available() {
        const string NAME = "XDG Desktop Portal";
        task_started(NAME);
        #if FLATPAK
        xdg_desktop_portal_status = Status.IN_PROGRESS;
        try {
            yield Drt.Flatpak.check_desktop_portal_available(null);
            xdg_desktop_portal_status = Status.OK;
        } catch (GLib.Error e) {
            if (XDG_DESKTOP_PORTAL_SIGSEGV in e.message) {
                xdg_desktop_portal_message = ("In case you have the 'xdg-desktop-portal-kde' package installed, "
                    + "uninstall it and install the 'xdg-desktop-portal-gtk' package instead. Error message: "
                    + e.message);
            } else {
                xdg_desktop_portal_message = e.message;
            }
            xdg_desktop_portal_status = Status.ERROR;
        }
        #else
        xdg_desktop_portal_status = Status.NOT_APPLICABLE;
        #endif
        yield Drt.EventLoop.resume_later();
        task_finished(NAME);
    }

    /**
     * Check requirements of the associated web app {@link web_app}.
     *
     * The {@link app_requirements_status} property is populated with the result of this check.
     */
    public async void check_app_requirements(WebOptions[] available_web_options) {
        const string NAME = "Web App Requirements";
        task_started(NAME);

        app_requirements_status = Status.IN_PROGRESS;
        string? result_message = null;
        try {
            yield format_support.check();
        } catch (GLib.Error e) {
            result_message = e.message;
        }

        int n_options = available_web_options.length;
        assert(n_options > 0);
        var checks = new WebOptionsCheck[n_options];
        for (var i = 0; i < n_options; i++) {
            var webkit_options = available_web_options[i] as WebkitOptions;
            if (webkit_options != null) {
                webkit_options.format_support = format_support;
            }
            checks[i] = new WebOptionsCheck(available_web_options[i], web_app);
        }

        /* The first pass: Perform requirements check for all web engines and asses the results. */
        var n_engines_without_unsupported = 0;
        foreach (WebOptionsCheck check in checks) {
            try {
                debug("Checking requirements with %s", check.web_options.get_name_version());
                check.check_requirements();
                if (check.parser.n_unsupported == 0) {
                    n_engines_without_unsupported++;
                }
            } catch (Drt.RequirementError e) {
                Drt.String.append(ref result_message, "\n", Markup.printf_escaped(
                    "This web app provides invalid metadata about its requirements."
                    + " Please create a bug report. The error message is: %s\n\n%s",
                    e.message, check.web_app.requirements));
                check_app_requirements_finished(Status.ERROR, (owned) result_message, available_web_options);
                return;
            }
        }

        /* If there is no engine without an unsupported requirement, abort early. */
        if (n_engines_without_unsupported == 0) {
            Drt.String.append(ref result_message, "\n",
                "This web app requires certain technologies to function properly but these requirements "
                + "have not been satisfied.");
            check_app_requirements_finished(Status.ERROR, (owned) result_message, available_web_options);
            warning("Failed requirements: %s", checks[0].parser.failed_requirements ?? "");
            return;
        }

        /* Select the first engine which satisfies requirements. */
        foreach (WebOptionsCheck check in checks) {
            if (check.parser.n_unsupported == 0) {
                if (check.parser.n_unknown > 0) {
                    yield check.web_options.gather_format_support_info(check.web_app);
                    try {
                        debug("Checking requirements with %s", check.web_options.get_name_version());
                        check.check_requirements();
                    } catch (Drt.RequirementError e) {
                        Drt.String.append(ref result_message, "\n", Markup.printf_escaped(
                            "This web app provides invalid metadata about its requirements."
                            + " Please create a bug report. The error message is: %s\n\n%s",
                            e.message, check.web_app.requirements));
                        check_app_requirements_finished(Status.ERROR, (owned) result_message, available_web_options);
                        return;
                    }
                }
                if (check.parser.n_unsupported + check.parser.n_unknown == 0) {
                    this.web_options = check.web_options;
                    check_app_requirements_finished(Status.OK, (owned) result_message, available_web_options);
                    return;
                }
            }
        }

        /* No engine satisfies requirements */
        Drt.String.append(ref result_message, "\n",
            "This web app requires certain technologies to function properly but these requirements "
            + "have not been satisfied.\n\nContact your distributor to get assistance.");
        warning("Failed requirements: %s", checks[0].parser.failed_requirements ?? "");
        warning("Unknown requirements: %s", checks[0].parser.unknown_requirements ?? "");
        check_app_requirements_finished(Status.ERROR, (owned) result_message, available_web_options);
    }

    private void check_app_requirements_finished(Status status, owned string? message, WebOptions[] web_options) {
        string msg = (owned) message;
        foreach (WebOptions web_opt in web_options) {
            string[] warnings = web_opt.get_format_support_warnings();
            if (warnings.length > 0) {
                foreach (unowned string entry in warnings) {
                    warning("%s: %s", web_opt.get_name(), entry);
                }
            }
        }
        app_requirements_message = (owned) msg;
        app_requirements_status = status;
        task_finished("Web App Requirements");
    }

    /**
     * Check the status of graphics drivers.
     *
     * The {@link opengl_driver_status}, {@link vaapi_driver_status} and {@link vdpau_driver_status}
     * properties are populated with the result of this check.
     */
    public async void check_graphics_drivers() {
        const string NAME = "Graphics drivers";
        task_started(NAME);
        opengl_driver_status = Status.IN_PROGRESS;
        vaapi_driver_status = Status.IN_PROGRESS;
        vdpau_driver_status = Status.IN_PROGRESS;

        yield Drt.EventLoop.resume_later();

        #if FLATPAK
        string? gl_extension = null;
        if (!Graphics.is_required_gl_extension_mounted(out gl_extension)) {
            opengl_driver_message = Markup.printf_escaped(
                "Graphics driver '%s' for Flatpak has not been found on your system. Please consult "
                + "<a href=\"https://github.com/tiliado/nuvolaruntime/wiki/Graphics-Drivers\">documentation"
                + " on graphics drivers</a> to get help with installation.", gl_extension);
            opengl_driver_status = Status.ERROR;
        } else {
            opengl_driver_status = Status.OK;
        }
        #else
        opengl_driver_status = Status.NOT_APPLICABLE;
        #endif

        vdpau_driver_status = Status.NOT_APPLICABLE;
        vaapi_driver_status = Status.NOT_APPLICABLE;

        yield Drt.EventLoop.resume_later();
        task_finished(NAME);
    }

    #if TILIADO_API
    /**
     * Check whether sufficient Tiliado account is available.
     *
     * The {@link tiliado_account_status} property is populated with the result of this check.
     */
    public async void check_tiliado_account(TiliadoActivation activation) {
        const string NAME = "Tiliado account";
        task_started(NAME);
        tiliado_account_status = Status.IN_PROGRESS;
        yield Drt.EventLoop.resume_later();
        this.activation = activation;
        TiliadoApi2.User? user = activation.get_user_info();
        if (user != null) {
            tiliado_account_message = Markup.printf_escaped("Tiliado account: %s", user.name);
            tiliado_account_status = Status.OK;
        } else {
            tiliado_account_message ="No Tiliado account.";
            tiliado_account_status = Status.OK;
        }
        yield Drt.EventLoop.resume_later();
        task_finished(NAME);
    }

    #endif

    /**
     * Statuses of {@link StartupCheck}s.
     */
    public enum Status {
        /**
         * The corresponding check hasn't run yet.
         */
        UNKNOWN,
        /**
         * The check is irrelevant in current environment.
         */
        NOT_APPLICABLE,
        /**
         * The corresponding check has stared but not finished yet.
         */
        IN_PROGRESS,
        /**
         * Everything is OK.
         */
        OK,
        /**
         * There is an issue but it is not so severe. See the corresponding message property for more info.
         */
        WARNING,
        /**
         * The corresponding check failed. See the corresponding message property for more info.
         */
        ERROR;

        /**
         * Get short string representing the status.
         *
         * @return A short status string.
         */
        public string get_blurb() {
            switch (this) {
            case UNKNOWN:
                return "Unknown";
            case IN_PROGRESS:
                return "In Progress";
            case OK:
                return "OK";
            case WARNING:
                return "Warning";
            case ERROR:
                return "Error";
            case NOT_APPLICABLE:
                return "Not Applicable";
            default:
                return "";
            }
        }

        /**
         * Return suitable CSS class for a badge.
         *
         * @return A suitable CSS class.
         */
        public string get_badge_class() {
            switch (this) {
            case IN_PROGRESS:
                return Drtgtk.Css.BADGE_INFO;
            case OK:
                return Drtgtk.Css.BADGE_OK;
            case WARNING:
                return Drtgtk.Css.BADGE_WARNING;
            case ERROR:
                return Drtgtk.Css.BADGE_ERROR;
            case NOT_APPLICABLE:
            case UNKNOWN:
                return Drtgtk.Css.BADGE_DEFAULT;
            default:
                return Drtgtk.Css.BADGE_DEFAULT;
            }
        }

        public static Status[] all() {
            return {UNKNOWN, NOT_APPLICABLE, IN_PROGRESS, OK, WARNING, ERROR};
        }
    }

    private class WebOptionsCheck {
        public WebOptions web_options;
        public RequirementParser parser;
        public WebApp web_app;

        public WebOptionsCheck(WebOptions web_options, WebApp web_app) {
            this.web_options = web_options;
            this.parser = new RequirementParser(web_options);
            this.web_app = web_app;
        }

        public void check_requirements() throws Drt.RequirementError {
            if (web_app.requirements != null) {
                parser.eval(web_app.requirements);
            }
        }
    }
}

} // namespace Nuvola
