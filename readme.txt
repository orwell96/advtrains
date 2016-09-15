
## ADVTRAINS ## realistic trains in Minetest!
by orwell96 and contributors(see below)

Until now are supported:
- tracks and switches, based on angles of 30(!) degrees
- wagons that drive on these rails and collide with nodes in the environment(they need 3x3x3 space)
-> a steam engine
-> a regular green wagon
-> a subway train (NEW!)
- coupling /discoupling of wagons/trains
- trains can travel through unloaded map chunks
- head-up display for train speed and nice controls when sitting in locomotive
- signals and bumpers
- switches and signals controllable by mesecons
Planned features:
- locomotives need coal to drive (and water...)
- more types of trains and rails(electric, diesel, maglevs...)
- better textures
- physics for train collisions (conservation of momentum)
- Automatic train control (ATC) via mesecons (only available on electric/subway trains, maybe allow for more features with digilines)
- an API, because API's are cool.
(I will probably split trains api and actual trains into two mods, to allow for extensions to be enabled individually)

Manual:
- Use the 'Default train track' item to place tracks. In most cases it will adjust rails in the direction you need them.
- use the trackworker tool (doctor who sonic screwdriver) to rotate tracks(right-click) and to change normal rails into switches(left-click)
- to overcome heights you need the ramped rails, place them and you will understand.
- right-click switches to change direction, or power them with mesecons
- place locomotives or wagons by picking the item and placing it on a track.
- right-click a wagon or locomotive to sit onto it.
- inside a locomotive, use W/S to accelerate/decelerate the train. This will fail if the train can't move in the desired direction. Shift stops the train, aux1 (default E) or right-click on wagon will let you off.
- drive two trains together and they will connect by right-clicking that green icon that appears.
- punch the red couple icon between wagons to discouple them


License of code: LGPL 2.1
License of media: CC-BY-NC-SA 3.0

Contributions:

Gravel Texture              : from Minetest Game
Initial rail model/texture  : DS-minetest
Models for signals/bumpers  : mbb
Steam engine / wagon texture: mbb