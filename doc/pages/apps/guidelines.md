Title: Service Integration Guidelines

If you would like to have your service integration **maintained as a part of the Nuvola Player project
and distributed in the Nuvola Player repository**, following rules apply.

Formal Rules
============

1. Copyright and license of all files must be clearly documented in `README.md`. All files must
   have license approved by [the Open Source Initiative](http://opensource.org/licenses),
   preferably the same license as Nuvola Player (BSD 2-Clause "Simplified" or "FreeBSD" license).
   Full text of a license must be provided in file `LICENSE` or `LICENSE.txt`. If more than one
   license are used, add a distinguishing suffix, e.g. `LICENSE-BSD.txt`. You can look at
   [README.md template](https://github.com/tiliado/nuvola-app-template/blob/master/README.md)
   for inspiration.

2. The field ``maintainer_link`` of ``metadata.json`` must contain URL of your
   [Github profile][github]. (You will be subscribed to bug reports related to your service
   integrations).

3. You must provide contact e-mail in `README.md`, e.g. inside Copyright section.

4. You must use a consistent coding style of ``integrate.json``, preferably the coding style of
   Nuvola Player.

5. You must use [strict JavaScript mode][JS_STRICT] and [self-executing anonymous function][JS_SEAF].
   (See [tutorial](:apps/tutorial.html).)

6. You have to use Nuvola Player JavaScript API >= 3.0.

7. You have to [mark translatable strings](:apps/translations.html) in ``integrate.js``.

8. Your repository must contain file `CONTRIBUTING.md` with instructions for contributors.
   You can copy
   [CONTRIBUTING.md template](https://github.com/tiliado/nuvola-app-template/blob/master/CONTRIBUTING.md)
   and adjust it to your needs.

License
======= 

You should use the same license as Nuvola Player does
([BSD 2-Clause "Simplified" or "FreeBSD" license](http://opensource.org/licenses/BSD-2-Clause))
unless you have severe reasons to choose different license. In that case you should stick
to the popular open-source licenses with strong communities:

  * [Apache License 2.0](http://opensource.org/licenses/Apache-2.0)
  * [BSD 3-Clause "New" or "Revised" license](http://opensource.org/licenses/BSD-3-Clause)
  * [BSD 2-Clause "Simplified" or "FreeBSD" license](http://opensource.org/licenses/BSD-2-Clause)
  * [GNU General Public License (GPL)](http://opensource.org/licenses/gpl-license)
  * [GNU Library or "Lesser" General Public License (LGPL)](http://opensource.org/licenses/lgpl-license)
  * [MIT license](http://opensource.org/licenses/MIT)
  * [Mozilla Public License 2.0](http://opensource.org/licenses/MPL-2.0)

Artwork
=======

Nuvola Player expects your integration to provide a set of icons in the `icons` directory. However,
you don't have to care about it as service integration template already contains generic Nuvola
Player source icons and a Makefile target to build the icon set from them. These generic icons
will be later replaced by icons provided by Alexander King. In case you insist on providing your
own icons, the resulting icon set must consist of:

 * `16.png` - 16×16 px PNG icon
 * `22.png` - 22×22 px PNG icon
 * `24.png` - 24×24 px PNG icon
 * `32.png` - 32×32 px PNG icon
 * `48.png` - 48×48 px PNG icon
 * `64.png` - 64×64 px PNG icon
 * `128.png` - 128×128 px PNG icon
 * `256.png` - 256×256 px PNG icon
 * `scalable.svg` - scalable SVG icon with base size 512×512 px

All PNG icons must be build from source SVG icons via a Makefile rule. While the file
`scalable.svg` can be used to build icon sizes 64-256, smaller icons will need their own fine-tuned
source SVG icons: icons 16, 22 and 24 from a SVG image with base size 16 px and icons 32 and 48 from a SVG image
with base size 32 px. See [template](https://github.com/tiliado/nuvola-app-template/tree/master)
for inspiration.

!!! danger "Beware of copyright infringement"

    A common mistake is to take an official logo of a particular streaming service, resize it or crop
    it and then use it as icon for Nuvola Player. This approach has always led to violation of the
    first rule regarding to copyright and license and affected integration scripts were rejected
    until the file was removed.

Git & GitHub Guidelines
=======================

### Commit Messages

Commit messages should follow this template:

```
Short (50 chars or less) summary of changes

More detailed explanatory text, if necessary.  Wrap it to
about 72 characters or so. The blank line separating the
summary from the body is critical (unless you omit the body
entirely); tools like rebase can get confused if you run
the two together.

Further paragraphs come after blank lines. Also don't
forget to link to issues.
    
Issue: tiliado/nuvolaplayer#128
```

* Write **useful commit summary** (the first line. max 50 chars):
    + Use verbs and don't end summary with a dot, e.g. "Add test for AboutDialog" instead of
      "Added test for AboutDialog." or "Adding test for AboutDialog."
    + Be specific, e.g. "Increase version to 2.1" instead of "Update metadata", "Remove extra comma
      to fix JSON parse error" instead "Fix JSON file".
    + You can use shortcuts "w/" = with, "w/o" = without, etc.
* If short summary is not clear enough, add one or a few paragraphs with **description** about what you
  changed and why.
* Add link to a **Github issue**, e.g. `tiliado/nuvolaplayer#128`, if there is any. See 
  [Writing on GitHub](https://help.github.com/articles/writing-on-github/#references) for details.

### Pull Requests

If you would like to **get your code** contributions **merged** to the main repository,
[create a pull request](https://help.github.com/articles/creating-a-pull-request/).
Pull request should follow similar template like commit messages, because a merge commit message
will be based it:

```
Short (50 chars or less) summary of changes

More detailed explanatory text, if necessary.  Wrap it to
about 72 characters or so. The blank line separating the
summary from the body is critical (unless you omit the body
entirely); tools like rebase can get confused if you run
the two together.

Further paragraphs come after blank lines. Also don't
forget to link to issues.
    
- Author: Pull Request Author Name <your@email>
- Reviewed by: FIXME <FIXME>
- Issue: tiliado/nuvolaplayer#128

---

If you have some other notes regarding the pull request,
add a separator "---" and then write anything you want to ;-)
This part won't be included in a commit message.
```

* The same rules as for the commit summary apply to **the title** of a pull requests.
* Always provide **description** of the pull request: what you changed and why. The merge commit
  message will be based on this description.
* Add lines:
   +  `Author: Pull Request Author Name <your@email>` - you will be recorded as the *author* of the
      merge commit (see bellow)
   +  `Reviewed by: FIXME <FIXME>` - the `FIXME` placeholder will be filled by a *reviewer*,
 * Add link to a related issue, if there is any: `Issue: tiliado/nuvolaplayer#128`


### Merge Commits

If you are a **maintainer of a repository**, follow these rules how to accept pull requests and
create merge commits. First of all, check whether the **title** of a pull request and a
**description conforms guidelines** above. If not, notify the author of the pull request (less work
for you) or prepare a well formed commit message on your own (more work for you).

**Message of merge commits** should follow this template:

```
Short (50 chars or less) summary of changes

More detailed explanatory text, if necessary.  Wrap it to
about 72 characters or so. The blank line separating the
summary from the body is critical (unless you omit the body
entirely); tools like rebase can get confused if you run
the two together.

Further paragraphs come after blank lines. Also don't
forget to link to issues.

 - Reviewed by: Your Name <your@email>
 - Reviewed by: Another Reviewer <his@email>
 - Pull Request: fenryxo/test#2
 - Issue: fenryxo/test#3
```

* Link to a pull request `https://github.com/fenryxo/test/pull/2` → ` - Pull request: fenryxo/test#2`
* Link to an issue `https://github.com/fenryxo/test/issues/3` -> `+ - Issue: fenryxo/test#3`

**Don't use GitHub to do a merge.** It's a pure crap:

 -  It creates a commit summary like "Merge pull request #1 from fenryxo/mybranch.". That has
    **zero** information **value**.
 -  It provides only a basic text box to fill in a commit description. No control of line wrapping
    at 75 characters. 

![no_github_merge](https://cloud.githubusercontent.com/assets/853706/8862021/fb68290e-318d-11e5-8e5e-5989d7df0a83.png)

Always **merge** pull requests **via command line**:

 * Add remote repository if necessary:
   `git remote add gh-USER https://github.com/USER/REPO.git; git fetch gh-USER`
 * Switch to the branch of the pull request: `git checkout gh-USER/BRANCH`
 * Review and test changes.
 * Switch to the master branch: `git checkout master` 
 * Use `git merge --no-ff --no-commit gh-USER/BRANCH` instead of a plain `git merge` to merge the
   pull request.
 * Use `git commit --author "Pull Request Author Name <author@email>"` to commit the merge on
   behalf of the pull request author with a very descriptive commit message:
    * Fill in  `Reviewed by: Your Name <Your@email>`
    * Link to a pull request `https://github.com/fenryxo/test/pull/2` → ` - Pull Request: fenryxo/test#2`
    * Link to an issue `https://github.com/fenryxo/test/issues/3` -> `+ - Issue: fenryxo/test#3`
 * *Optionally*, you can squash all commits of the pull request and the merge commit into one final
   commit. However, you should not ask author of the pull request to do rebasing and squashing to
   keep entrance barrier for contributors as low as possible.
 * Finally, ``git push``.
 * *Optionally*, you can remove remote repository: `git remote remove gh-USER/BRANCH`

### Releases

  * Create a Github issue "Make release X.Y" and assing it to @fenryxo when ready for a new release, but don't increase version fields in metadata.
  * Don't hesitate to release often. Packages of service integration script are lightweight
    with a typical build time a few seconds thanks to [fpm](https://github.com/jordansissel/fpm).
  * Users will love you if you release a fix as soon as possible.


Coding Style
============

Service integrations are maintained in separate repositories as more or less independent sub-projects.
Therefore, you can use different coding style that the main Nuvola Player project. However, your
coding style have to be consistent. You can get inspired by coding style of Nuvola Player:

Basics
------

 *  Source lines may be up to 100 characters long.
 *  Variables should be declared at the point where they are first needed rather than at the top of
    a block or function.

Naming
------

  * Prototype objects ("classes") are named in camel case: ``MediaPlayer``.
  * Constants (and values of enumerations) are all uppercase, with underscores between words: ``CONSTANT_NAME``
  * Other variables and method/function names are in camel case with the first letter lower-cased: ``methodName()``, ``myVariable``.
  * Usage of single-letter variables or abbreviations is discouraged except for temporary variables in loops (``i``, ``j``, etc.).

```js

// Prototype name
var ConfigStorage = Nuvola.$prototype(KeyValueStorage, SignalsMixin);

// Enumeration
var PlaybackState = {
    UNKNOWN: 0,
    PAUSED: 1,
    PLAYING: 2,
}

// Constant
var PI_VALUE = "3.14";

var myVariable = 5;
var myFunction = function(){};
```

Braces
------

  * Both opening and closing curly braces of code blocks appear on the new line. The code is more fluffy.
  * The opening curly brace of an object literal appears on the same line as a preceding assignment operator.
  * If body of ``if``, ``else``, ``while`` or ``for`` only one statement, it can be optionally surrounded by braces. However, it should always be on a new line with proper indentation.
  * If one branch of ``if-else`` block is braced, all should be braced.
  * To not put space between function name and opening brace.

```js

var foo = function()
{
    for (var i = 0 ; i < 10 ; ++i)
    {
        ...
    }
}

if (x == 4)
{
    ...
}
else
{
    ...
}

// Preferred
if (x >= 0)
    y = x;
else
    y = -x;

// Also possible
if (x >= 0)
{
    y = x;
}
else
{
    y = -x;
}

try
{
    ...
}
catch (e)
{
    ...
}

var person = {
    name: "Jiří",
    surname: "Janoušek",
}

```
Spaces
------

  * Indentation level is four spaces. Use a clever editor that can treat spaces as tabs, i.e. it
    inserts four spaces when you press TAB.
  * A blank line should be padded to the “natural” indentation level of the surrounding lines. 
  * Don't put spaces between function name and opening brace.
  * Don't put spaces between variable name and opening square brace.
  * Keywords like ``if``, ``for``, ``while`` and ``catch`` are followed by a space and opening bracket.
  * Don't use inner spaces of brackets.
  * Use spaces around binary operators.
  * Don't use spaces around unary and increment/decrement operators (e.g. ``++``, ``--``, ``!``, ``!!``, ``-``). 
  
```js

document.getElementById("foo");

myArray[1];

if (true)
    ...

var c = a + b;
var c = -b;
var c = --b;
var success = !failed;

```

[github]: https://github.com
[JS_STRICT]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions_and_function_scope/Strict_mode
[JS_SEAF]: http://markdalgleish.com/2011/03/self-executing-anonymous-functions/

[TOC]
