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

namespace Nuvola {

public class RequirementParser : Drt.RequirementParser {
	private WebOptions web_options;
	
	public RequirementParser(WebOptions web_options) {
		this.web_options = web_options;
	}
	
	protected override Drt.RequirementState call(int pos, string ident, string? params) {
		var type = ident.down();
		Drt.RequirementState result = Drt.RequirementState.UNSUPPORTED;
		switch (type) {
		case "codec":
			result = call_codec(pos, params);
			break;
		case "feature":
			result = call_feature(pos, params);
			break;
		case "flashaudiorequired":
		case "flashaudiopreferred":
			warning("No longer supported identifier in a format support expression: '%s'.", ident);
			result = call_feature(pos, "flash");
			break;
		case "html5audiorequired":
		case "html5audiopreferred":
			warning("No longer supported identifier in a format support expression: '%s'.", ident);
			result = call_codec(pos, "mp3");
			break;
		default:
			string? error = null;
			result = web_options.supports_requirement(type, params, out error);
			if (error != null) {
				set_eval_error(pos, error);
			}
			break;
		}
		debug("%s[%s] -> %s ", ident, params, result.to_string());
		return result;
	}
	
	private Drt.RequirementState call_codec(int pos, string? params) {
		if (params == null) {
			set_eval_error(pos, "Codec[] needs a codec name as a parameter.");
			return Drt.RequirementState.ERROR;
		}
		var name = params.strip().down();
		if (name[0] == 0) {
			set_eval_error(pos, "Codec[] needs a codec name as a parameter.");
			return Drt.RequirementState.ERROR;
		}
		string? error = null;
		var result = web_options.supports_codec(name, out error);
		if (error != null) {
			set_eval_error(pos, error);
		}
		return result;
	}
	
	private Drt.RequirementState call_feature(int pos, string? params) {
		if (params == null) {
			set_eval_error(pos, "Feature[] needs a feature name as a parameter.");
			return Drt.RequirementState.ERROR;
		}
		var name = params.strip().down();
		if (name[0] == 0) {
			set_eval_error(pos, "Feature[] needs a feature name as a parameter.");
			return Drt.RequirementState.ERROR;
		}
		string? error = null;
		var result = web_options.supports_feature(name, out error);
		if (error != null) {
			set_eval_error(pos, error);
		}
		return result;
	}
}

} // namespace Nuvola
