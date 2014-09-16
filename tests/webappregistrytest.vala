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

namespace Nuvola
{

public class WebAppRegistryTest: Diorite.TestCase
{
	public void test_load_web_apps()
	{
		const string PATH = "../web_apps";
		var web_apps_reg = create_registry(PATH);
		var known_apps = list_web_apps(PATH);
		var web_apps = web_apps_reg.list_web_apps();
		string[] found = {};
		foreach (var web_app in web_apps.get_values())
		{
			expect(web_app.id in known_apps, "");
			found += web_app.id;
		}
		
		expect(known_apps.length == found.length, "");
		foreach (var id in known_apps)
		{
			expect(id in found, "");
		}
	}
	
	public void test_invalid_metadata()
	{
		// TODO
	}
	
	public void test_install_packages()
	{
		File tmp_dir = null;
		try
		{
			tmp_dir = File.new_for_path(DirUtils.make_tmp("nuvolaplayerXXXXXX"));
		}
		catch (FileError e)
		{
			fail("");
		}
		
		try
		{
			var parent = File.new_for_path("../packages");
			var packages = list_files(parent.get_path());
			var web_app_reg = create_registry(tmp_dir.get_path(), true);
			foreach(var package_name in packages)
			{
				WebAppMeta? web_app = null;
				try
				{
					web_app = web_app_reg.install_app(parent.get_child(package_name));
				}
				catch (WebAppError e)
				{
					critical("%s: %s", package_name, e.message);
				}
				expect(web_app != null, package_name);
			}
		}
		finally
		{
			Diorite.System.try_purge_dir(tmp_dir);
		}
	}
	
	public void test_install_invalid_packages()
	{
		// TODO
	}
	
	private WebAppRegistry create_registry(string? path, bool allow_management=false)
	{
		return new WebAppRegistry(File.new_for_path(path), {}, allow_management);
	}
	
	private string[] list_web_apps(string path)
	{
		string[] apps = {};
		var parent = File.new_for_path(path);
		message("path %s", parent.get_path());
		expect(parent.query_exists(), "");
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
			expectation_failed("Filesystem error: %s", e.message);
		}
		return apps;
	}
	
	private string[] list_files(string path)
	{
		string[] files = {};
		var parent = File.new_for_path(path);
		expect(parent.query_exists(), "");
		if (!parent.query_exists())
			return files;
		
		try
		{
			FileInfo file_info;
			var enumerator = parent.enumerate_children(FileAttribute.STANDARD_NAME, 0);
			while ((file_info = enumerator.next_file()) != null)
			{
				string name = file_info.get_name();
				
				var item = parent.get_child(name);
				if (item.query_file_type(0) != FileType.REGULAR)
					continue;
				
				files += name;
			}
		}
		catch (GLib.Error e)
		{
			warning("Filesystem error: %s", e.message);
			expectation_failed("Filesystem error: %s", e.message);
		}
		return files;
	}

}

} // namespace Nuvola
