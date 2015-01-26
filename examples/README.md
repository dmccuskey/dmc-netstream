

### dmc-netstream-basic Example ###

Here are the steps:

1. Run data server
1. Run Corona project


**Run server on your computer**

```shell
> cd <dmc-netstream-folder>/examples/dmc-netstream-basic/server
> lua long_poll.lua
```

Once it is started, the server is constantly listening for new connections. It will display the following message when it's ready:

```
Server: listening for connections
```


**Run Corona project**

In the Corona Simulator, open `main.lua` found in `<dmc-netstream-folder>/examples/dmc-netstream-basic/`

The app will connect to the server and get data from it. If you relaunch the simulator, the server will clean up the connection.


