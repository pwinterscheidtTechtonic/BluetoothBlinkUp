server.log("URL: " + http.agenturl() + "?erase=1");

http.onrequest(function(request, response) {
     if ("query" in request) {
        if ("erase" in request.query) {
            device.send("clear.spiflash", true);
        }
    }

    response.send(200, "OK");
});
