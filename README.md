LitMod is a combined geophysical-petrological 3D forward/inversion modelling tool developed to study the thermal, compositional, density and seismological structure of lithosphere and sublithosphere domains by combining data from petrology, mineral physics and geophysical observables within a self-consistent framework.

-----------------------
Installation
-----------------------

By default, LitMod can be compiled in serial mode without any extra features. To do this, modify the very first several parameters on the makefile in order to specify paths to compilers and set the variables appropriately.

To get a benefit of HDF5 output, you need a serial HDF5 library (even for parallel LitMod version). Install it and set HDF5WRITE to yes and HDF5PATH to the location of the library.

-----------------------
Running
-----------------------

Type "man ./litmod" to see information on the running options available right now.

-----------------------
Copyright
-----------------------

(c) J.C. Afonso et al., 2013-2018 under GNU GPL terms.
