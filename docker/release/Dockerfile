FROM jhaas8/todobackend-base:latest
MAINTAINER Jan Haas


#Copy application artefacts
COPY target /wheelhouse


#Install application
RUN . /appenv/bin/activate && \
	pip3 install --no-index -f /wheelhouse todobackend && \
	rm -rf /wheelhouse &&  \
	apt-get install -qy python3-dev default-libmysqlclient-dev