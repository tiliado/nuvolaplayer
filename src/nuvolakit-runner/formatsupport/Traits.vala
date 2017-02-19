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

public class Traits
{
	public bool flash_supported {get; private set; default = false;}
	public bool flash_required {get; private set; default = false;}
	public bool mp3_supported {get; private set; default = false;}
	public bool h264_supported {get; private set; default = false;}
	public bool mse_supported {get; private set; default = false;}
	public bool mse_required {get; private set; default = false;}
	public uint webkitgtk_required {get; private set; default = 0;}
	private string? rule;
	
	public Traits(string? rule)
	{
		this.rule = rule;
		#if WEBKIT_SUPPORTS_MSE
		mse_supported = true;
		h264_supported = true;
		#endif
	}
	
	public bool eval() throws Drt.RequirementError
	{
		if (rule == null)
		{
			/* Legacy settings */
			rule = "Feature[flash] Codec[mp3]";
			warning("No requirements specified. '%s' used by default but that may change in the future.", rule);
			flash_required = true;
			return true;
		}
		return new Parser(this).eval(rule);
	}
	
	public void set_from_format_support(FormatSupport format_support)
	{
		
		flash_supported = format_support.n_flash_plugins > 0;
		mp3_supported = format_support.mp3_supported;
	}
	
	public bool eval_webkitgtk(uint major, uint minor, uint micro)
	{
		webkitgtk_required = major * 10000 + minor * 100 + micro;
		return WebEngine.get_webkit_version() >= webkitgtk_required;
	}
	
	public bool eval_feature(string name)
	{
		switch (name)
		{
		case "eme":
			return false;
		case "mse":
			mse_required = true;
			return mse_supported;
		case "flash":
			flash_required = true;
			return flash_supported;
		default:
			return false;
		}
	}
	
	public bool eval_codec(string name)
	{
		switch (name)
		{
		case "mp3":
			return mp3_supported;
		
		case "h264":
			return h264_supported;
		default:
			return false;
		}
	}


	private class Parser : Drt.RequirementParser
	{
		private Traits traits;
		
		public Parser(Traits traits)
		{
			this.traits = traits;
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
			case "flashaudiorequired":
			case "flashaudiopreferred":
				warning("No longer supported identifier in a format support expression: '%s'.", ident);
				return traits.eval_feature("flash");
			case "html5audiorequired":
			case "html5audiopreferred":
				warning("No longer supported identifier in a format support expression: '%s'.", ident);
				return traits.eval_codec("mp3");
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
			return traits.eval_codec(params.down());
		}
		
		private bool call_feature(int pos, string? params)
		{
			if (params == null)
				return set_eval_error(pos, "Feature[] needs a feature name as a parameter.");
			var name = params.strip().down();
			if (name[0] == 0)
				return set_eval_error(pos, "Feature[] needs a feature name as a parameter.");
			return traits.eval_feature(params.down());
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
			return traits.eval_webkitgtk(uint_versions[0], uint_versions[1], uint_versions[2]);
		}
	}
}

} // namespace Nuvola
