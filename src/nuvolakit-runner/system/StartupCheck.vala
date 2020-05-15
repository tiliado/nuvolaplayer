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

private const string XDG_DESKTOP_PORTAL_SIGSEGV = "GDBus.Error:org.freedesktop.DBus.Error.Spawn.ChildSignaled: " +
"Process org.freedesktop.portal.Desktop received signal 11";

/**
 * Class performing a system check on start-up of Nuvola.
 * Public fields are filled as the check progresses.
 */
public class StartupCheck : GLib.Object {
    public WebOptions? web_options = null;
    public MasterService? master = null;
    public TiliadoPaywall? paywall = null;
    public string? machine_hash = null;
    private StartupResult model;
    private WebApp web_app;
    private unowned AppRunnerController app;
    private SourceFunc? resume = null;

    /**
     * Create new StartupCheck object.
     *
     * @param web_app           Web application to check its requirements.
     * @param format_support    Information about supported formats and technologies.
     */
    public StartupCheck(
        AppRunnerController app, StartupResult model, AboutDialog dialog, WebApp web_app
    ) {
        this.model = model;
        this.web_app = web_app;
        this.app = app;

        Gtk.Label status_label = Drtgtk.Labels.markup("%s web app script performs start-up checks...", app.app_name);
        status_label.hexpand = true;
        status_label.margin = 10;
        status_label.halign = Gtk.Align.CENTER;
        status_label.valign = Gtk.Align.CENTER;
        status_label.justify = Gtk.Justification.CENTER;
        dialog.show_progress(status_label);
    }

    /**
     * Start start-up check.
     *
     * @param available_web_options    WebOptions to try during requirements check.
     */
    public async StartupStatus run(WebOptions[] available_web_options) {
        machine_hash = yield Nuvola.get_machine_hash();
        model.task_finished.connect_after(on_phase_1_task_finished);
        check_desktop_portal_available.begin((o, res) => check_desktop_portal_available.end(res));
        check_app_requirements.begin(available_web_options, (o, res) => check_app_requirements.end(res));
        check_graphics_drivers.begin((o, res) => check_graphics_drivers.end(res));
        resume = run.callback;
        yield;
        if (model.get_overall_status() != StartupStatus.ERROR) {
            connect_master_service();
            TiliadoActivation? activation = TiliadoActivation.create_if_enabled(master.config ?? app.config);
            if (activation != null) {
                var gumroad = new TiliadoGumroad(
                    master.config ?? app.config, Drt.String.unmask(TILIADO_OAUTH2_CLIENT_SECRET.data),
                    activation.tiliado);
                paywall = new TiliadoPaywall(app, activation, gumroad);
            }
            yield check_tiliado_account(paywall);

        }
        model.mark_as_finished();
        return model.final_status;
    }

    private void on_phase_1_task_finished(StartupResult startup_check, StartupCheck.Task task) {
        if (startup_check.finished_tasks == 3 && startup_check.running_tasks == 0) {
            model.task_finished.disconnect(on_phase_1_task_finished);
            Idle.add((owned) resume);
        }
    }

    /**
     * Check whether XDG desktop portal is available.
     *
     * The {@link xdg_desktop_portal_status} property is populated with the result of this check.
     */
    public async void check_desktop_portal_available() {
        model.task_started(Task.DESKTOP_PORTAL);
        #if FLATPAK
        model.xdg_desktop_portal_status = StartupStatus.IN_PROGRESS;
        try {
            yield Drt.Flatpak.check_desktop_portal_available(null);
            model.xdg_desktop_portal_status = StartupStatus.OK;
        } catch (GLib.Error e) {
            if (XDG_DESKTOP_PORTAL_SIGSEGV in e.message) {
                model.xdg_desktop_portal_message = ("In case you have the 'xdg-desktop-portal-kde' package installed, "
                    + "uninstall it and install the 'xdg-desktop-portal-gtk' package instead. Error message: "
                    + e.message);
            } else {
                model.xdg_desktop_portal_message = e.message;
            }
            model.xdg_desktop_portal_status = StartupStatus.ERROR;
        }
        #else
        model.xdg_desktop_portal_status = StartupStatus.NOT_APPLICABLE;
        #endif
        yield Drt.EventLoop.resume_later();
        model.task_finished(Task.DESKTOP_PORTAL);
    }

    /**
     * Check requirements of the associated web app {@link web_app}.
     *
     * The {@link app_requirements_status} property is populated with the result of this check.
     */
    public async void check_app_requirements(WebOptions[] available_web_options) {
        model.task_started(Task.APP_REQUIREMENTS);

        model.app_requirements_status = StartupStatus.IN_PROGRESS;
        string? result_message = null;

        int n_options = available_web_options.length;
        assert(n_options > 0);
        var checks = new WebOptionsCheck[n_options];
        for (var i = 0; i < n_options; i++) {
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
                check_app_requirements_finished(StartupStatus.ERROR, (owned) result_message, available_web_options);
                return;
            }
        }

        /* If there is no engine without an unsupported requirement, abort early. */
        if (n_engines_without_unsupported == 0) {
            Drt.String.append(ref result_message, "\n",
                "This web app requires certain technologies to function properly but these requirements "
                + "have not been satisfied.");
            check_app_requirements_finished(StartupStatus.ERROR, (owned) result_message, available_web_options);
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
                        check_app_requirements_finished(StartupStatus.ERROR, (owned) result_message, available_web_options);
                        return;
                    }
                }
                if (check.parser.n_unsupported + check.parser.n_unknown == 0) {
                    this.web_options = check.web_options;
                    check_app_requirements_finished(StartupStatus.OK, (owned) result_message, available_web_options);
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
        check_app_requirements_finished(StartupStatus.ERROR, (owned) result_message, available_web_options);
    }

    private void check_app_requirements_finished(StartupStatus status, owned string? message, WebOptions[] web_options) {
        string msg = (owned) message;
        foreach (WebOptions web_opt in web_options) {
            string[] warnings = web_opt.get_format_support_warnings();
            if (warnings.length > 0) {
                foreach (unowned string entry in warnings) {
                    warning("%s: %s", web_opt.get_name(), entry);
                }
            }
        }
        model.app_requirements_message = (owned) msg;
        model.app_requirements_status = status;
        model.task_finished(Task.APP_REQUIREMENTS);
    }

    /**
     * Check the status of graphics drivers.
     *
     * The {@link opengl_driver_status}, {@link vaapi_driver_status} and {@link vdpau_driver_status}
     * properties are populated with the result of this check.
     */
    public async void check_graphics_drivers() {
        model.task_started(Task.GRAPHICS_DRIVERS);
        model.opengl_driver_status = StartupStatus.IN_PROGRESS;
        model.vaapi_driver_status = StartupStatus.IN_PROGRESS;
        model.vdpau_driver_status = StartupStatus.IN_PROGRESS;

        yield Drt.EventLoop.resume_later();

        #if FLATPAK
        string? gl_extension = null;
        if (!Graphics.is_required_gl_extension_mounted(out gl_extension)) {
            model.opengl_driver_message = Markup.printf_escaped(
                "Graphics driver '%s' for Flatpak has not been found on your system. Please consult "
                + "<a href=\"https://github.com/tiliado/nuvolaruntime/wiki/Graphics-Drivers\">documentation"
                + " on graphics drivers</a> to get help with installation.", gl_extension);
            model.opengl_driver_status = StartupStatus.ERROR;
        } else {
            model.opengl_driver_status = StartupStatus.OK;
        }
        #else
        model.opengl_driver_status = StartupStatus.NOT_APPLICABLE;
        #endif

        model.vdpau_driver_status = StartupStatus.NOT_APPLICABLE;
        model.vaapi_driver_status = StartupStatus.NOT_APPLICABLE;

        yield Drt.EventLoop.resume_later();
        model.task_finished(Task.GRAPHICS_DRIVERS);
    }

    /**
     * Check whether sufficient Tiliado account is available.
     *
     * The {@link tiliado_account_status} property is populated with the result of this check.
     */
    public async void check_tiliado_account(TiliadoPaywall? paywall) {
        model.task_started(Task.TILIADO_ACCOUNT);
        #if TILIADO_API
        model.tiliado_account_status = StartupStatus.IN_PROGRESS;
        yield Drt.EventLoop.resume_later();
        if (paywall != null) {
            yield paywall.refresh_data();
            if (paywall.unlocked) {
                model.tiliado_account_message = Markup.printf_escaped("Features Tier: %s", paywall.tier.get_label());
                model.tiliado_account_status = StartupStatus.OK;
            } else {
                model.tiliado_account_message = "Features Tier: Free";
                model.tiliado_account_status = StartupStatus.OK;
            }
        } else {
            model.tiliado_account_status = StartupStatus.NOT_APPLICABLE;
        }
        yield Drt.EventLoop.resume_later();
        #endif
        model.task_finished(Task.TILIADO_ACCOUNT);
    }

    private void connect_master_service() {
        var master = new MasterService();
        if (master.init(app.ipc_bus, this.web_app.id, app.dbus_id)) {
            model.nuvola_service_status = StartupStatus.OK;
        } else if (master.error is MasterServiceError.OTHER) {
            model.nuvola_service_status = StartupStatus.OK;
            model.nuvola_service_message = Markup.printf_escaped(
                "Failed to connect to Nuvola Apps Service, but it is optional.\n\n<i>Error message: %s</i>",
                master.error.message);
        } else {
            model.nuvola_service_message = Markup.printf_escaped(
                "<b>Failed to connect to Nuvola Apps Service.</b>\n\n"
                + "1. Make sure Nuvola Apps Service is installed.\n"
                + "2. Make sure Nuvola Apps Service and individual Nuvola Apps are up-to-date.\n"
                + "3. Close all Nuvola Apps and try launching it again.\n\n"
                + "<i>Error message: %s</i>", master.error.message);
            model.nuvola_service_status = StartupStatus.WARNING;
        }
        this.master = master;
    }

    public enum Task {
        DESKTOP_PORTAL,
        APP_REQUIREMENTS,
        GRAPHICS_DRIVERS,
        TILIADO_ACCOUNT,
        NUVOLA_SERVICE;
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
