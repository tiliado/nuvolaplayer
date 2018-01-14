/*
 * Copyright 2016-2018 Jiří Janoušek <janousek.jiri@gmail.com>
 * -> Engine.io-soup - the Vala/libsoup port of the Engine.io library
 *
 * Copyright 2014 Guillermo Rauch <guillermo@learnboost.com>
 * -> The original JavaScript Engine.io library
 * -> https://github.com/socketio/engine.io
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * 'Software'), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
namespace Engineio
{

public class JsonpTransport: PollingTransport
{
	private static Regex newlines = /(\\{2,4})n/;
	private string head;
	private string foot;
	
	public JsonpTransport(Request request)
	{
		base(request);
		head = "___eio[%s](".printf(request.jsonp_index >= 0 ? request.jsonp_index.to_string() :  "");
		foot = ");";
	}
	
	protected override async void handle_incoming_data(owned string? string_payload, Bytes? binary_payload)
	{
		if (string_payload != null)
		{
			string_payload = Soup.Form.decode(string_payload)["d"];
			//if ('string' == typeof data) {
			//client will send already escaped newlines as \\\\n and newlines as \\n
			// \\n must be replaced with \n and \\\\n with \\n
	    
			try
			{
				string_payload = newlines.replace_eval(string_payload, -1, 0, 0, (match, result) => 
				{
					result.append(match.fetch(1) == "\\\\" ? "\\" : "\\\\");
					return false;
				});
			}
			catch (RegexError e)
			{
				critical("RegexError %s", e.message);
			}
		}
		yield base.handle_incoming_data((owned) string_payload, binary_payload);
	}
	
	protected override void do_write(owned string? data, Bytes? bin_data, bool compress)
	{
	  // we must output valid javascript, not valid json
	  // see: http://timelessrepo.com/json-isnt-a-javascript-subset
		data = data.replace("\u2028", "\\u2028").replace("\u2029", "\\u2029");
	
	  base.do_write(head + data + foot, null, compress);
  }
}

} // namespace Engineio
