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
   [README.md template](https://raw.githubusercontent.com/tiliado/nuvolasdk/master/nuvolasdk/data/template/README.md)
   for inspiration. In addition, the `metadata.json` file must contain a list of licenses in the
   `license` field, e.g. `"license": "2-Clause BSD, CC-BY-3.0"`.

 2. The field ``maintainer_link`` of ``metadata.json`` must contain URL of your
   [Github profile][github]. (You will be subscribed to bug reports related to your service
   integrations).

 3. You must provide contact e-mail in `README.md`, e.g. inside Copyright section.

 4. You must use [Standard JS coding style](https://standardjs.com/) for ``integrate.json``.

 5. You must use [strict JavaScript mode][JS_STRICT] and [self-executing anonymous function][JS_SEAF].
    (See [tutorial](:apps/tutorial.html).)

 6. You have to use [NuvolaKit JavaScript API](apiref>x-changelog) >= 4.11.

 7. You have to [mark translatable strings](:apps/translations.html) in ``integrate.js``.

 8. Your repository must contain file `CONTRIBUTING.md` with instructions for contributors.
    You can copy
    [CONTRIBUTING.md template](https://raw.githubusercontent.com/tiliado/nuvolasdk/master/nuvolasdk/data/template/CONTRIBUTING.md)
    and adjust it to your needs.

 9. You have to create a `CHANGELOG.md` file with a limited subset of Markdown syntax (headings, links, bullet points).
    [Example with an unreleased initial release](https://raw.githubusercontent.com/tiliado/nuvolasdk/master/nuvolasdk/data/template/CHANGELOG.md).
    [Example with a few released releases](https://raw.githubusercontent.com/tiliado/nuvola-app-siriusxm/0d8432f18f6164b19b58b5b68b1ca4f3d260179d/CHANGELOG.md).
10. You need to provide a [web view snapshot](:apps/screenshots.html).

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

You must specify the license in `README.md` and in the `licence` field of `metadata.json`.

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

### Releases

  * **Never increase version number in `metadata.json` in regular commits** nor in pull requests,
    but only in special release commits.
  * **Release commits** have a commit message `Release X.Y`, are tagged `X.Y` (not `vX.Y` nor `release-X.Y`, just `X.Y`)
    and must also update changelog (`X.Y.Z - unreleased` → `X.Y.Z - ${release date}`, e.g. `1.2 - September 28, 2016`,
    [example](https://raw.githubusercontent.com/tiliado/nuvola-app-siriusxm/0d8432f18f6164b19b58b5b68b1ca4f3d260179d/CHANGELOG.md)).
    However, **you don't have to make release commits at all**, just jump to the next step.
  * Create a Github issue "Release X.Y" and assing it to @fenryxo when ready for a new release.
    He will decide whether the release should be made or a few other changes should be made before next
    release. He will also create a tagged release commit and build new packages for the Nuvola Player
    Package Repository.
  * Don't hesitate to release often. It takes only a few minutes to rebuild packages with a new release.
    Users will love you if you release a fix as soon as possible.

### Changelog

  * Every user-facing change or an important internal change must be also mentioned in the CHANGELOG.md file. You should
    update the changelog in the same commit that introduces the change. The changelog will be eventually parsed by the
    flatpak builder and displayed in GNOME Software and similar package managers.
  * The changelog should be written with a limited subset of Markdown syntax
    ([example](https://raw.githubusercontent.com/tiliado/nuvola-app-google-play-music/master/CHANGELOG.md)).
  * The first heading is `${app name} Changelog`.
  * Then there is one subheading for each release followed by a bullet-point list of changes.
  * If there are unreleased changes, the very first subheading contains version number of the next release and
    ends with `- unreleased`
    ([example](https://raw.githubusercontent.com/tiliado/nuvola-app-google-play-music/09a31c87133e036671441fbad5557c2ef6c74e45/CHANGELOG.md)).
  * **Don't mix unrelated changes in a single commit.** As a rule of thumb, if your commit adds more then a single entry
    to the CHANGELOG.md file, you should split it into more commits.

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

* Don't forget to update the CHANGELOG.md file.
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


[github]: https://github.com
[JS_STRICT]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions_and_function_scope/Strict_mode
[JS_SEAF]: http://markdalgleish.com/2011/03/self-executing-anonymous-functions/

[TOC]
