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

namespace Nuvola.Startup
{

public int print_web_app_version(FileStream output, File web_app_dir)
{
	try
	{
		var web_app = new WebApp.from_dir(web_app_dir);
		Nuvola.print_version_info(output, web_app);
		return 0;
	}
	catch (WebAppError e)
	{
		output.puts("### Failed to load web app! ###\n");
		output.printf("### %s ###\n", e.message);
		Nuvola.print_version_info(output, null);
		return 1;
	}
}

public int run_web_app_with_dbus_handshake(File web_app_dir, string[] argv) throws WebAppError
{
	return launch_app_runner(web_app_dir, null, argv);
}

public int run_web_app_as_subprocess(File web_app_dir, string api_token, string[] argv) throws WebAppError
{
	return launch_app_runner(web_app_dir, api_token, argv);
}

private int launch_app_runner(File web_app_dir, string? api_token, string[] argv) throws WebAppError
{
	/* We are not ready for Wayland yet.
	 * https://github.com/tiliado/nuvolaplayer/issues/181
	 * https://github.com/tiliado/nuvolaplayer/issues/240
	 */
	Environment.set_variable("GDK_BACKEND", "x11", true);
	
	// Init GTK early to have be able to use Gtk.IconTheme stuff
	string[] empty_argv = {};
	unowned string[] unowned_empty_argv = empty_argv;
	Gtk.init(ref unowned_empty_argv);
	
	var storage = new Diorite.XdgStorage.for_project(Nuvola.get_app_id());
	move_old_xdg_dirs(new Diorite.XdgStorage.for_project(Nuvola.get_old_id()), storage);
	var web_app = new WebApp.from_dir(web_app_dir);
	var app_storage = new WebAppStorage(
		  storage.user_config_dir.get_child(WEB_APP_DATA_SUBDIR).get_child(web_app.id),
		  storage.user_data_dir.get_child(WEB_APP_DATA_SUBDIR).get_child(web_app.id),
		  storage.user_cache_dir.get_child(WEB_APP_DATA_SUBDIR).get_child(web_app.id));
	var controller = new Nuvola.AppRunnerController(storage, web_app, app_storage, api_token, api_token == null);
	return controller.run(argv);
}

} // namespace Nuvola.Startup
