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

public class BindingsTest: Diorite.TestCase
{
	private static const string SERVER_NAME = "test_server";
	private static const string CLIENT_NAME = "test_client";
	private static const string NO_COMPONENTS = "*has no registered components*";
	private static const string NO_HANDLERS = "*No handler for message*";
	private Diorite.Ipc.MessageServer runner_server;
	private Diorite.Ipc.MessageServer worker_server;
	private WebWorker web_worker;
	private Diorite.Ipc.MessageClient runner_client;
	private Bindings bindings;
	
	public override void set_up()
	{
		try
		{
			runner_server = new Diorite.Ipc.MessageServer(SERVER_NAME);
			runner_server.start_service();
		}
		catch (Diorite.IOError e)
		{
			fail("runner server error: %s", e.message);
		}
		
		try
		{
			worker_server = new Diorite.Ipc.MessageServer(CLIENT_NAME);
			worker_server.start_service();
		}
		catch (Diorite.IOError e)
		{
			fail("worker server error: %s", e.message);
		}
		
		web_worker = new RemoteWebWorker(CLIENT_NAME, 5000);
		runner_client = new Diorite.Ipc.MessageClient(SERVER_NAME, 5000);
		
		bindings = new Bindings();
	}
	
	private void call_runner(Binding binding, string method, Variant? params=null)
	{
		var message = binding.name + "." + method;
		try
		{
			runner_client.send_message(message, params);
		}
		catch (Diorite.Ipc.MessageError e)
		{
			expectation_failed("method %s(%s) failed: %s", message, params == null ? "null" : params.print(true), e.message);
		}
	}
	
	[Diagnostics]
	private void expect_runner_error(string pattern, Binding binding, string method, Variant? params, string mark)
	{
		var message = binding.name + "." + method;
		try
		{
			runner_client.send_message(message, params);
			fail("%smethod %s(%s) should produce error", mark, message, params == null ? "null" : params.print(true));
		}
		catch (Diorite.Ipc.MessageError e)
		{
			expect_str_match(pattern, e.message, "%sError of method %s(%s):", mark, message, params == null ? "null" : params.print(true));
		}
	}
	
	public void test_actions_binding_empty()
	{
		var binding = new ActionsBinding(runner_server, web_worker);
		bindings.add_binding(binding);
		
		expect_runner_error(NO_HANDLERS, binding, "dummy", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "addAction", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "addRadioAction", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "isEnabled", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "setEnabled", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "getState", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "setState", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "activate", null, "");
	}
	
	public void test_launcher_binding_empty()
	{
		var binding = new LauncherBinding(runner_server, web_worker);
		bindings.add_binding(binding);
		
		expect_runner_error(NO_HANDLERS, binding, "dummy", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "setTooltip", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "setActions", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "addAction", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "removeAction", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "removeActions", null, "");
	}
	
	public void test_notifications_binding_empty()
	{
		var binding = new NotificationsBinding(runner_server, web_worker);
		bindings.add_binding(binding);
		
		expect_runner_error(NO_HANDLERS, binding, "dummy", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "showNotification", null, "");
	}
	
	public void test_notification_binding_empty()
	{
		var binding = new NotificationBinding(runner_server, web_worker);
		bindings.add_binding(binding);
		
		expect_runner_error(NO_HANDLERS, binding, "dummy", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "update", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "setActions", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "removeActions", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "show", null, "");
	}
	
	public void test_media_keys_binding_empty()
	{
		var binding = new MediaKeysBinding(runner_server, web_worker);
		bindings.add_binding(binding);
		
		expect_runner_error(NO_HANDLERS, binding, "dummy", null, "");
	}
	
	public void test_menu_bar_binding_empty()
	{
		var binding = new MenuBarBinding(runner_server, web_worker);
		bindings.add_binding(binding);
		
		expect_runner_error(NO_HANDLERS, binding, "dummy", null, "");
		expect_runner_error(NO_COMPONENTS, binding, "setMenu", null, "");
	}
}

} // namespace Nuvola
