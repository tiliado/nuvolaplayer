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

require("utils");

/**
 * Log message to terminal
 * 
 * Note: This function doesn't print to JavaScript console of WebKit Web Inspector, but to real console/terminal.
 * 
 * @param String template    template string, see @link{Nuvola.format} for details
 * @param Variant data...    other arguments will be used as data for replacement
 */
Nuvola.log = function(template)
{
    var args = Array.prototype.slice.call(arguments);
    var message = Nuvola.format.apply(Nuvola, args);
    Nuvola._log(message);
}

/**
 * Log warning to terminal
 * 
 * Note: This function doesn't print to JavaScript console of WebKit Web Inspector, but to real console/terminal.
 * 
 * @param String template    template string, see @link{Nuvola.format} for details
 * @param Variant data...    other arguments will be used as data for replacement
 */
Nuvola.warn = function(template)
{
    var args = Array.prototype.slice.call(arguments);
    var message = Nuvola.format.apply(Nuvola, args);
    Nuvola._warn(message);
}

/**
 * Log exception to terminal
 * 
 * @since Nuvola 4.8
 * @param Exception e    The exception to log.
 */
Nuvola.logException = function(e) {
   console.log(e);
}
