/*
 * Copyright 2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

require("logging");

// Make sure some useful functionality does exist even in bare global object

var argsToString = function(args)
{
    var strings = [];
    for (var i = 0; i < args.length; i++)
        strings.push("" + args[i])
    return strings.join(" ");
}

if (!global.console)
    global.console = {};

if (!console.log)
{
    console.log = function()
    {
        Nuvola.warn("console.log() is not available, using Nuvola.log as a fallback. The following message might be incomplete.");
        Nuvola.log("{1}", argsToString(arguments));
    }
}

if (!console.debug)
{
    console.debug = function()
    {
        Nuvola.warn("console.debug() is not available, using Nuvola.log as a fallback. The following message might be incomplete.");
        Nuvola.log("{1}", argsToString(arguments));
    }
}

if (!global.alert)
{
    global.alert = function()
    {
        Nuvola.warn("alert() is not available, using Nuvola.log as a fallback. The following message might be incomplete.");
        Nuvola.log("{1}", argsToString(arguments));
    }
}
