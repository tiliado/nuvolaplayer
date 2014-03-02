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
 * 
 * Tests are under public domain because they might contain useful sample code.
 */

using Diorite.Test;

namespace Nuvola
{

class WebAppRegistryTest: Diorite.TestCase
{
	public void test_load_web_apps()
	{
		const string PATH = "../data/nuvolaplayer3/web_apps";
		var web_apps_reg = create_registry(PATH);
		var known_apps = list_web_apps(PATH);
		var web_apps = web_apps_reg.list_web_apps();
		string[] found = {};
		foreach (var web_app in web_apps.get_values())
		{
			expect(web_app.meta.id in known_apps);
			found += web_app.meta.id;
		}
		
		expect(known_apps.length == found.length);
		foreach (var id in known_apps)
		{
			expect(id in found);
		}
	}
	
	public void test_invalid_metadata()
	{
		// TODO
	}
	
	private WebAppRegistry create_registry(string? path)
	{
		var storage = new Diorite.XdgStorage.for_project(Nuvola.get_appname()).get_child("web_apps");
		return new WebAppRegistry.with_data_path(storage, path);
	}
	
	private string[] list_web_apps(string path)
	{
		string[] apps = {};
		var parent = File.new_for_path(path);
		expect(parent.query_exists());
		if (!parent.query_exists())
			return apps;
		
		try
		{
			FileInfo file_info;
			var enumerator = parent.enumerate_children(FileAttribute.STANDARD_NAME, 0);
			while ((file_info = enumerator.next_file()) != null)
			{
				string name = file_info.get_name();
				if (!WebAppRegistry.check_id(name))
					continue;
				
				var app_dir = parent.get_child(name);
				if (app_dir.query_file_type(0) != FileType.DIRECTORY)
					continue;
				
				apps += name;
			}
		}
		catch (GLib.Error e)
		{
			warning("Filesystem error: %s", e.message);
			expect(false);
		}
		return apps;
	}

}

} // namespace Nuvola
