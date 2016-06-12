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

#if EXPERIMENTAL
namespace Nuvola.HttpRemoteControl
{

public class RequestContext
{
	public Soup.Server server;
	public Soup.Message msg;
	public string path;
	public GLib.HashTable? query;
	public Soup.ClientContext client;
	
	public RequestContext(
		Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client)
	{
		this.server = server;
		this.msg = msg;
		this.path = path;
		this.query = query;
		this.client = client;
	}
	
	public void respond_json(int status_code, Json.Node json)
	{
		var generator = new Json.Generator();
		generator.pretty = true;
		generator.indent = 4;
		generator.set_root(json);
		var data = generator.to_data(null);
		msg.set_response("text/plain; charset=utf-8", Soup.MemoryUse.COPY, data.data);
		msg.status_code = status_code;
	}
	
	public void respond_not_found()
	{
		msg.set_response(
			"text/html", Soup.MemoryUse.COPY,
			"<html><head><title>404</title></head><body><h1>404</h1><p>%s</p></body></html>".printf(
			   msg.uri.to_string(false)).data);
		msg.status_code = 404;
	}
	
	public void serve_file(File file)
	{
		string? mime_type = null;
		try
		{
			var content_type = file.query_info(FileAttribute.STANDARD_CONTENT_TYPE, 0).get_content_type();
			mime_type = ContentType.get_mime_type(content_type);
		}
		catch (GLib.Error e)
		{
			mime_type = null;
		}
		
		if (mime_type == null)
			mime_type = "application/octet-stream";
		else if (mime_type == "text/plain")
			mime_type += "; charset=utf8";
		try
		{
			uint8[] data;
			file.load_contents(null, out data, null);
			msg.response_headers.replace("Content-Type", mime_type);
			msg.response_body.append_take((owned) data);
			msg.status_code = 200;
		}
		catch (GLib.Error e)
		{
			warning("Failed to load file '%s': %s", file.get_path(), e.message);
			respond_not_found();
			return;
		}
	}
}

} // namespace Nuvola.HttpRemoteControl
#endif
