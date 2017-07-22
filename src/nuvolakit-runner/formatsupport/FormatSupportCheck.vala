/*
 * Copyright 2014-2015 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class FormatSupportCheck : GLib.Object
{
	private FormatSupport format_support;
	private Diorite.Storage storage;
	private Diorite.Application app;
	private Config config;
	private WebEngine web_engine;
	private WebApp web_app;
	private FormatSupportDialog format_support_dialog = null;
	
	public FormatSupportCheck(FormatSupport format_support, Diorite.Application app, Diorite.Storage storage,
	Config config, WebEngine web_engine, WebApp web_app)
	{
		this.format_support = format_support;
		this.app = app;
		this.storage = storage;
		this.config = config;
		this.web_engine = web_engine;
		this.web_app = web_app;
	}
	
	public async void check()
	{
		try
		{
			yield format_support.check();
			unowned List<WebPlugin?> plugins = format_support.list_web_plugins();
			foreach (unowned WebPlugin plugin in plugins)
				debug("Nuvola.WebPlugin: %s (%s, %s) at %s: %s", plugin.name, plugin.enabled ? "enabled" : "disabled",
					plugin.is_flash ? "flash" : "not flash", plugin.path, plugin.description);
			var flash_plugins = format_support.n_flash_plugins;
			if (flash_plugins == 0)
			{
				warning("No Flash plugin has been found.");
			}
			else if (flash_plugins > 1)
			{
				warning("Too many Flash plugins have been found: %u", flash_plugins);
			}
			if (!format_support.mp3_supported)
			{
				warning("MP3 Audio not supported.");
			}
			if (!web_engine.media_source_extension)
				debug("MSE is disabled");
			else
				#if !WEBKIT_SUPPORTS_MSE
				warning("MSE enabled but this particular build of WebKitGTK might not support it.");
				#else
				debug("MSE enabled and this particular build of WebKitGTK should support it.");
				#endif
		}
		catch (GLib.Error e)
		{
			warning("Plugin listing error: %s", e.message);
		}
		
		try
		{
			var dri2_driver = Graphics.dri2_get_driver_name();
			if (!Graphics.have_vdpau_driver(dri2_driver))
				warning("VDPAU Driver for %s not found. Flash plugin may suffer.", dri2_driver);
			if (!Graphics.have_vaapi_driver(dri2_driver))
				warning("VA-API Driver for %s not found. Flash plugin may suffer.", dri2_driver);
		}
		catch (Graphics.DriError e)
		{
			warning("Failed to get DRI2 driver name. %s", e.message);
		}
		try
		{
			string? failed_requirements = null;
			if (!web_app.check_requirements(format_support, out failed_requirements))
				app.fatal_error(
					"Requirements Not Satisfied",
					Markup.printf_escaped(
						"This web app requires certain technologies to function properly but these requirements "
						+ "have not been satisfied.\n\nFailed requirements: <i>%s</i>\n\n"
						+ "<a href=\"%s\">Get help with installation</a>",
						failed_requirements ?? "", WEB_APP_REQUIREMENTS_HELP_URL),
					true);
		}
		catch (Drt.RequirementError e)
		{
			app.show_error(
				"Invalid Metadata",
				("This web app provides invalid metadata about its requirements."
				+ " Please create a bug report. The error message is: %s\n\n%s"
				).printf(e.message, web_app.requirements));
		}
		
	}
	
	public void show_dialog(FormatSupportDialog.Tab tab=FormatSupportDialog.Tab.DEFAULT)
	{
		if (format_support_dialog == null)
		{
			format_support_dialog = new FormatSupportDialog(app, format_support, storage, app.active_window);
			Idle.add(() => {
				format_support_dialog.run();
				format_support_dialog.destroy();
				format_support_dialog = null;
				return false;
			});
		}
		format_support_dialog.show_tab(tab);
	}
}

} // namespace Nuvola
