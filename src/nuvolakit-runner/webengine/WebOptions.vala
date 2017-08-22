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

public abstract class WebOptions : GLib.Object {
	private static bool have_default;
	private static Type? default_options_class = null;
	
	public static bool set_default(Type type) {
		if (!have_default) {
			default_options_class = type;
			have_default = true;
			return true;
		}
		return false;
	}
	
	public static Type get_default() {
		return have_default ? default_options_class : null;
	}
	
	public static WebOptions? create_default(WebAppStorage storage) {
		if (have_default) {
			return (WebOptions) GLib.Object.@new(default_options_class, "storage", storage);
		}		
		return null;
	}
	
	public WebAppStorage storage {get; construct;}
	public abstract uint engine_version {get;}
	
	public WebOptions(WebAppStorage storage) {
		GLib.Object (storage: storage);
	}
	
	public bool check_engine_version(uint min, uint max=0)
	{
		var version = engine_version;
 		return version >= min && (max == 0 || version < max);
	}
	
	public abstract WebEngine create_web_engine();
}

} // namespace Nuvola
