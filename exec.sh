docker build . -t janus-ubuntu

docker run -it -d -p 80:80 -p 443:443 -p 8080:8080 -p 8089:8089 --rm --name janus janus-ubuntu

