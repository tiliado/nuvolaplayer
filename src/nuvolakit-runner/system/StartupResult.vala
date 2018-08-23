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

/**
 * Class performing a system check on start-up of Nuvola
 */
public class StartupResult : GLib.Object {
    [Description (nick="XDG Desktop Portal status", blurb="XDG Desktop Portal is required for proxy settings and opening URIs.")]
    public StartupStatus xdg_desktop_portal_status {get; set; default = StartupStatus.UNKNOWN;}
    [Description (nick="XDG Desktop Portal message", blurb="Null unless the check went wrong.")]
    public string? xdg_desktop_portal_message {get; set; default = null;}
    [Description (nick="Nuvola Service status", blurb="Status of the connection to Nuvola Service (master process).")]
    public StartupStatus nuvola_service_status {get; set; default = StartupStatus.UNKNOWN;}
    [Description (nick="Nuvola Service message", blurb="Null unless the check went wrong.")]
    public string? nuvola_service_message {get; set; default = null;}
    [Description (nick="OpenGL driver status", blurb="If OpenGL driver is misconfigured, WebKitGTK may crash.")]
    public StartupStatus opengl_driver_status {get; set; default = StartupStatus.UNKNOWN;}
    [Description (nick="OpenGL driver message", blurb="Null unless the check went wrong.")]
    public string? opengl_driver_message {get; set; default = null;}
    [Description (nick="VA-API driver status", blurb="One of the two APIs for video acceleration.")]
    public StartupStatus vaapi_driver_status {get; set; default = StartupStatus.UNKNOWN;}
    [Description (nick="VA-API driver message", blurb="Null unless the check went wrong.")]
    public string? vaapi_driver_message {get; set; default = null;}
    [Description (nick="VDPAU driver status", blurb="One of the two APIs for video acceleration.")]
    public StartupStatus vdpau_driver_status {get; set; default = StartupStatus.UNKNOWN;}
    [Description (nick="VDPAU driver message", blurb="Null unless the check went wrong.")]
    public string? vdpau_driver_message {get; set; default = null;}
    [Description (nick="Web App Requirements status", blurb="A web app may have certain requirements, e.g. Flash plugin, MP3 codec, etc.")]
    public StartupStatus app_requirements_status {get; set; default = StartupStatus.UNKNOWN;}
    [Description (nick="Web App Requirements message", blurb="Null unless the check went wrong.")]
    public string? app_requirements_message {get; set; default = null;}
    [Description (nick="Number of running tasks", blurb="The current number of running checks.")]
    public int running_tasks {get; private set; default = 0;}
    [Description (nick="Number of finished tasks", blurb="The current number of finished checks.")]
    public int finished_tasks {get; private set; default = 0;}
    [Description (nick="Final status of all checks.", blurb="Set after mark_finished is called.")]
    public StartupStatus final_status {get; private set; default = StartupStatus.UNKNOWN;}
    #if TILIADO_API
    [Description (nick="Tiliado Account status", blurb="Tiliado account is required for premium features.")]
    public StartupStatus tiliado_account_status {get; set; default = StartupStatus.UNKNOWN;}
    [Description (nick="Tiliado Account message", blurb="Null unless the check went wrong.")]
    public string? tiliado_account_message {get; set; default = null;}
    #endif

    /**
     * Create new StartupCheck model.
     */
    public StartupResult() {
    }

    /**
     * Emitted when a check is started.
     *
     * @param name    The name of the check.
     */
    public virtual signal void task_started(StartupCheck.Task task) {
        running_tasks++;
    }

    /**
     * Emitted when a check is finished.
     *
     * @param name    The name of the check.
     */
    public virtual signal void task_finished(StartupCheck.Task task) {
        running_tasks--;
        finished_tasks++;
    }

    /**
     * Emitted when all checks are considered finished.
     */
    public signal void finished(StartupStatus final_status);

    /**
     * Mark all checks as finished.
     *
     * Emits {@link finished} signal.
     *
     * @return {@link StartupStatus.ERROR} if any of checks ended up with {@link Status.ERROR},
     * {@link StartupStatus.WARNING} if there was any warning, finally {@link Status.OK} otherwise.
     */
    public StartupStatus mark_as_finished() {
        StartupStatus status = get_overall_status();
        final_status = status;
        finished(status);
        return status;
    }

    /**
     * Get overall status based on statuses of all checks.
     *
     * @return {@link StartupStatus.ERROR} if any of checks ended up with {@link Status.ERROR},
     * {@link StartupStatus.WARNING} if there was any warning, finally {@link Status.OK} otherwise.
     */
    public StartupStatus get_overall_status() {
        StartupStatus result = StartupStatus.OK;
        (unowned ParamSpec)[] properties = get_class().list_properties();
        foreach (weak ParamSpec property in properties) {
            if (property.name != "final-status" && property.name.has_suffix("-status")) {
                StartupStatus status = StartupStatus.UNKNOWN;
                this.get(property.name, out status);
                if (status == StartupStatus.ERROR) {
                    return status;
                }
                if (status == StartupStatus.WARNING) {
                    result = status;
                }
            }
        }
        return result;
    }
}

/**
 * Statuses of {@link StartupCheck}.
 */
public enum StartupStatus {
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

    public static StartupStatus[] all() {
        return {UNKNOWN, NOT_APPLICABLE, IN_PROGRESS, OK, WARNING, ERROR};
    }
}

} // namespace Nuvola
