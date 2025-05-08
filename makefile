###### Makefile for compiling and running the LITMOD3D_4inv parallel or serial ######

# set variables here to allow LitMod to look for system compilers.
# you might need to specify paths explicitly in the code below
# NB: these variables affect further compilation, so they must be set appropriately

# Compiler Vendor, options are: intel,gcc,gcc8,gcc9
COMPILERVENDOR=gcc9

# Parallel or serial LitMod: none,mpi,both
PARALLEL=mpi

# Write outputs, requiring additional libs?
HDF5WRITE=yes
TILEDBWRITE=yes
PNGWRITE=no

# Here you need to specify paths to the required compiler
FC :=mpifort
CC :=mpicc
# Here you may set the actual path to HDF5 serial(!) library (if you have one)
HDF5PATH :=/opt/hdf5s/
TILEDBPATH :=/opt/tiledb

# Use mpiP library for MPI profiling
USEMPIP=no
ifeq ($(USEMPIP),yes)
   MPIP=-L/opt/mpip/lib -lmpiP -lm -lunwind
else
   MPIP=
endif

#------------------------------------------------------
# Generally, you should not need to tune anything below
#------------------------------------------------------

#initialize variables
LIBRARIES =
LDHDF5 =
LDTDB =
LTO =

# computational options:
# CovMat update: -DHAARIO2001, -DPYMCMC, (NONE) for direct computation ; -DPYMCMC is not safe
# PerpleX computations: -DNEWPERPLEX for Perple_X 6.9.1 or none for Perple_X 07
# RF code: -DTHEO for the PRF only theo code (otherwise Kennet's solver is used)
# To produce 2 km grids (txt and HDF5 files), use -DHDF52KM
# To use Cartesian geometry in gravity subroutine instead of the spherical one -DGRAVCART
# To smooth the gravity gradients before computing misfit (default), use -DSMOOTHGRADGRAV 
# To smooth the sublithospheric temperatures before generating a proposal, use -DSMOOTHTEMP
# To smooth the mantle compositions before generating a proposal, use -DSMOOTHCOMP
# To smooth the mantle boundaries (MLD,LAB) before generating a proposal, use -DSMOOTHLAB
# To output Volumetric fractions of mantle phases instead of Weight fractions, use -DVOLPCPHASE
COMPOPT:=-DHDF52KM -DSMOOTHGRADGRAV

ifeq ($(COMPILERVENDOR),intel)
   # ifort flags
   # -O2 level is required because of Intel Fortran 2018 vectorization bug. Can be replaced with a new Intel Fortran
   OPTIMIZATION  = -O2
   DEBUG         = -traceback -DD -debug -check bounds -check format -check uninit -DCHECKS
   PRECISION     = -autodouble -fp-model=precise
#-fltconsistency
   ifeq ($(HDF5WRITE),yes)
      LIBRARIES += -DHDF5WRT -lhdf5_fortran -L$(HDF5PATH)/lib/ -I$(HDF5PATH)/include/
      LDHDF5    += -lhdf5_fortran -L$(HDF5PATH)/lib/ -Wl,-rpath=$(HDF5PATH)/lib/
   endif
   ifeq ($(TILEDBWRITE),yes)
      LIBRARIES += -DTDBWRT -L$(TILEDBPATH)/lib/ -I$(TILEDBPATH)/include
      LDTLDB    += -L$(TILEDBPATH)/lib64/ -Wl,-rpath=$(TILEDBPATH)/lib64 -ldl -ltiledb
   endif
   ifeq ($(PNGWRITE),yes)
      LIBRARIES += -DPNGWRT -lpng
      LDPNG     += -lpng
   endif
   FPEFLAGS      =
   GENERAL       = -fpp -no-wrap-margin -heap-arrays -mcmodel=medium -shared-intel -DIFORT
   MANDATORY_F90 = -132 -warn all
   MANDATORY_F77 = -132 -warn none
   CC_FLAGS      = $(OPTIMIZATION) -traceback -DD -debug $(LIBRARIES) -Wall -heap-arrays -mcmodel=medium -shared-intel
else ifeq ($(findstring gcc,$(COMPILERVENDOR)),gcc)
   # GCC Flags:
   OPTIMIZATION  = -O3
#   LTO  = $(OPTIMIZATION) -flto -fno-strict-aliasing
   DEBUG         = -fbounds-check -fbacktrace -pedantic -g -DCHECKS
   FPEFLAGS      = -ffpe-summary=none
   PRECISION     = -fdefault-double-8 -fdefault-real-8
   ifeq ($(HDF5WRITE),yes)
      LIBRARIES += -DHDF5WRT -lhdf5_fortran -L$(HDF5PATH)/lib/ -I$(HDF5PATH)/include/
      LDHDF5    += -lhdf5_fortran -L$(HDF5PATH)/lib/ -Wl,-rpath=$(HDF5PATH)/lib/
   endif
   ifeq ($(TILEDBWRITE),yes)
      LIBRARIES += -DTDBWRT -L$(TILEDBPATH)/lib/ -I$(TILEDBPATH)/include
      LDTLDB    += -L$(TILEDBPATH)/lib/ -Wl,-rpath=$(TILEDBPATH)/lib -ltiledb -ldl
   endif
   ifeq ($(PNGWRITE),yes)
      LIBRARIES += -DPNGWRT -lpng
      LDPNG     += -lpng
   endif
   GENERAL       = -cpp -fPIC
   MANDATORY_F90 = -Wall -Wextra -ffree-line-length-0
   ifeq ($(COMPILERVENDOR),gcc8)
      MANDATORY_F90 += -Wno-do-subscript
   endif
   ifeq ($(COMPILERVENDOR),gcc9)
      MANDATORY_F90 += -Wno-do-subscript -Wno-function-elimination
   endif
   MANDATORY_F77 = -w -ffixed-line-length-132
   CC_FLAGS      = $(OPTIMIZATION) -fbounds-check -pedantic -g $(GENERAL) $(LIBRARIES) -Wall -Wextra
else
$(error Bad compiler vendor. Check the makefile comments)
endif

# add -DMPI to compile with MPI, -DOPENMP to compile with OpenMP
# NB: $(PAROMP) must be used only with files requiring OpenMP, used by OpenMP, or calling OpenMP
ifeq ($(PARALLEL),none)
   # NONE
   PARMPI =
   PAROMP =
else ifeq ($(PARALLEL),mpi)
   # MPI only
   PARMPI = -DMPI
   PAROMP =
   ifeq ($(findstring gcc,$(COMPILERVENDOR)),gcc)
      PARMPI  += -lmpi
   endif
else ifeq ($(PARALLEL),omp)
   # OpenMP only
   PARMPI =
   PAROMP = -DOPENMP
   ifeq ($(COMPILERVENDOR),intel)
      PAROMP += -qopenmp
   else ifeq ($(findstring gcc,$(COMPILERVENDOR)),gcc)
      PAROMP  += -fopenmp
   endif
else ifeq ($(PARALLEL),both)
   # MPI and OpenMP
   PARMPI = -DMPI
   PAROMP = -DOPENMP
   ifeq ($(COMPILERVENDOR),intel)
      PAROMP += -qopenmp
   else ifeq ($(findstring gcc,$(COMPILERVENDOR)),gcc)
      PAROMP  += -fopenmp
      PARMPI  += -lmpi
   endif
else
$(error Bad parallelization option. Check the makefile comments)
endif

# Assemble compiler flags
F90_FLAGS = $(OPTIMIZATION) $(PARMPI) $(DEBUG) $(PRECISION) $(LIBRARIES) $(MANDATORY_F90) $(GENERAL) $(FPEFLAGS) $(LTO)
F77_FLAGS = $(OPTIMIZATION) $(PARMPI) $(DEBUG) $(LIBRARIES) $(MANDATORY_F77) $(GENERAL) $(FPEFLAGS)

###########################End of Editable part######################################

BUILD_DEFS:=-D _F90_FLAGS="'$(F90_FLAGS)'" \
           -D _F77_FLAGS="'$(F77_FLAGS)'" \
           -D _LDHDF5="'$(LDHDF5)'" \
           -D _LDTLDB="'$(LDTLDB)'" \
           -D _MPIP="'$($MPIP)'" \
           -D _FC="'`$(FC) --version | head -n 1`'" \
           -D _CC="'`$(CC) --version | head -n 1`'" \
           -D   _DATE="' `date` '"

# Rules and dependencies for the executable
all: jkiss32.o statarrays.o modules.o extra_functions.o mpisetup.o io_ascii.o SUB_LSQ_PLANE.o \
 proposals.o misfitcalc.o mpiexchange.o noise.o covmats.o mpiomcmc.o mpipt.o \
 quadpack_re.o attenuation.o sw_compute.o raytracer.o SUB_THERM_COND.o init_swc.o \
 SUB_TD_NOD.o redefine.o proposaldata.o Select_Col.o \
 io_tiledb_core.o io_tiledb_driver.o io_xdmf_hdf5.o io_png_core.o io_png_driver.o \
 BLASlib_new.o SUB_flib_new.o SUB_iniprp_new.o SUB_nlib_new.o SUB_olib_new.o SUB_resub_new.o SUB_rlib_new.o SUB_tlib_new.o \
 SUB_clib.o SUB_flib.o SUB_iniprp.o SUB_nlib.o SUB_olib.o SUB_resub.o SUB_rlib.o SUB_tlib.o \
 SUB_thermo.o SUB_TEMPERATURE_1D.o SUB_COLUMNS.o theo.o io_xdmf_hdf5_2km.o \
 fftmath.o SUB_iterdeconfd.o kennet.o io_native.o covmats_update.o \
 tess2prism.o SUB_Geo_Grad3D_sph.o SUB_Grav_Grad3D_sph.o SUB_U_SECOND_DER_sph.o SUB_GRAV_PRISM_sph.o \
 io_tiledb_primtosec.o io_cmdline.o synthetic_maker.o tests.o LITMOD3D_4INV.o LITMOD.o

.PHONY: fast
fast: DEBUG:=
fast: all

LITMOD3D_4INV.o :LITMOD3D_4INV.f90
	$(FC) $(F90_FLAGS) $(COMPOPT) $(PAROMP) -c LITMOD3D_4INV.f90


ifeq ($(findstring NEWPERPLEX,$(COMPOPT)),NEWPERPLEX)
   PERPLEXFILES := BLASlib_new.o SUB_flib_new.o SUB_iniprp_new.o SUB_nlib_new.o SUB_olib_new.o SUB_resub_new.o SUB_rlib_new.o SUB_tlib_new.o
else
   PERPLEXFILES := SUB_clib.o SUB_flib.o SUB_iniprp.o SUB_nlib.o SUB_olib.o SUB_resub.o SUB_rlib.o SUB_tlib.o
endif

%.o : %.F90
	$(FC) $(F90_FLAGS) $(COMPOPT) $(PAROMP) -c $*.F90 -o $*.o

#--------------------------------------------------------------------------------------
# Linking the objects
LITMOD.o:
	$(FC) $(PAROMP) -o LITMOD.i $(LTO) \
	jkiss32.o statarrays.o modules.o extra_functions.o mpisetup.o io_ascii.o \
	SUB_LSQ_PLANE.o proposals.o misfitcalc.o mpiexchange.o noise.o covmats.o mpiomcmc.o mpipt.o \
	sw_compute.o raytracer.o SUB_THERM_COND.o init_swc.o quadpack_re.o \
	SUB_TD_NOD.o redefine.o proposaldata.o Select_Col.o \
	io_tiledb_core.o io_tiledb_driver.o io_xdmf_hdf5.o io_png_core.o io_png_driver.o \
	$(PERPLEXFILES) SUB_thermo.o SUB_TEMPERATURE_1D.o SUB_COLUMNS.o attenuation.o \
	fftmath.o SUB_iterdeconfd.o kennet.o theo.o io_native.o covmats_update.o \
	tess2prism.o SUB_Geo_Grad3D_sph.o SUB_Grav_Grad3D_sph.o SUB_U_SECOND_DER_sph.o SUB_GRAV_PRISM_sph.o \
	io_tiledb_primtosec.o io_cmdline.o synthetic_maker.o io_xdmf_hdf5_2km.o tests.o LITMOD3D_4INV.o \
	$(LDHDF5) $(MPIP) $(LDTLDB) $(LDPNG)


# Cleaning
.PHONY: clean
clean:
	rm -rf LITMOD.i LITMOD.exe

# documentation
.PHONY: docs
docs: docs.man docs.doxygen

docs.man:
	man -t ./litmod > litmod.ps && ps2pdf litmod.ps && rm -f litmod.ps
docs.doxygen:
ifdef DOXYGENPATH
	$(DOXYGENPATH) litmod.conf
	$(MAKE) -C ./docs/latex/ &> ./docs/latex/out.txt
else
	@echo "Specify doxygen executable to produce Doxygen-LaTeX documentation"
endif

