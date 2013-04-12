#@date 1/17/2013
#@author Sriram Jayakumar
#Avoid using wildcards, since I don't know how to
#use them with makefiles

objects = temperature.o data_collector.o options.o \
	utilities.o power.o pws.o control.o

#Some systems may require specifying -L for the
#location of the sensors library, and -I for the
#locations of sensors.h
data : $(objects)
	cc -Wall -g -o data $(objects) -L"/usr/local/lib" -lsensors -pthread
temperature.o : temperature.h utilities.h temperature.c
	cc -g -c -o temperature.o temperature.c
data_collector.o : options.h utilities.h temperature.h power.h pws.h \
	control.h data_collector.h data_collector.c
	cc -g -c -o data_collector.o data_collector.c
options.o : utilities.h options.h pws.h utilities.h options.c control.h \
	pws.h
	cc -g -c -o options.o options.c
utilities.o : utilities.h options.h utilities.c
	cc -g -c -o utilities.o utilities.c
power.o : power.h utilities.h power.c
	cc -g -c -o power.o power.c
pws.o : pws.h power.h control.h pws.c
	cc -g -c -o pws.o pws.c
control.o : control.h utilities.h temperature.h pws.h data_collector.h \
	control.c options.h
	cc -g -c -o control.o control.c
#TODO Accurately describe control.h including data_collector.h, options.h
#including control.h
.PHONY : clean
clean :
	rm data $(objects)

