#!/bin/bash
#Activate virtual environment
. /appenv/bin/activate


#Build
python3 setup.py bdist_wheel --universal --no-index -f /build


#Run arguments
exec $@