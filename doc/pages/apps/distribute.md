Title: Distribute Service Integration

After going through [Service Integrations Tutorial]({filename}tutorial.md)
or [Service Integrations Guide]({filename}guide.md), you have a brand new functional
service integration on your disk. This guide describe various ways how to distribute
your work for other users to use it.

Copyright and license
=====================

  * Make sure your ``integrate.js`` contain proper copyright information 
    "Copyright 2014 Your name <your e-mail>".
  * The test service used in tutorial and guide contains 2-Clause BSD license. If you have severe
    reasons to choose a different license, update license text in both ``integrate.js`` and
    ``LICENSE`` files.

!!! info "If you use Git, commit changes"
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git add integrate.js LICENSE
        git commit -m "Update copyright information and license"

Create Makefile
===============

Makefile is a recipe how to build and install your service integration. The test service comes
with sample ``Makefile``. All you need to do is to change service
integration id ``APP_ID``. Run ``make help`` to see available actions.

!!! info "Service icon"
    You can replace generic Nuvola Player icon ``src/icon.svg`` with an actual icon of the service. However, beware of
    any copyright violations, you cannot just download the offical icon and modify it. Better option is to let
    Alexander King, the author of other service icons, to create a new icon for your service.

Let's try out your Makefile. You will need application ``rsvg-convert`` to proceed.

    :::sh
    cd ~/projects/nuvola-player/test-integration
    make install
    nuvolaplayer3 -D

If everything goes well, you should have your service integration installed to
``~/.local/share/nuvolaplayer3/web_apps`` and Nuvola Player can find it.

!!! info "If you use Git, commit changes"
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git add Makefile
        git commit -m "Add Makefile"

Add README.md
=============

``README.md`` is a text file in [Markdown syntax](http://daringfireball.net/projects/markdown/syntax)
that should contain basic information about your service integration:

  * Description of your work.
  * Support details.
  * Installation instructions.
  * Copyright and license information

```text
Google Play Nuvola Player App
=============================

Integration of Google Play Music into your linux desktop via
[Nuvola Player](https://github.com/tiliado/nuvolaplayer).
 
Support
-------

Report bugs and issues at <https://github.com/tiliado/nuvola-app-google-play/issues>.

Installation
------------

  * Execute ``make help`` to get help.
  * Execute ``make build`` to build graphics.
  * Execute ``make install`` to install files to user's local directory.
  * Don't execute ``make uninstall``. Why would you do that?

Copyright
---------

  - Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
  - License: [2-Clause BSD-license](./LICENSE)
```

!!! info "If you use Git, commit changes"
        :::sh
        cd ~/projects/nuvola-player/test-integration
        git add README.md
        git commit -m "Add README.md"

Publish your work
=================

First of all, remove any unnecessary files like `Makefile.basic`, `Makefile.full`,
`home.html`, `metadata.old.json` and `integrate.old.js`.

Git way (preferred)
-------------------

If you use Git, the easiest way how to publish your work is to push it to [GitHub](https://github.com),
[bitbucket](https://bitbucket.org) or similar code hosting platform.

 1. Create an empty remote repository. See [GitHub For Beginners: Don't Get Scared, Get Started][A1] for
    help.

 2. Push content of your local repository to the remote repository.
    
        :::sh
        git remote add origin git@github.com:fenryxo/nuvola-app-test.git
        git push -u origin master

[A1]: http://readwrite.com/2013/09/30/understanding-github-a-journey-for-beginners-part-1
[A2]: http://readwrite.com/2013/10/02/github-for-beginners-part-2

Tar archives
------------

You can create a tar archive with your work and publish it anywhere on the internet.

    :::sh
    cd ~/projects/nuvola-player
    tar -czvf nuvola-app-test-integration.tar.gz \
    --exclude-vcs --exclude='*~' test-integration
    
Push your work upstream
=======================

If you would like to have your service integration **maintained as a part of the Nuvola Player project
and distributed in the Nuvola Player repository**, follow the instructions bellow.

Git way (preferred)
-------------------

 1. Push your repository to GitHub. Repository name is ``fenryxo/nuvola-app-test`` for this example.
 2. Create new issue in your repository titled "Push to Nuvola Player project"
 3. Create new topic at [Nuvola Player Development forum](https://groups.google.com/d/forum/nuvola-player-devel)
    with subject "Code review of You Service Name integration" and post a link the the issue created
    above.
 4. Don't hesitate to ask any question.   
 5. Wait for a review ;-)

Tar archives (slow)
-------------------

 1. Create tar archive (see previous section).
 2. Create new topic at [Nuvola Player Development forum](https://groups.google.com/d/forum/nuvola-player-devel)
    with subject "Code review of You Service Name integration" and attach the tar archive.
 3. Don't hesitate to ask any question.   
 4. Wait for a review, it may take a while.

[TOC]
