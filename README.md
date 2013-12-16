Rubikscam
=========

This is an FPGA project for the DE-2 Card with the chip Cyclone II.
It is written for quartus 13.

It implements a hand recognition for the control of embed software, and comes with two game examples:
- A two player pong
- A 3D engine, that should display a Rubik's Cube (the reason the project is named so), that can be controlled with the hands.


TODO
=========
* Fix the SRAM driver that don't seem to be beginning to work (concerning the 3D engine)
* Link the different parts with comprehensive branches
* Improve the 3D engine
	- implement rotations
	- implement color depth
	- implement line and surface rasterization for the drawing of shapes
	- implement depth sorting algorithm (ray tracing) to be able to draw the shapes in the right order
