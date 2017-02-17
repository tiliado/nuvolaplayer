/*
 * Copyright 2017 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class FormatSupportExpression : Drt.ConditionalExpression
{
	private FormatSupport formats;
	
	public FormatSupportExpression(FormatSupport formats)
	{
		this.formats = formats;
	}
	
	protected override bool call(int pos, string ident, string? params)
	{
		var ci_ident = ident.down();
		bool result = false;
		switch (ci_ident)
		{
		case "codec":
			result = call_codec(pos, params);
			break;
		case "webkitgtk":
			result = call_webkitgtk(pos, params);
			break;
		case "feature":
			result = call_feature(pos, params);
			break;
		default:
			warning("Unknown identifier in a format support expression: '%s'.", ident);
			return false;
		}
		debug("%s[%s] -> %s ", ident, params, result.to_string());
		return result;
	}
	
	private bool call_codec(int pos, string? params)
	{
		if (params == null)
			return set_eval_error(pos, "Codec[] needs a codec name as a parameter.");
		var name = params.strip().down();
		if (name[0] == 0)
			return set_eval_error(pos, "Codec[] needs a codec name as a parameter.");
		switch (name)
		{
		case "mp3":
			return formats.mp3_supported;
		case "h264":
			return true; // FIXME
		default:
			return false;
		}
	}
	
	private bool call_feature(int pos, string? params)
	{
		if (params == null)
			return set_eval_error(pos, "Feature[] needs a feature name as a parameter.");
		var name = params.strip().down();
		if (name[0] == 0)
			return set_eval_error(pos, "Feature[] needs a feature name as a parameter.");
		switch (name)
		{
		case "eme":
			return false;
		#if WEBKIT_SUPPORTS_MSE
		case "mse":
			return true;
		#endif
		default:
			return false;
		}
	}
	
	private bool call_webkitgtk(int pos, string? params)
	{
		if (params == null)
			return set_eval_error(pos, "WebKitGtk[] needs a version as a parameter.");
		var param = params.strip().down();
		if (param[0] == 0)
			return set_eval_error(pos, "WebKitGtk[] needs a version name as a parameter.");
		var versions = param.split(".");
		if (versions.length > 3)
			return set_eval_error(pos, "WebKitGtk[] received invalid version parameter '%s'.", param);
		uint[] uint_versions = {0, 0, 0};
		for (var i = 0; i < versions.length; i++)
		{
			var version = int.parse(versions[i]);
			if (i < 0)
			return set_eval_error(pos, "WebKitGtk[] received invalid version parameter '%s'.", param);
			uint_versions[i] = (uint) version;
		}
		if (uint_versions[0] == 0)
			return set_eval_error(pos, "WebKitGtk[] received invalid version parameter '%s'.", param);
		return WebEngine.get_webkit_version() >= uint_versions[0] * 10000 + uint_versions[1] * 100 + uint_versions[2];
	}
}

} // namespace Nuvola
