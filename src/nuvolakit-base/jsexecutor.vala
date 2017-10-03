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

public interface JSExecutor: GLib.Object
{
	public abstract void call_function(string name, ref Variant? params, bool propagate_error=false) throws GLib.Error;
	
	public string? send_data_request_string(string name, string key, string? default_value=null) throws GLib.Error
	{
		var default_variant = default_value == null ? null : new Variant.string(default_value);
		var variant = send_data_request_variant(name, key, default_variant);
		if (variant == null || !variant.is_of_type(VariantType.STRING))
			return null;
		var result = variant.get_string();
		
		return result != "" ? result : null;
	}
	
	public bool send_data_request_bool(string name, string key, bool default_value) throws GLib.Error
	{
		var variant = send_data_request_variant(name, key, new Variant.boolean(default_value));
		if (variant == null || !variant.is_of_type(VariantType.BOOLEAN))
			return default_value;
		return variant.get_boolean();
	}
	
	private Variant? send_data_request_variant(string name, string key, Variant? default_value=null)
	throws GLib.Error {
		var builder = new VariantBuilder(new VariantType("a{smv}"));
		builder.add("{smv}", key, default_value);
		var args = new Variant("(s@a{smv})", name, builder.end());
		call_function("Nuvola.core.emit", ref args, false);
		VariantIter iter = args.iterator();
		assert(iter.next("s", null));
		assert(iter.next("a{smv}", &iter));
		string dict_key = null;
		Variant value = null;
		while (iter.next("{smv}", &dict_key, &value)) {
			if (dict_key == key) {
				return value;
			}
		}
		return null;
	}
}

} // namespace Nuvola
