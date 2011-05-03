### Autonomous Driving

In order to run, you will need Java, which is installed on most
systems. The next requirement is jruby, which can be obtained from the
jruby website at jruby.org. With both in hand, you should be ready to
go.

To start the server with the default map, run the following command:
   
    $ jruby bin/driving

This should start up a graphical view of the map but without any
agents for the moment. Let's fix that. In another terminal, run:

    $ jruby bin/driving --agent DynamicalAgent

That will create a dynamical agent in the world with a random starting
point and destination. It will immediately try to get to its
destination while staying in its lane. You can also try starting an
AStarAgent and a HybridAgent.

There are many other options, which can be seen with

    $ jruby bin/driving --help


Inside the simulation the following actions can be performed:

    SPACE: follow an agent as it moves through the world
    Left/Right: switch which agent is being followed
    d: if you are currently following an agent, the agent is picked up
       and can be placed anywhere on the map with a double click;
       another double click will place the target
    p: pauses and un-pauses the simulation
  
