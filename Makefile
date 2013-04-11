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
	cc -Wall -o data $(objects) -L"/usr/local/lib" -lsensors -pthread
temperature.o : temperature.h utilities.h
data_collector.o : options.h utilities.h temperature.h power.h pws.h \
	control.h
options.o : utilities.h options.h pws.h utilities.h
utilities.o : utilities.h options.h
power.o : power.h utilities.h
pws.o : pws.h power.h control.h 
control.o : control.h utilities.h temperature.h pws.h 

.PHONY : clean
clean :
	rm data $(objects)

