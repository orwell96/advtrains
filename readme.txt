Hi
Since there are no trains mods out there that satisfied my needs, I decided to write my own.
Until now are supported:
- tracks and switches, based on angles of 45 degrees
- wagons (atm they all look like very simple locomotives in different colors) that drive on these rails and collide with nodes in the environment(they need 3x3x3 space)
- conecting/disconnecting of wagons/trains
Planned features:
- trains will only move if a locomotive is in train
- locomotives need coal to drive (and water...)
- more types of trains and rails(electric, diesel, maglevs...)
- better controls
- cool models for trains and rails
- an API, because API's are cool.
(I will probably split trains api and actual trains into two mods, to allow for extensions to be enabled individually)

At the moment, you can try around with the trains. There are some debug messages that shouldn't disturb you. Note that anything may change in future releases.
- Use the Track(placer) item to place tracks. In most cases it will adjust rails in the direction you need them.
- use the trackworker tool to rotate tracks(right-click) and to change normal rails into switches(left-click)
- to overcome heights you need the rails with the strange gravel texture in the background, place them and you will understand.
- place any of the wagons in different colors by picking the item and placing it on a track.
- right-click a wagon to sit onto it.
- right-click a wagon while holding W / S to accelerate/decelerate the train. This will fail if the train can't move in the desired direction.
- drive two trains together and they will connect automatically.
- right-click a wagon while holding sneak key to split a train at this wagon
- right-click a wagon while holding aux1 to print useful(TM) information to the console

Have fun!