/* 
 * Author: Jiří Janoušek <janousek.jiri@gmail.com>
 *
 * To the extent possible under law, author has waived all
 * copyright and related or neighboring rights to this file.
 * http://creativecommons.org/publicdomain/zero/1.0/
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHORS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */



public class MyApp : Diorite.Application
{
	private Gtk.ApplicationWindow? main_window = null;
	private Diorite.ActionsRegistry actions;
	
	public MyApp()
	{
		base("cz.fenryxo.MyApp", "My App", "myapp.desktop", "myapp");
		icon = "gedit";
		version = "0.1";
	}
	
	public override void activate()
	{
		if (main_window == null)
			start();
		main_window.present();
	}
	
	private void start()
	{
		main_window = new Gtk.ApplicationWindow(this);
		main_window.set_default_size(400, 400);
		append_actions();
		set_app_menu(actions.build_menu({"quit"}));
		var menu = new Menu();
		menu.append_submenu("_Go", actions.build_menu({"back", "forward"}));
		set_menubar(menu);
		var toolbar = actions.build_toolbar({"back", "forward", "|", "quit", " ", "menu"});
		toolbar.hexpand = false;
		toolbar.vexpand = true;
		main_window.add(toolbar);
		main_window.show_all();
	}
	
	private void append_actions()
	{
		this.actions = new Diorite.ActionsRegistry(this, main_window);
		Diorite.Action[] actions = {
		//          Action(group, scope, name, label?, mnemo_label?, icon?, keybinding?, callback?)
		new Diorite.Action("main", "app", "quit", "Quit", "_Quit", "application-exit", "<ctrl>Q", on_quit),
		new Diorite.Action("main", "win", "back", "Back", "_Back", "go-previous", "<alt>Left", null),
		new Diorite.Action("main", "win", "forward", "Forward", "_Forward", "go-next", "<alt>Right", null),
		new Diorite.Action("main", "win", "menu", "Menu", null, "emblem-system-symbolic", null, null)
		};
		this.actions.add_actions(actions);
		
	}
	
	private void on_quit()
	{
		quit();
	}
}

int main(string[] args)
{
	Diorite.Logger.init(stderr, GLib.LogLevelFlags.LEVEL_DEBUG);
	var me = args[0];
	debug("Debug: %s", me);
	var app = new MyApp();
	return app.run(args);
	
}
