#@date 1/17/2013
#@author Sriram Jayakumar
#Avoid using wildcards, since I don't know how to
#use them with makefiles

objects = temperature.o data_collector.o options.o \
	utilities.o power.o pws.o

#Some systems may require specifying -L for the
#location of the sensors library, and -I for the
#locations of sensors.h
data : $(objects)
	cc -Wall -o data $(objects) -L"/usr/local/lib" -lsensors -pthread
temperature.o : temperature.h utilities.h
data_collector.o : options.h utilities.h temperature.h power.h pws.h
options.o : utilities.h options.h pws.h utilities.h
utilities.o : utilities.h options.h
power.o : power.h utilities.h
pws.o : pws.h power.h 

.PHONY : clean
clean :
	rm data $(objects)

