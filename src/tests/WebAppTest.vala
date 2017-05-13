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

public class WebAppTest: Diorite.TestCase
{
	public void test_construct()
	{
		expect_no_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "http://maintainer_link", 4, 3, 3, 1, null, null, null, 1200, 800),
			"valid params");
		expect_error(() => new Nuvola.WebApp(
			"", "name", "maintainer_name", "http://maintainer_link", 4, 3, 3, 1, null, null, null, 1200, 800),
			"*Invalid app id*", "empty id");
		expect_error(() => new Nuvola.WebApp(
			"-id", "name", "maintainer_name", "http://maintainer_link",	4, 3, 3, 1, null, null, null, 1200, 800),
			"*Invalid app id*", "invalid id");
		expect_error(() => new Nuvola.WebApp(
			"id", "", "maintainer_name", "http://maintainer_link", 4, 3, 3, 1, null, null, null, 1200, 800),
			"*Empty 'name' entry*", "empty name");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "", "http://maintainer_link", 4, 3, 3, 1, null, null, null, 1200, 800),
			"*Empty 'maintainer_name' entry*", "empty maintainer");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "", 4, 3, 3, 1, null, null, null, 1200, 800),
			"*Empty or invalid 'maintainer_link' entry*", "empty maintainer link");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "file://maintainer_link", 4, 3, 3, 1, null, null, null, 1200, 800),
			"*Empty or invalid 'maintainer_link' entry*", "invalid maintainer link");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "http://maintainer_link", 0, 3, 3, 1, null, null, null, 1200, 800),
			"*Major version must be greater than zero*", "zero major version");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "http://maintainer_link", -3, 3, 3, 1, null, null, null, 1200, 800),
			"*Major version must be greater than zero*", "negative major version");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "http://maintainer_link", 4, -3, 3, 1, null, null, null, 1200, 800),
			"*Minor version must be greater or equal to zero*", "invalid minor version");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "http://maintainer_link", 4, 3, -3, 1, null, null, null, 1200, 800),
			"*Major api_version must be greater than zero*", "invalid api major");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "http://maintainer_link", 4, 3, 0, 1, null, null, null, 1200, 800),
			"*Major api_version must be greater than zero*", "invalid api major");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "http://maintainer_link", 4, 3, 3, -1, null, null, null, 1200, 800),
			"*Minor api_version must be greater or equal to zero*", "invalid api minor");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "http://maintainer_link", 4, 3, 3, 1, null, null, null, -1200, 800),
			"*Property window_width must be greater or equal to zero*", "invalid window width");
		expect_error(() => new Nuvola.WebApp(
			"id", "name", "maintainer_name", "http://maintainer_link", 4, 3, 3, 1, null, null, null, 1200, -800),
			"*Property window_height must be greater or equal to zero*", "invalid window height");
	}
	
	public void test_construct_from_dir()
	{
		expect_no_error(() => new Nuvola.WebApp.from_dir(File.new_for_path("web_apps/test")), "test service");
	}
	
	public void test_construct_from_metadata()
	{
		expect_no_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"valid meta");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"#id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The id key is missing or is not a string*", "invalid id");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"#name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The name key is missing or is not a string*", "invalid name");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"#maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The maintainer_name key is missing or is not a string*", "invalid maintainer_name");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"#maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The maintainer_link key is missing or is not a string*", "invalid maintainer_link");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"#version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The version_major key is missing or is not an integer*", "invalid version_major");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"#version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The version_minor key is missing or is not an integer*", "invalid version_minor");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"#api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The api_major key is missing or is not an integer*", "invalid api_major");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"#api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The api_minor key is missing or is not an integer*", "invalid api_minor");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": 1,
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The id key is missing or is not a string*", "invalid id");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": 1,
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The name key is missing or is not a string*", "invalid name");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": 10,
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The maintainer_name key is missing or is not a string*", "invalid maintainer_name");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": 11,
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The maintainer_link key is missing or is not a string*", "invalid maintainer_link");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": "abc",
				"version_minor": 0,
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The version_major key is missing or is not an integer*", "invalid version_major");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": "abc",
				"api_major": 3,
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The version_minor key is missing or is not an integer*", "invalid version_minor");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": "abc",
				"api_minor": 0,
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The api_major key is missing or is not an integer*", "invalid api_major");
		expect_error(() => new Nuvola.WebApp.from_metadata("""
			{
				"id": "test",
				"name": "Test",
				"maintainer_name": "Jiří Janoušek",
				"maintainer_link": "https://github.com/fenryxo",
				"version_major": 1,
				"version_minor": 0,
				"api_major": 3,
				"api_minor": "abc",
				"categories": "AudioVideo;Audio;",
				"home_url": "nuvola://home.html",
				"hidden": true,
				"window_width": 2000,
				"window_height": 2000,
				"requirements": "Codec[MP3] Feature[Flash]"
			}
			""", null),
			"*The api_minor key is missing or is not an integer*", "invalid api_minor");
	}
}

} // namespace Nuvola
