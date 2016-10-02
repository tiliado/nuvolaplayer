var Nuvolaio = {};

// Todo: Clean up outgoing request after a timeout => timeout error

Nuvolaio.MessageType = 
{
	REQUEST: 0, RESPONSE: 1, SUBSCRIBE: 2, NOTIFICATION: 3
};

Nuvolaio.serializeMessage = function(type, id, method, data)
{
	var data_size = 0;
	var data_str = "";
	if (data !== null && data !== undefined)
	{
		data_str = JSON.stringify(data);
		data_size = data_str.length;
	}
	return "" + type + "" + id + ":" + method.length + ":" + method + data_size + ":" + data_str;
}

Nuvolaio.deserializeMessage = function(message)
{
	var result = {};
	result.type = parseInt(message.substring(0, 1));
	if (result.type === NaN || result.type < Nuvolaio.MessageType.REQUEST || result.type > Nuvolaio.MessageType.NOTIFICATION)
		throw new Error("Invalid message type: " + result.type);
	
	var msgSize = message.length;
	var intStr = "";
	var i;
	for (i = 1; i < msgSize; i++)
	{
		if (message[i] != ':')
		{
			intStr += message[i];
		}
		else
		{
			result.id = parseInt(intStr);
			if (result.id === NaN || result.id < 0)
				throw new Error("Invalid message id: " + result.id);
			i++;
			break;
		}
	}
	
	intStr = "";
	for (; i < msgSize; i++)
	{
		if (message[i] != ':')
		{
			intStr += message[i];
		}
		else
		{
			var size = parseInt(intStr);
			if (size === NaN || size < 0)
				throw new Error("Invalid message method size: " + size);
			i++;
			result.method = message.substr(i, size);
			i += size;
			break;
		}
	}
	
	intStr = "";
	for (; i < msgSize; i++)
	{
		if (message[i] != ':')
		{
			intStr += message[i];
		}
		else
		{
			var size = parseInt(intStr);
			if (size === NaN || size < 0)
				throw new Error("Invalid message data size: " + size);
			i++;
			if (size == 0)
				result.data = null;
			else
				result.data = JSON.parse(message.substr(i, size)); // throws SyntaxError
			break;
		}
	}
	return result;
}

Nuvolaio.Channel = function(socket)
{
	this.socket = socket;
	this.lastMessageId = 0;
	this.outgoingRequests = {};
	this.subscribers = {};
	socket.on('message', this._onDataReceived.bind(this));
}

Nuvolaio.Channel.prototype._getNextMessageId = function()
{
	var id = this.lastMessageId;
	do
	{
		if (id === 10000)
			id = 1;
		else
			id++;
	}
	while (this.outgoingRequests.hasOwnProperty(id));
	this.outgoingRequests[id] = null;
	this.lastMessageId = id;
	return id;
}

Nuvolaio.Channel.prototype.send = function(name, data, callback)
{
	this._write(Nuvolaio.MessageType.REQUEST, name, data, callback);
}

Nuvolaio.Channel.prototype.subscribe = function(name, callback)
{
	this._write(Nuvolaio.MessageType.SUBSCRIBE, name, {subscribe: true}, callback);
}

Nuvolaio.Channel.prototype.unsubscribe = function(name, callback)
{
	delete this.subscribers[name];
	this._write(Nuvolaio.MessageType.SUBSCRIBE, name, {subscribe: false}, callback);
}

Nuvolaio.Channel.prototype.unsubscribePrefix = function(prefix, callback)
{
	for (var name in this.subscribers)
		if (this.subscribers.hasOwnProperty(name) && name.indexOf(prefix) === 0)
			this.unsubscribe(name, null);
}

Nuvolaio.Channel.prototype.on = function(name, callback)
{
	var callbacks = this.subscribers[name];
	if (!callbacks)
	{
		callbacks = [];
		this.subscribers[name] = callbacks;
		this.subscribe(name, null);
	}
	callbacks.push(callback);
}

Nuvolaio.Channel.prototype._write = function(msg_type, name, data, callback)
{
	var id = this._getNextMessageId();
	var msg = Nuvolaio.serializeMessage(msg_type, id, name, data === undefined ? null : data);
	this.outgoingRequests[id] = {
		id: id,
		type: msg_type,
		callback: callback
	};
	this.socket.send(msg);
}

Nuvolaio.Channel.prototype._onDataReceived = function(data)
{
	var msg;
	try
	{
		msg = Nuvolaio.deserializeMessage(data);
	}
	catch (e)
	{
		console.log("Message parse error: " + e);
		return;
	}
	switch (msg.type)
	{
	case Nuvolaio.MessageType.REQUEST:
		console.log("Request received");
		break;
	case Nuvolaio.MessageType.RESPONSE:
		this._handleResponse(msg);
		break;
	case Nuvolaio.MessageType.SUBSCRIBE:
		console.log("Subscribe received");
		break;
	case Nuvolaio.MessageType.NOTIFICATION:
		this._handleNotification(msg);
		break;
	}
}

Nuvolaio.Channel.prototype._handleResponse = function(msg)
{
	var request = this.outgoingRequests[msg.id];
	if (!request)
	{
		console.log("Unexpected response id: " + msg.id);
		return;
	}
	delete this.outgoingRequests[msg.id];
	var result = new Nuvolaio.Channel.Result(msg.method, msg.data);
	if (request.callback)
	{
		request.callback(result);
	}
	else
	{
		try
		{
			result.finish();
		}
		catch (e)
		{
			console.log("No callback for request resulted in error: " + JSON.stringify(msg.data));
		}
	}
}

Nuvolaio.Channel.prototype._handleNotification = function(msg)
{
	var callbacks = this.subscribers[msg.method];
	if (callbacks)
		for (var i = 0; i < callbacks.length; i++)
			callbacks[i](msg.method, msg.data);
}

Nuvolaio.Channel.Result = function(status, data)
{
	this.status = status;
	this.data = data;
}

Nuvolaio.Channel.Result.prototype.finish = function()
{
	if (this.status === "OK")
		return this.data;
	throw new Error(JSON.stringify(this.data));
}

