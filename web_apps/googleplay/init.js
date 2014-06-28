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

(function(Nuvola)
{

var WebApp = Nuvola.$WebApp();

WebApp.onInitAppRunner = function(emitter, values, entries)
{
	Nuvola.WebAppPrototype.onInitAppRunner.call(this, emitter, values, entries);
	
	Nuvola.Actions.addAction("playback", "win", "thumbs-up", "Thumbs up", null, null, null, true);
	Nuvola.Actions.addAction("playback", "win", "thumbs-down", "Thumbs down", null, null, null, true);
	var ratingOptions = [
		// Variant? parameter, string? label, string? mnemo_label, string? icon, string? keybinding
		[0, "Rating: 0 stars", null, null, null, null],
		[1, "Rating: 1 star", null, null, null, null],
		[2, "Rating: 2 stars", null, null, null, null],
		[3, "Rating: 3 stars", null, null, null, null],
		[4, "Rating: 4 stars", null, null, null, null],
		[5, "Rating: 5 stars", null, null, null, null]
	];
	Nuvola.Actions.addRadioAction("playback", "win", "rating", 0, ratingOptions);
}

WebApp.start();

})(this);  // function(Nuvola)
