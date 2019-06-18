FROM jhaas8/todobackend-base:latest
MAINTAINER Jan Haas


#Install dev/build dependencies
RUN apt-get update && \
	apt-get install -qy python3-dev default-libmysqlclient-dev


#Activate virtual environment and install wheel support
RUN . /appenv/bin/activate && \
	pip3 install wheel --upgrade


#PIP environment variables (NOTE: must be set after installung wheel)
ENV WHEELHOUSE=/wheelhouse PIP_WHEEL_DIR=/wheelhouse PIP_FIND_LINKS=/wheelhouse XDG_CACHE_HOME=/cache


#Output: Build artefacts (Wheels) are output here
VOLUME /wheelhouse


#Output: Build cache
VOLUME /build


#Output: Test reports
VOLUME /reports


#Add entrypoint scripts
COPY scripts/test.sh /usr/local/bin/test.sh
RUN chmod +x /usr/local/bin/test.sh


#Set defaults for entrypoint and command string
ENTRYPOINT ["test.sh"]
CMD ["python3", "manage.py", "test", "--noinput"]


#Add application source
COPY src /application
WORKDIR /application
