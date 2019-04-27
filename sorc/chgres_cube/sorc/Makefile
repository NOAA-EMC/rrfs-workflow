SHELL	=/bin/ksh
INCMOD	=$(INCS)             
LIBS    =$(LIBSM)

include $(ESMFMKFILE)

SRCM	=grb_chgres.f
SRCS	=

OBJS	=chgres.o \
	 atmosphere.o \
	 input_data.o \
	 grib2_util.o \
	 surface.o \
	 model_grid.o \
	 program_setup.o \
	 write_data.o \
	 search_util.o \
	 static_data.o \
	 utils.o \
	 atmdata_type.o \

FC	=$(FCMP)
FC90    =$(FCMP95)
LDR	=$(FCMP)

FFLAGS	=$(FFLAGSM)
OMPFLAG=$(OMPFLAGM)
LDFLAGS =$(LDFLAGSM)

CMD	=global_chgres.exe
$(CMD):	$(OBJS)
	$(LDR) $(LDFLAGS) $(OBJS) $(LIBS) $(ESMF_F90COMPILEPATHS) -o $(CMD) $(ESMF_F90LINKPATHS) $(ESMF_F90ESMFLINKRPATHS) $(ESMF_F90ESMFLINKLIBS) -g -traceback

grib2_util.o: model_grid.o program_setup.o atmdata_type.o grib2_util.F90
		$(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c grib2_util.F90

model_grid.o:  program_setup.o model_grid.F90
	        $(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c model_grid.F90

utils.o:  utils.f90
	        $(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c utils.f90

atmdata_type.o:  atmdata_type.F90
		$(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c atmdata_type.F90

program_setup.o:  program_setup.f90
	        $(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c program_setup.f90

atmosphere.o:  program_setup.o model_grid.o input_data.o atmosphere.F90
	        $(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c atmosphere.F90

chgres.o: atmosphere.o model_grid.o program_setup.o surface.o chgres.F90
	        $(FC90) $(FFLAGS) $(OMPFLAG) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c chgres.F90

write_data.o: atmosphere.o  model_grid.o program_setup.o surface.o static_data.o write_data.F90
	        $(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c write_data.F90

input_data.o: program_setup.o model_grid.o grib2_util.o atmdata_type.o input_data.F90
	        $(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c input_data.F90

surface.o: search_util.o model_grid.o input_data.o program_setup.o static_data.o surface.F90
	        $(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c surface.F90

search_util.o: search_util.f90
	        $(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c search_util.f90

static_data.o: model_grid.o program_setup.o static_data.F90
	        $(FC90) $(FFLAGS) $(INCMOD) $(ESMF_F90COMPILEPATHS) -c static_data.F90

clean:
	        rm -f *.o *.mod ${CMD} ../exec/${CMD}
