/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class VariantHashTable : GLib.Object, Diorite.KeyValueStorage
{
	public HashTable<string, Variant?> values {get; private set;}
	private HashTable<string, bool> keys {get; set;}

	public VariantHashTable(HashTable<string, Variant?>? values = null)
	{
		this.values = values != null ? values : new HashTable<string, Variant>(str_hash, str_equal);
		keys = new HashTable<string, bool>(str_hash, str_equal);
	}
	
	public bool save() throws GLib.Error
	{
		return false;
	}
	
	public bool has_key(string key)
	{
		return key in keys;
	}
	
	public Variant? get_value(string key)
	{
		return values[key];
	}
	
	public void set_value(string key, Variant? value)
	{
		if (value != null)
		{
			values[key] = value;
			keys[key] = true;
		}
		else
		{
			values.remove(key);
			keys.remove(key);
		}
	}
	
	public void set_default_value(string key, Variant? value)
	{
		if (value != null && !values.contains(key))
			values.insert(key, value);
	}
	
	public void unset(string key)
	{
		warn_if_reached(); // FIXME
	}
}

} // namespace Nuvola
