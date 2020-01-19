_Docker_ container for _Nominatim_ with embedded _OpenStreetMap_ data (one region) based on [Nominatim Docker 3.4](https://github.com/mediagis/nominatim-docker).

List of available regions could be found on [OpenStreetMap Data Extracts](http://download.geofabrik.de/).

1. Clone the repository
2. Build the image:
   ```
   docker image build --build-arg REGION=europe/belarus --tag <image> .
   ```
3. Create and run the container (start only webserver on the port 8080):
   ```
   docker container run --name nominatim --publish 8080:80 <image>
   ```

Notes:

* Before creating an image please verify that your machine has enough space.
* Building image will require some time (hours, days) depends on the region.

Arguments:

* REGION - case-sensentivie region (e.g. _europe/belarus_)

Exposed ports:

* 80 - web-server
* 5432 - posgresql database

Sample container with _Belarus_ region could be downloaded from [Docker Hub](https://hub.docker.com/repository/docker/vasalvit/nominatim-europe-belarus).
