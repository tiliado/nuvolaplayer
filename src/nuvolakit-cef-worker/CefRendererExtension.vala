namespace Nuvola {

public class CefRendererExtension : GLib.Object {
	private CefGtk.RendererContext ctx;
	private int browser_id;
	private Drt.RpcChannel channel;
	private File data_dir;
	private File user_config_dir;
	private string? api_token = null;
	private HashTable<string, Variant>? worker_data;
	private Drt.XdgStorage storage;
	
	public CefRendererExtension(CefGtk.RendererContext ctx, int browser_id, Drt.RpcChannel channel,
	HashTable<string, Variant> worker_data) {
		this.ctx = ctx;
		this.browser_id = browser_id;
		this.channel = channel;
		this.worker_data = worker_data;
		this.storage = new Drt.XdgStorage.for_project(Nuvola.get_app_id());
	}
	
	public void init() {
		ainit.begin((o, res) => {ainit.end(res);});
	}
	
	private async void ainit() {
		Variant response;
		try {
			response = yield channel.call("/nuvola/core/get-data-dir", null);
			data_dir = File.new_for_path(response.get_string());
			response = yield channel.call("/nuvola/core/get-user-config-dir", null);
			user_config_dir = File.new_for_path(response.get_string());
		} catch (GLib.Error e) 	{
			error("Runner client error: %s", e.message);
		}
		
		/* Use worker_data and free it. */
		uint[] webkit_version = new uint[3];
		webkit_version[0] = (uint) worker_data["WEBKITGTK_MAJOR"].get_int64();
		webkit_version[1] = (uint) worker_data["WEBKITGTK_MINOR"].get_int64();
		webkit_version[2] = (uint) worker_data["WEBKITGTK_MICRO"].get_int64();
		uint[] libsoup_version = new uint[3];
		libsoup_version[0] = (uint) worker_data["LIBSOUP_MAJOR"].get_int64();
		libsoup_version[1] = (uint) worker_data["LIBSOUP_MINOR"].get_int64();
		libsoup_version[2] = (uint) worker_data["LIBSOUP_MICRO"].get_int64();
		api_token = worker_data["NUVOLA_API_ROUTER_TOKEN"].get_string();
		worker_data = null;
		
		channel.call.begin("/nuvola/core/web-worker-initialized", null, (o, res) => {
			try {
				channel.call.end(res);
			} catch (GLib.Error e) {
				error("Runner client error: %s", e.message);
			}
		});
	}
}

} // namespace Nuvola
