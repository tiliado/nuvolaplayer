var socket = eio('ws://' + location.host);
socket.on('open', function()
{
    console.log("Socket opened");
    socket.on('message', function(data)
    {
		console.log("Message received: " + data); 
	});
    socket.on('close', function()
    {
		console.log("Connection closed");
	});
	setInterval(function()
	{
		socket.send("Hello! It's " + new Date().toLocaleString() + ".");
	}, 2000);
});
