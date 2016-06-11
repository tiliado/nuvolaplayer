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

public class AppRequest
{
    public string app_path;
    public string method;
    public string uri;
    private string? body_base64;
    private uint8[]? body_bytes;
   
    public AppRequest(string app_path, string method, string uri, uint8[]? body_bytes)
    {
        this.app_path = app_path;
        this.method = method;
        this.uri = uri;
		this.body_bytes = body_bytes;
    }
    
    public AppRequest.from_request_context(string app_path, RequestContext request)
    {
		var msg = request.msg;
		this(
		    app_path, msg.method, msg.uri.to_string(false),
		    msg.request_body == null ? null : msg.request_body.flatten().data);
    }
    
    public AppRequest.from_variant(Variant variant)
    {
		string app_path = null;
		string method = null;
		string uri = null;
		var dict = new VariantDict(variant);
		dict.lookup("app_path", "s", &app_path);
		dict.lookup("method", "s", &method);
		dict.lookup("uri", "s", &uri);
		this(app_path, method, uri, null);
		if (!dict.lookup("body", "s", &this.body_base64))
		    this.body_base64 = null;
    }
    
    public uint8[]? get_body()
    {
		if (body_bytes == null && body_base64 != null)
		{
			body_bytes = Base64.decode(body_base64);
			body_base64 = null;
		}
		return body_bytes;
    }
    
    public string? get_base64_body()
    {
		if (body_bytes != null && body_base64 == null)
		    return Base64.encode(body_bytes);
		return body_base64 = null;
    }
    
    public Variant to_variant()
    {
		var builder = new VariantBuilder(new VariantType("a{sv}"));
		builder.add("{sv}", "type", new Variant.string("AppRequest"));
		builder.add("{sv}", "app_path", new Variant.string(app_path));
		builder.add("{sv}", "method", new Variant.string(method));
		builder.add("{sv}", "uri", new Variant.string(uri));
		var body = get_base64_body();
		if (body != null)
		    builder.add("{sv}", "body", new Variant.bytestring(body));
		return builder.end();
    }
    
    public string to_string()
    {
		return to_variant().print(false);
    }
}

} // namespace Nuvola.HttpRemoteControl
#endif
