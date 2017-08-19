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
 
namespace Nuvola {

public class WebkitOptions : WebOptions {
	public override uint engine_version {get {return get_webkit_version();}}
	public WebKit.WebContext default_context{get; private set;}
	
	public WebkitOptions(WebAppStorage storage) {
		base(storage);
		var data_manager = (WebKit.WebsiteDataManager) GLib.Object.@new(
			typeof(WebKit.WebsiteDataManager),
			"base-cache-directory", storage.create_cache_subdir("webkit").get_path(),
			"disk-cache-directory", storage.create_cache_subdir("webcache").get_path(),
			"offline-application-cache-directory", storage.create_cache_subdir("offline_apps").get_path(),
			"base-data-directory", storage.create_data_subdir("webkit").get_path(),
			"local-storage-directory", storage.create_data_subdir("local_storage").get_path(),
			"indexeddb-directory", storage.create_data_subdir("indexeddb").get_path(),
			"websql-directory", storage.create_data_subdir("websql").get_path());
		var web_context =  new WebKit.WebContext.with_website_data_manager(data_manager);
		web_context.set_favicon_database_directory(storage.create_data_subdir("favicons").get_path());
		/* Persistence must be set up after WebContext is created! */
		var cookie_manager = data_manager.get_cookie_manager();
		cookie_manager.set_persistent_storage(storage.data_dir.get_child("cookies.dat").get_path(),
			WebKit.CookiePersistentStorage.SQLITE);	
		default_context = web_context;
	}
	
	public static uint get_webkit_version()
	{
		return WebKit.get_major_version() * 10000 + WebKit.get_minor_version() * 100 + WebKit.get_micro_version(); 
	}
}

} // namespace Nuvola
