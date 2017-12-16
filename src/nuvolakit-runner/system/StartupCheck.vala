/*
 * Copyright 2014-2017 Jiří Janoušek <janousek.jiri@gmail.com>
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
 
namespace Nuvola
{

private const string XDG_DESKTOP_PORTAL_SIGSEGV = "GDBus.Error:org.freedesktop.DBus.Error.Spawn.ChildSignaled: " +
	"Process org.freedesktop.portal.Desktop received signal 11";

/**
 * Class performing a system check on start-up of Nuvola
 */
public class StartupCheck : GLib.Object
{
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
	public WebkitOptions webkit_options {get; construct;}
	
	/**
	 * Create new StartupCheck object.
	 * 
	 * @param web_app           Web application to check its requirements.
	 * @param format_support    Information about supported formats and technologies.
	 */
	public StartupCheck(WebApp web_app, FormatSupport format_support, WebkitOptions webkit_options)
	{
		GLib.Object(format_support: format_support, web_app: web_app, webkit_options: webkit_options);
	}
	
	~StartupCheck()
	{
	}
	
	/**
	 * Emitted when a check is started.
	 * 
	 * @param name    The name of the check.
	 */
	public virtual signal void task_started(string name)
	{
		running_tasks++;
	}
	
	/**
	 * Emitted when a check is finished.
	 * 
	 * @param name    The name of the check.
	 */
	public virtual signal void task_finished(string name)
	{
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
	public Status mark_as_finished()
	{
		var status = get_overall_status();
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
	public Status get_overall_status()
	{
		Status result = Status.OK;
		(unowned ParamSpec)[] properties = get_class().list_properties();
		foreach (weak ParamSpec property in properties)
		{
			if (property.name != "final-status" && property.name.has_suffix("-status"))
			{
				Status status = Status.UNKNOWN;
				this.get(property.name, out status);
				if (status == Status.ERROR)
					return status;
				if (status == Status.WARNING)
					result = status;
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
	public async void check_app_requirements()
	{
		const string NAME = "Web App Requirements";
		task_started(NAME);
		
		app_requirements_status = Status.IN_PROGRESS;
		var result_status = Status.OK;
		string? result_message = null;
		try
		{
			yield format_support.check();
		}
		catch (GLib.Error e)
		{
			result_message = e.message;
		}
		
		if (web_app.traits(webkit_options).flash_required)
		{
			unowned List<WebPlugin?> plugins = format_support.list_web_plugins();
			foreach (unowned WebPlugin plugin in plugins)
				debug("Nuvola.WebPlugin: %s (%s, %s) at %s: %s", plugin.name, plugin.enabled ? "enabled" : "disabled",
					plugin.is_flash ? "flash" : "not flash", plugin.path, plugin.description);
			var flash_plugins = format_support.n_flash_plugins;
			if (flash_plugins == 0)
			{
				Drt.String.append(ref result_message, "\n",
					"<b>Flash plugin issue:</b> No Flash Player plugin has been found. Music playback may fail.");
				result_status = Status.ERROR;
			}
			else if (flash_plugins > 1)
			{
				Drt.String.append(ref result_message, "\n",
					"<b>Flash plugin issue:</b> More Flash Player plugins have been found. Wrong version may be in use.");
				if (result_status < Status.WARNING)
					result_status = Status.WARNING;
			}
		}
		if (!format_support.mp3_supported)
			warning("MP3 Audio not supported.");
		
		#if WEBKIT_SUPPORTS_MSE
		debug("MSE supported: yes");
		#else
		debug("MSE supported: no");
		#endif
		
		yield Drt.EventLoop.resume_later();
		
		try
		{
			string? failed_requirements = null;
			if (!web_app.check_requirements(format_support, webkit_options, out failed_requirements))
			{
				Drt.String.append(ref result_message, "\n", Markup.printf_escaped(
						"This web app requires certain technologies to function properly but these requirements "
						+ "have not been satisfied.\n\nFailed requirements: <i>%s</i>\n\n"
						+ "<a href=\"%s\">Get help with installation</a>",
						failed_requirements ?? "", WEB_APP_REQUIREMENTS_HELP_URL));
				result_status = Status.ERROR;
			}
		}
		catch (Drt.RequirementError e)
		{
			Drt.String.append(ref result_message, "\n", Markup.printf_escaped(
				"This web app provides invalid metadata about its requirements."
				+ " Please create a bug report. The error message is: %s\n\n%s",
				e.message, web_app.requirements));
			result_status = Status.ERROR;
		}
		
		yield Drt.EventLoop.resume_later();
		app_requirements_message = (owned) result_message;
		app_requirements_status = result_status;
		task_finished(NAME);
	}
	
	/**
	 * Check the status of graphics drivers.
	 * 
	 * The {@link opengl_driver_status}, {@link vaapi_driver_status} and {@link vdpau_driver_status}
	 * properties are populated with the result of this check.
	 */
	public async void check_graphics_drivers()
	{
		const string NAME = "Graphics drivers";
		task_started(NAME);
		opengl_driver_status = Status.IN_PROGRESS;
		vaapi_driver_status = Status.IN_PROGRESS;
		vdpau_driver_status = Status.IN_PROGRESS;
		
		yield Drt.EventLoop.resume_later();
		
		#if FLATPAK
		string? gl_extension = null;
		if (!Graphics.is_required_gl_extension_mounted(out gl_extension))
		{
			opengl_driver_message = Markup.printf_escaped(
				"Graphics driver '%s' for Flatpak has not been found on your system. Please consult "
				+ "<a href=\"https://github.com/tiliado/nuvolaruntime/wiki/Graphics-Drivers\">documentation"
				+ " on graphics drivers</a> to get help with installation.", gl_extension);
			opengl_driver_status = Status.ERROR;
		}
		else
		{
			opengl_driver_status = Status.OK;
		}
		#else
			opengl_driver_status = Status.NOT_APPLICABLE;
		#endif
		try
		{
			const string DRIVER_NOT_FOUND_TEMPLATE = (
				"%s Driver for '%s' not found. Rendering performance of some web apps may suffer. "
				#if !FLATPAK
				+ "Contact your distributor to get help with installation."
				#else
				+ "Please <a href=\"https://github.com/tiliado/nuvolaruntime/issues/280\">report your issue</a>"
				+" so that the driver can be added to Nuvola Runtime flatpak."
				#endif
				);
			
			var dri2_driver = Graphics.dri2_get_driver_name();
			if (!Graphics.have_vdpau_driver(dri2_driver))
			{
				vdpau_driver_message = Markup.printf_escaped(DRIVER_NOT_FOUND_TEMPLATE, "VDPAU", dri2_driver);
				vdpau_driver_status = Status.WARNING;
			}
			else
			{
				vdpau_driver_status = Status.OK;
			}
			if (!Graphics.have_vaapi_driver(dri2_driver))
			{
				vaapi_driver_message = Markup.printf_escaped(DRIVER_NOT_FOUND_TEMPLATE, "VA-API", dri2_driver);
				vaapi_driver_status = Status.WARNING;
			}
			else
			{
				vaapi_driver_status = Status.OK;
			}
		}
		catch (Graphics.DriError e)
		{
			if (e is Graphics.DriError.NO_X_DISPLAY || e is Graphics.DriError.EXTENSION_QUERY
			|| e is Graphics.DriError.CONNECT)
			{
				vdpau_driver_status = Status.NOT_APPLICABLE;
				vaapi_driver_status = Status.NOT_APPLICABLE;
			}
			else
			{
				var msg = Markup.printf_escaped("Failed to get DRI2 driver name. %s", e.message);
				vdpau_driver_message = msg;
				vdpau_driver_status = Status.WARNING;
				vaapi_driver_message = (owned) msg;
				vaapi_driver_status = Status.WARNING;
			}
		}
		yield Drt.EventLoop.resume_later();
		task_finished(NAME);
	}
	
	#if TILIADO_API
	/**
	 * Check whether sufficient Tiliado account is available.
	 * 
	 * The {@link tiliado_account_status} property is populated with the result of this check.
	 */
	public async void check_tiliado_account(TiliadoActivation activation)
	{
		const string NAME = "Tiliado account";
		task_started(NAME);
		tiliado_account_status = Status.IN_PROGRESS;
		yield Drt.EventLoop.resume_later();
		this.activation = activation;
		var user = activation.get_user_info();
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
	public enum Status
	{
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
		public string get_blurb()
		{
			switch (this)
			{
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
		public string get_badge_class()
		{
			switch (this)
			{
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
		
		public static Status[] all()
		{
			return {UNKNOWN, NOT_APPLICABLE, IN_PROGRESS, OK, WARNING, ERROR};
		}
	}
}

} // namespace Nuvola
