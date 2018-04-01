/*
 * Copyright 2014-2018 Jiří Janoušek <janousek.jiri@gmail.com>
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

require('logging')

/**
 * @namespace Translation functions.
 *
 * These functions are only placeholders for now, but you can use them to mark translatable strings
 * and then check whether they are properly recognized by a tool ``xgettext`` from the ``gettext``
 * package.
 *
 * See also @link{doc>apps/translations.html|translations documentation}.
 */
var Translate = {}

/**
 * Translate string.
 *
 *
 * **Placeholder**: This function is only a placeholder for future functionality, but you can use it to mark
 * translatable strings.
 *
 * **Usage notes**
 *
 *   * It is usual to create alias ``var _ = Nuvola.Translate.gettext;``
 *   * You have to pass plain string literals, not expressions nor variables.
 *
 * @param String text    text to translate
 * @return String        translated string
 *
 * ```
 * var _ = Nuvola.Translate.gettext;
 * /// You can use tree slashes to add comment for translators.
 * /// It has to be on a line preceding the translated string though.
 * console.log(_("Hello world!")); // Right
 *
 * var greeting = "Hello world!";
 * console.log(_(greeting)); // Wrong!
 *
 * var greeting = _("Hello world!"); // Right
 * console.log(greeting);
 *
 * var name = "John";
 * console.log(_("Hello " + name + "!")); // Wrong!
 * console.log(Nuvola.format(_("Hello {1}!"), name)); // Right
 * ```
 */
Translate.gettext = function (text) {
    // TODO: string g_dgettext(string domain, string msgid);
  return text
}

/**
 * Translate string with support of a disambiguating message context.
 *
 * This is mainly useful for short strings which may need different translations, depending on the context in which they
 * are used. e.g.: ``pgettext("Navigation", "Back")`` vs ``pgettext("Body part", "Back")``.
 *
 * **Placeholder**: This function is only a placeholder for future functionality, but you can use it to mark
 * translatable strings.
 *
 * **Usage notes**
 *
 *   * It is usual to create alias ``var C_ = Nuvola.Translate.pgettext;``
 *   * You have to pass plain string literals, not expressions nor variables.
 *
 * @param String context    the message context
 * @param String text       text to translate
 * @return String           translated string
 *
 * ```
 * var C_ = Nuvola.Translate.pgettext;
 * /// You can use tree slashes to add comment for translators.
 * /// It has to be on a line preceding the translated string though.
 * console.log(C_("Navigation", "Back"));
 * console.log(C_("Body part", "Back"));
 * ```
 */
Translate.pgettext = function (context, text) {
  if (!context) {
    Nuvola.warn("Context information passed to Translate.pgettext is invalid: {1}, '{2}'", context, text)
    return Translate.gettext(text)
  }

    // TODO: string g_dpgettext2 (string domain, string context, string msgid)
  return text
}

/**
 * Translate string with support of singluar and plural forms.
 *
 *
 * **Placeholder**: This function is only a placeholder for future functionality, but you can use it to mark
 * translatable strings.
 *
 * **Usage notes**
 *
 *   * It is usual to create alias ``var ngettext = Nuvola.Translate.ngettext;``
 *   * You have to pass plain string literals, not expressions nor variables.
 *
 * @param String text1      singular form
 * @param String text2      plural form
 * @param Number n          number of items
 * @return String           translated string
 *
 * ```
 * var ngettext = Nuvola.Translate.ngettext;
 * var eggs = 5;
 * var text = ngettext(
 *     "There is {1} egg in the fridge.",
 *     "There are {1} eggs in the fridge.",
 *     eggs);
 * console.log(Nuvola.format(text, eggs));
 *
 * var text = ngettext(
 *     /// You can use tree slashes to add comment for translators.
 *     /// It has to be on a line preceding the singular string though.
 *     /// {1} will be replaced by number of eggs in both forms,
 *     /// but can be omitted as shown in singular form.
 *     "There is one egg in the fridge.",
 *     "There are {1} eggs in the fridge.",
 *     eggs);
 * ```
 */
Translate.ngettext = function (text1, text2, n) {
    // TODO: //  string g_dngettext (string domain, string msgid1, string msgid2, ulong n)
  return n === 1 ? text1 : text2
}

// export public items
Nuvola.Translate = Translate
