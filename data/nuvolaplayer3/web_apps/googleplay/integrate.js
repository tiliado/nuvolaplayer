/*
 * Copyright 2011-2014 Jiří Janoušek <janousek.jiri@gmail.com>
 * Copyright 2014 Martin Pöhlmann <martin.deimos@gmx.de>
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
var ACTION_THUMBS_UP = "thumbs-up";
var ACTION_THUMBS_DOWN = "thumbs-down";
var ACTION_RATING = "rating";
var STARS_ACTIONS = ["rating::0", "rating::1", "rating::2", "rating::3", "rating::4", "rating::5"]
var THUMBS_ACTIONS = ["thumbs-up", "thumbs-down"];

/**
 * Creates new integration object
 */
var Integration = function()
{
	Nuvola.Actions.connect("action-activated", this, "onActionActivated");
	this.thumbsUp = undefined;
	this.thumbsDown = undefined;
	this.starRating = undefined;
	this.starRatingEnabled = undefined;
	this.thumbRatingEnabled = undefined;
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
	
	// null = disabled; true/false toggled on/off
	var thumbsUp, thumbsDown;
	try
	{
		var thumbs = this.getThumbs();
		if (thumbs[0].style.visibility == "hidden")
		{
			thumbsUp = thumbsDown = null;
		}
		else
		{
			this.toggleThumbRating(true);
			thumbsUp = thumbs[1].className == "selected";
			thumbsDown = thumbs[2].className == "selected";
		}
	}
	catch (e)
	{
		thumbsUp = thumbsDown = null;
	}
	
	// null = disabled
	var starRating;
	try
	{
		var stars = this.getStars();
		if (stars.style.visibility == "hidden")
		{
			starRating = null;
		}
		else
		{
			this.toggleStarRating(true);
			starRating = stars.childNodes[0].getAttribute("data-rating") * 1;
		}
	}
	catch (e)
	{
		starRating = null;
	}
	
	player.update();
	
	if (this.thumbsUp !== thumbsUp)
	{
		this.thumbsUp = thumbsUp;
		Nuvola.Actions.setEnabled(ACTION_THUMBS_UP, thumbsUp !== null);
		Nuvola.Actions.setState(ACTION_THUMBS_UP, thumbsUp === true);
	}
	
	if (this.thumbsDown !== thumbsDown)
	{
		this.thumbsDown = thumbsDown;
		Nuvola.Actions.setEnabled(ACTION_THUMBS_DOWN, thumbsDown !== null);
		Nuvola.Actions.setState(ACTION_THUMBS_DOWN, thumbsDown === true);
	}
	
	if (this.starRating !== starRating)
	{
		this.starRating = starRating;
		Nuvola.Actions.setEnabled(ACTION_RATING, starRating !== null);
		Nuvola.Actions.setState(ACTION_RATING, starRating);
	}
	
	setTimeout(this.update.bind(this), 500);
}

Integration.prototype.onActionActivated = function(object, name, param)
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
	case ACTION_THUMBS_UP:
		Nuvola.clickOnElement(this.getThumbs()[1]);
		break;
	case ACTION_THUMBS_DOWN:
		Nuvola.clickOnElement(this.getThumbs()[2]);
		break;
	case ACTION_RATING:
		var stars = this.getStars().childNodes;
		var i = stars.length;
		while (i--)
		{
			var star = stars[i];
			if (star.getAttribute("data-rating") === ("" + param))
			{
				Nuvola.clickOnElement(star);
				break;
			}
		}
		break;
	}
}

Integration.prototype.addNavigationButtons = function()
{
	/* Loading in progress? */
	var loading = document.getElementById("loading-progress");
	if (loading && loading.style.display != "none")
	{
		setTimeout(this.addNavigationButtons.bind(this), 250);
		return;
	}
	
	var queryBar = document.getElementById("gbq2");
	if (!queryBar)
	{
		console.log("Could not find the query bar.");
		return;
	}
	
	var queryBarFirstChild = queryBar.firstChild;
	
	var navigateBack = Nuvola.makeElement("button", null, "<");
	navigateBack.className = "button small vertical-align";
	navigateBack.style.float = "left";
	navigateBack.style.marginRight = "0px";
	navigateBack.style.borderTopRightRadius = "2px";
	navigateBack.style.borderBottomRightRadius = "2px";
	queryBar.insertBefore(navigateBack, queryBarFirstChild);
	
	var navigateForward = Nuvola.makeElement("button", null, ">");
	navigateForward.className = "button small vertical-align";
	navigateForward.style.float = "left";
	navigateForward.style.marginRight = "15px";
	navigateForward.style.borderLeft = "none";
	navigateForward.style.borderTopLeftRadius = "2px";
	navigateForward.style.borderLeftRightRadius = "2px";
	queryBar.insertBefore(navigateForward, queryBarFirstChild);
	
	Nuvola.Actions.attachButton(Nuvola.Browser.ACTION_GO_BACK, navigateBack);
	Nuvola.Actions.attachButton(Nuvola.Browser.ACTION_GO_FORWARD, navigateForward);
}

Integration.prototype.getThumbs = function()
{
	var elm = document.querySelector("#player-right-wrapper .thumbs.rating-container");
	return [elm, elm.childNodes[0], elm.childNodes[1]];
}

Integration.prototype.getStars = function()
{
	return document.querySelector("#player-right-wrapper .stars.rating-container");
}

Integration.prototype.toggleStarRating = function(enabled)
{
	if (enabled && this.starRatingEnabled !== true)
	{
		Nuvola.Player.addExtraActions(STARS_ACTIONS);
		this.starRatingEnabled = true;
	}
}

Integration.prototype.toggleThumbRating = function(enabled)
{
	if (enabled && this.thumbRatingEnabled !== true)
	{
		Nuvola.Player.addExtraActions(THUMBS_ACTIONS);
		this.thumbRatingEnabled = true;
	}
}

Nuvola.Player.init();


/* Store reference */ 
Nuvola.integration = new Integration();
setTimeout(Nuvola.integration.addNavigationButtons.bind(Nuvola.integration), 1000);
Nuvola.integration.update();

})(this);  // function(Nuvola)
