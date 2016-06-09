Since there are no trains mods out there that satisfied my needs, I decided to write my own.
Until now are supported:
- tracks and switches, based on angles of 45 degrees
- wagons that drive on these rails and collide with nodes in the environment(they need 3x3x3 space)
- coupling /discoupling of wagons/trains
- trains can travel through unloaded map chunks
- head-up display for train speed and nice controls when sitting in locomotive
Planned features:
- locomotives need coal to drive (and water...)
- more types of trains and rails(electric, diesel, maglevs...)
- make switches controllable by mesecons
- better textures
- physics for train collisions (conservation of momentum)
- Automatic train control (ATC) via mesecons (only available on electric/subway trains, maybe allow for more features with digilines)
- an API, because API's are cool.
(I will probably split trains api and actual trains into two mods, to allow for extensions to be enabled individually)

At the moment, you can try around with the trains. There are some debug messages that shouldn't disturb you. Note that anything may change in future releases.
- Use the 'track' item to place tracks. In most cases it will adjust rails in the direction you need them.
- use the trackworker tool to rotate tracks(right-click) and to change normal rails into switches(left-click)
- to overcome heights you need the rails with the strange gravel texture in the background, place them and you will understand.
- right-click switches to change direction
- place locomotives or wagons by picking the item and placing it on a track.
- right-click a wagon or locomotive to sit onto it.
- inside a locomotive, use W/S to accelerate/decelerate the train. This will fail if the train can't move in the desired direction. Shift stops the train, aux1 (default E) or right-click on wagon will let you off.
- drive two trains together and they will connect by right-clicking that green icon that appears.
- punch the red couple icon between wagons to discouple them

License of code: LGPL 2.1
License of media: CC-BY-SA 3.0
see attached files.