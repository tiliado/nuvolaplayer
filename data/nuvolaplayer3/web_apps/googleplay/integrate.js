/*
 * Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
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

var player = Nuvola.Player;

/**
 * Creates new integration object
 */
var Integration = function()
{
	Nuvola.Actions.connect("action-activated", this, "onActionActivated");
};

/**
 * Updates current playback state
 */
Integration.prototype.update = function()
{
	try
	{
		player.artwork = document.getElementById('playingAlbumArt').src;
	}
	catch(e)
	{
		player.artwork = null;
	}
	
	try
	{
		var elm = document.getElementById('playerSongTitle').firstChild;
		player.song = elm.innerText || elm.textContent;
	}
	catch(e)
	{
		player.song = null;
	}
	
	try
	{
		var elm = document.getElementById('player-artist').firstChild;
		player.artist = elm.innerText || elm.textContent;
	}
	catch (e)
	{
		player.artist = null;
	}
	
	try
	{
		var elm = artistDiv.nextSibling.nextSibling.firstChild;
		player.album = elm.innerText || elm.textContent;
	}
	catch (e)
	{
		player.album = null;
	}
	
	try
	{
		var buttons = document.querySelector("#player .player-middle");
		var pp = buttons.childNodes[2];
		if (pp.disabled === true)
			player.state = player.STATE_UNKNOWN;
		else if (pp.className == "flat-button playing")
			player.state = player.STATE_PLAYING;
		else
			player.state = player.STATE_PAUSED;
		
		if (player.state !== player.STATE_UNKNOWN)
		{
			player.prevSong = buttons.childNodes[1].disabled === false;
			player.nextSong = buttons.childNodes[3].disabled === false;
		}
		else
		{
			player.prevSong = player.nextSong = false;
		}
		
	}
	catch (e)
	{
		player.prevSong = player.nextSong = false;
	}
	
	player.update();
	setTimeout(this.update.bind(this), 500);
}

/**
 * Command handler
 * @param cmd command to execute
 */
Integration.prototype.onActionActivated = function(object, name)
{
	var buttons = document.querySelector("#player .player-middle");
	if (buttons)
	{
		var prevSong = buttons.childNodes[1];
		var nextSong = buttons.childNodes[3];
	}
	else
	{
		var prevSong = null;
		var nextSong = null;
	}
	
	switch (name)
	{
	case player.ACTION_TOGGLE_PLAY:
		SJBpost("playPause");
		break;
	case player.ACTION_PLAY:
		if (player.state != player.STATE_PLAYING)
			SJBpost("playPause");
		break;
	
	case player.ACTION_PAUSE:
	case player.ACTION_STOP:
		if (player.state == player.STATE_PLAYING)
			SJBpost("playPause");
		break;
	case player.ACTION_PREV_SONG:
		Nuvola.clickOnElement(prevSong);
		break;
	case player.ACTION_NEXT_SONG:
		Nuvola.clickOnElement(nextSong);
		break;
	}
}

/* Store reference */ 
Nuvola.integration = new Integration();
Nuvola.integration.update();

})(this);  // function(Nuvola)
