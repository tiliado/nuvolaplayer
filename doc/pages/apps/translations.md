Title: Translations

It is planned to provide a [gettext-based](http://www.gnu.org/software/gettext/manual/gettext.html)
translations framework for service integration scripts. The JavaScript API currently contains only
[translation placeholders](apiref>Nuvola.Translate) that can be used to mark strings for
translation.

Translation Functions
=====================

There are three ways how to use translations

 * Translations of strings that are unambiguous.
 * Translations of short strings that need a disambiguating message context
 * Translations of strings that have a singular and a plural form.

Unambiguous String
------------------

The most common case is you want to translate a string that is unambiguous,
i. e. it cannot be translated differently depending on a message context.

  * Use function [Translate.gettext](apiref>Nuvola.Translate.gettext).

        :::js
        console.log(Nuvola.Translate.gettext('Bye World!'))

  * It's common to create a short alias ``_``. (Note that other aliases won't be recognized by
    a translation extraction tool.)

        :::js
        var _ = Nuvola.Translate.gettext
        console.log(_('Hello world!'))

  * Note that you have to provide a string literal, not variable nor expression, because the
    translation extraction tool doesn't expand variables.

        :::js
        var greeting = 'Hello world!'
        console.log(_(greeting)) // Wrong!

        var greeting = _('Hello world!') // Right
        console.log(greeting)

  * If you need to compose message with variables, use [Nuvola.format](apiref>Nuvola.format).

        :::js
        var name = 'John'
        console.log(_('Hello ' + name + '!')) // Wrong!
        console.log(Nuvola.format(_('Hello {1}!'), name)) // Right
        var $fmt = Nuvola.format
        console.log($fmt(_('Hello {1}!'), name)) // Right

  * You can optionally add a comment for translators after tree slashes. It has to be on a line
    preceding the translated string though.

        :::js
        var name = 'John'
        /// {1} is a placeholder for user name
        console.log(Nuvola.format(_('Hello {1}!'), name))


Disambiguating message context
------------------------------

You might sometimes have short strings that could be translated differently depending on a context.
For example, 'Back' string in navigation or in a body part. You should use this function for
labels of [custom actions](:apps/custom-actions.html) or entries of
[initialization and preferences forms](:apps/initialization-and-preferences-forms.html).


  * Use function [Translate.pgettext](apiref>Nuvola.Translate.pgettext).

        :::js
        console.log(Nuvola.Translate.pgettext('Action label', 'Show notification'))
        console.log(Nuvola.Translate.pgettext('Checkbox label', 'Show notification'))

  * It's common to create a short alias ``C_``. (Note that other aliases won't be recognized by
    a translation extraction tool.)

        :::js
        var C_ = Nuvola.Translate.pgettext
        console.log(C_('Action label', 'Show notification'))
        console.log(C_('Checkbox label', 'Show notification'))

  * You can optionally add a comment for translators after tree slashes. It has to be on a line
    preceding the translated string though.

        :::js
        /// My comment
        console.log(C_('Action label', 'Show notification'))

        console.log(C_(
          'Checkbox label',
          /// My comment
          'Show notification'
          ))

Singular and plural form
------------------------

Gettext also support messages with a singular and a plural form.

  * Use function [Translate.ngettext](apiref>Nuvola.Translate.ngettext).

        :::js
        var eggs = 5;
        var text = Nuvola.Translate.ngettext(
          'There is {1} egg in the fridge.',
          'There are {1} eggs in the fridge.',
          eggs)
        console.log(Nuvola.format(text, eggs))

        var $fmt = Nuvola.format
        console.log($fmt(text, eggs))

  * It's common to create an  alias ``ngettext``. (Note that other aliases won't be recognized by
    a translation extraction tool.)

        :::js
        var ngettext = Nuvola.Translate.ngettext
        var eggs = 5
        var text = ngettext(
          'There is {1} egg in the fridge.',
          'There are {1} eggs in the fridge.',
          eggs)
        console.log(Nuvola.format(text, eggs))

  * It's possible to replace placeholder in the singular form with ``one``.

        :::js
        var text = ngettext(
          'There is one egg in the fridge.',
          'There are {1} eggs in the fridge.',
          eggs)
        console.log(Nuvola.format(text, eggs))

  * You can optionally add a comment for translators after tree slashes. It has to be on a line
    preceding the singular string though.

        :::js
        var text = ngettext(
          /// {1} is a placeholder for a number
          'There is one egg in the fridge.',
          'There are {1} eggs in the fridge.',
          eggs)
        console.log(Nuvola.format(text, eggs))

Extract translations
====================

Translatable strings will be eventually extracted by ``xgettext`` tool from the ``gettext`` package.
Make sure all strings you have intended to mark for translations do appear in generated translation
template including translation comments.

```sh
xgettext --from-code=utf-8 -kC_:1c,2 -c/ -o- integrate.js
```

Example
-------

```js
var _ = Nuvola.Translate.gettext
var C_ = Nuvola.Translate.pgettext
var ngettext = Nuvola.Translate.ngettext
var $fmt = Nuvola.format

var greeting = _('Hello world!')
console.log(greeting)

var name = 'John'
/// {1} is a placeholder for user name
console.log(Nuvola.format(_('Hello {1}!'), name))
console.log($fmt(_('Hello {1}!'), name))

/// My comment
console.log(C_('Action label', 'Show notification'))
console.log(C_(
  'Checkbox label',
  /// My comment
  'Show notification'
  ))

var eggs = 1
var text = ngettext(
    'There is {1} egg in the fridge.',
    'There are {1} eggs in the fridge.',
    eggs)
console.log(Nuvola.format(text, eggs))
console.log($fmt(text, eggs))

var eggs = 5
var text = ngettext(
  /// {1} is a placeholder for a number
  'There is one egg in the fridge.',
  'There are {1} eggs in the fridge.',
  eggs)
console.log(Nuvola.format(text, eggs))
```

```sh
xgettext --from-code=utf-8 -kC_:1c,2 -c/ -o- integrate.js
```

```gettext
# SOME DESCRIPTIVE TITLE.
# Copyright (C) YEAR THE PACKAGE'S COPYRIGHT HOLDER
# This file is distributed under the same license as the PACKAGE package.
# FIRST AUTHOR <EMAIL@ADDRESS>, YEAR.
#
#, fuzzy
msgid ""
msgstr ""
"Project-Id-Version: PACKAGE VERSION\n"
"Report-Msgid-Bugs-To: \n"
"POT-Creation-Date: 2014-09-07 10:21+0200\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\n"
"Last-Translator: FULL NAME <EMAIL@ADDRESS>\n"
"Language-Team: LANGUAGE <LL@li.org>\n"
"Language: \n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=CHARSET\n"
"Content-Transfer-Encoding: 8bit\n"
"Plural-Forms: nplurals=INTEGER; plural=EXPRESSION;\n"

#: integrate.js:131
msgid "Hello world!"
msgstr ""

#. / {1} is a placeholder for user name
#: integrate.js:136 integrate.js:137
msgid "Hello {1}!"
msgstr ""

#. / My comment
#: integrate.js:140
msgctxt "Action label"
msgid "Show notification"
msgstr ""

#. / My comment
#: integrate.js:144
msgctxt "Checkbox label"
msgid "Show notification"
msgstr ""

#: integrate.js:149
msgid "There is {1} egg in the fridge."
msgid_plural "There are {1} eggs in the fridge."
msgstr[0] ""
msgstr[1] ""

#. / {1} is a placeholder for a number
#: integrate.js:158
msgid "There is one egg in the fridge."
msgid_plural "There are {1} eggs in the fridge."
msgstr[0] ""
msgstr[1] ""

```
[TOC]
