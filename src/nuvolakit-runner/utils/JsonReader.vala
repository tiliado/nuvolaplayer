/*
 * Copyright 2016 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class JsonReader
{
	private Json.Reader? reader;
	
	public JsonReader()
	{
		reader = null;
	}
	
	public void load_from_data(string? data) throws GLib.Error
	{
		if (data == null || data[0] == 0)
			throw new GLib.IOError.INVALID_DATA("Data is empty.");
		var parser = new Json.Parser();
		parser.load_from_data(data);
		var node = parser.get_root();
		if (node == null)
			throw new GLib.IOError.INVALID_DATA("Root node is null.");
		reader = new Json.Reader(node);
	}
	
	public string? get_string_member_or(string name, string? default_value)
	{
		string? result;
		if (string_member(name, out result))
			return result;
		return default_value;
	}
	
	public bool string_member(string name, out string? result)
	{
		result = null;
		return_val_if_fail(reader != null, false);
		bool success = false;
		if (reader.read_member(name) && reader.is_value())
		{
			unowned Json.Node node = reader.get_value();
			if (node.get_value_type() == typeof(string))
			{
				result = node.dup_string();
				success = true;
			}
		}
		reader.end_member();
		return success;
	}
	
	public bool string_element(int index, out string? result)
	{
		result = null;
		return_val_if_fail(reader != null, false);
		bool success = false;
		if (reader.read_element(index) && reader.is_value())
		{
			unowned Json.Node node = reader.get_value();
			if (node.get_value_type() == typeof(string))
			{
				result = node.dup_string();
				success = true;
			}
		}
		reader.end_element();
		return success;
	}
	
	public bool get_bool_member_or(string name, bool default_value)
	{
		bool result;
		if (bool_member(name, out result))
			return result;
		return default_value;
	}
	
	public bool bool_member(string name, out bool result)
	{
		result = false;
		return_val_if_fail(reader != null, false);
		bool success = false;
		if (reader.read_member(name) && reader.is_value())
		{
			unowned Json.Node node = reader.get_value();
			if (node.get_value_type() == typeof(bool))
			{
				result = node.get_boolean();
				success = true;
			}
		}
		reader.end_member();
		return success;
	}
	
	public int get_int_member_or(string name, int default_value)
	{
		int result;
		if (int_member(name, out result))
			return result;
		return default_value;
	}
	
	public bool int_member(string name, out int result)
	{
		result = 0;
		return_val_if_fail(reader != null, false);
		bool success = false;
		if (reader.read_member(name) && reader.is_value())
		{
			unowned Json.Node node = reader.get_value();
			if (node.get_value_type() == typeof(int64))
			{
				result = (int) node.get_int();
				success = true;
			}
		}
		reader.end_member();
		return success;
	}
	
	public int get_int_element_or(int index, int default_value)
	{
		int result;
		return int_element(index, out result) ? result : default_value;
	}
	
	public bool int_element(int index, out int result)
	{
		result = 0;
		return_val_if_fail(reader != null, false);
		bool success = false;
		if (reader.read_element(index) && reader.is_value())
		{
			unowned Json.Node node = reader.get_value();
			if (node.get_value_type() == typeof(int64))
			{
				result = (int) node.get_int();
				success = true;
			}
		}
		reader.end_element();
		return success;
	}
	
	public bool intv_member(string name, out int[] result)
	{
		result = {};
		return_val_if_fail(reader != null, false);
		bool success = false;
		if (reader.read_member(name) && reader.is_array())
		{
			var size = reader.count_elements();
			result = new int[size];
			success = true;
			for (var i = 0; i < size; i++)
			{
				int val;
				if (int_element(i, out val))
				{
					result[i] = val;
				}
				else
				{
					success = false;
					break;
				}
			}
			reader.end_element(); // This is a necessary workaround
		}
		reader.end_member();
		return success;
	}
	
	public bool strv_member(string name, out string[] result)
	{
		result = {};
		return_val_if_fail(reader != null, false);
		bool success = false;
		if (reader.read_member(name) && reader.is_array())
		{
			var size = reader.count_elements();
			result = new string[size];
			success = true;
			for (var i = 0; i < size; i++)
			{
				string val;
				if (string_element(i, out val))
				{
					result[i] = val;
				}
				else
				{
					success = false;
					break;
				}
			}
		}
		reader.end_member();
		return success;
	}
}

} // namespace Nuvola
