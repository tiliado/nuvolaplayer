/*
 * Copyright 2021 Jiří Janoušek <janousek.jiri@gmail.com>
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

public class TiliadoSurvey: GLib.Object {
    public const string DEFAULT_URL_TEMPLATE = "https://survey.tiliado.eu/%s/%s/";
    public const string INFO_URL = "https://github.com/tiliado/nuvolaplayer/issues/678";
    public string? survey_key = null;
    private string url_template;
    private string survey_id;

    public TiliadoSurvey(string? url_template, string survey_id, string? survey_key = null) {
        this.url_template = url_template ?? DEFAULT_URL_TEMPLATE;
        this.survey_id = survey_id;
        this.survey_key = survey_key;
    }

    public string? get_survey_url() {
        if (Drt.String.is_empty(survey_key)) {
            return null;
        }
        string? code = TiliadoSurvey.create_survey_code(survey_key);
        return code == null ? null : url_template.printf(survey_id, code);
    }

    public static string? create_survey_code(string key) {
        var s = new StringBuilder.sized(key.length);
        unichar c;
        for (int i = 0; key.get_next_char(ref i, out c);) {
            if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
                s.append_unichar(c);
            }
        }
        if (s.len == 0) {
            return null;
        }

        return GLib.Checksum.compute_for_string(GLib.ChecksumType.SHA256, s.str.down());
    }
}

} // namespace Nuvola
