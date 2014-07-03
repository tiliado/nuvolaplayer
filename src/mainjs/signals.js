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

/**
 * @mixin Provides signaling functionality.
 */ 
var SignalsMixin = {};

/**
 * Adds new signal listeners can connect to
 * 
 * @param String name    signal name, should be in CamelCase
 * 
 * ```
 * BookStore.$init = function()
 * {
 *     **
 *      * Emitted when a book is added.
 *      * 
 *      * @param Book book    book that has been added
 *      *\/
 *     this.addSignal("book-added");
 * }
 * ```
 */
SignalsMixin.addSignal = function(name)
{
	if (this.signals == null)
		this.signals = {};
	
	this.signals[name] = [];
}

SignalsMixin.registerSignals = function(signals)
{
	if (this.signals === undefined)
		this.signals = {};
	
	var size = signals.length;
	for (var i = 0; i < size; i++)
	{
		this.signals[signals[i]] = [];
	}
}

/**
 * Connect handler to a signal
 * 
 * The first argument passed to the handler is the emitter object, i.e. object that has emitted the signal,
 * other arguments should be specified at each signal's description.
 * 
 * @param String name                    signal name
 * @param Object object                  object that contains handler method
 * @param optional String handlerName    name of handler method of an object, default name is ``_onSignalName``
 * @throws Error if signal doesn't exist
 * 
 * ```
 * Logger._onBookAdded = function(emitter, book)
 * {
 *     console.log("New book: " + book.title + ".");
 * }
 * 
 * Logger.$init = function()
 * {
 *     bookStore.connect("book-added", this, "_onBookAdded");
 * }
 * ```
 */
SignalsMixin.connect = function(name, object, handlerName)
{
	handlerName = handlerName || ("_on" + name);
	var handlers = this.signals[name];
	if (handlers === undefined)
		throw new Error("Unknown signal '" + name + "'.");
	handlers.push([object, handlerName]);
}

/**
 * Disconnect handler from a signal
 * 
 * @param String name                    signal name
 * @param Object object                  object that contains handler method
 * @param optional String handlerName    name of handler method of an object, default name is ``_onSignalName``
 * @throws Error if signal doesn't exist
 */
SignalsMixin.disconnect = function(name, object, handlerName)
{
	handlerName = handlerName || ("_on" + name);
	var handlers = this.signals[name];
	if (handlers === undefined)
		throw new Error("Unknown signal '" + name + "'.");
	var size = handlers.length;
	for (var i = 0; i < size; i++)
	{
		var handler = handlers[i];
		if (handler[0] === object && handler[1] === handlerName)
		{
			handlers.splice(i, 1);
			break;
		}
	}
},

/**
 * Emit a signal
 * 
 * @param String name               signal name
 * @param Variant varArgsList...    arguments to pass to signal handlers
 * @throws Error if signal doesn't exist
 * 
 * ```
 * BookStore.addBook = function(book)
 * {
 *     this.books.push(book);
 *     this.emit("book-added", book)
 * }
 * ```
 */
SignalsMixin.emit = function(name, varArgsList)
{
	var handlers = this.signals[name];
	if (handlers === undefined)
		throw new Error("Unknown signal '" + name + "'.");
	var size = handlers.length;
	var args = [this];
	for (var i = 1; i < arguments.length; i++)
		args.push(arguments[i]);
	
	for (var i = 0; i < size; i++)
	{
		var handler = handlers[i];
		var object = handler[0];
		object[handler[1]].apply(object, args);
	}
}

Nuvola.SignalsMixin = SignalsMixin;
