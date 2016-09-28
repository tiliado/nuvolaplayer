public void serve_file(Soup.Message msg, File file) throws GLib.Error
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
		
	uint8[] contents;
	file.load_contents(null, out contents, null);
	msg.response_headers.replace("Content-Type", mime_type);
	msg.response_body.append_take((owned) contents);
	msg.status_code = 200;
}

private void default_handler(Soup.Server server, Soup.Message msg, string request_path, GLib.HashTable? query, Soup.ClientContext client)
{
	var path = msg.uri.get_path();
	if (path.has_suffix("/"))
		path += "index";
	var file = File.new_for_path("./www" + path);
	if (file.query_file_type(FileQueryInfoFlags.NONE, null) != FileType.REGULAR)
	{
		path += ".html";
		file = File.new_for_path("./www" + path);
		if (file.query_file_type(FileQueryInfoFlags.NONE, null) != FileType.REGULAR)
		{
			set_404(msg);
			return;
		}
	}
	
	try
	{
		serve_file(msg, file);
	}
	catch (GLib.Error e)
	{
		set_404(msg);
	}
}

public static void set_error(Soup.Message msg, int code)
{
	msg.set_response ("text/plain", Soup.MemoryUse.COPY, code.to_string().data);
	msg.status_code = code;
}

public static void set_404(Soup.Message msg)
{
	msg.set_response ("text/plain", Soup.MemoryUse.COPY, "404".data);
	msg.status_code = 404;
}

void main()
{
	Diorite.Logger.init(stderr, GLib.LogLevelFlags.LEVEL_DEBUG);
	var soup = new Soup.Server(null);
	soup.add_handler (null, default_handler);
	var engineio = new Engineio.Server(soup);
	engineio.soup.listen_local(8080, 0);
	message("Listening om %d", 8080);
    new MainLoop().run();
}
