FROM ubuntu:focal

ARG REGION=europe/belarus

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8

RUN apt-get -y update -qq && \
    apt-get -y install locales && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    apt-get install -y build-essential cmake g++ ninja-build libboost-dev libboost-system-dev \
    libboost-filesystem-dev libexpat1-dev zlib1g-dev libxml2-dev\
    libbz2-dev libpq-dev libgeos-dev libgeos++-dev libproj-dev \
    postgresql-server-dev-12 postgresql-12-postgis-3 postgresql-contrib-12 \
    apache2 php php-pgsql libapache2-mod-php php-pear php-db \
    php-intl git curl sudo \
    python3-pip libboost-python-dev \
    osmosis && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* /var/tmp/*

WORKDIR /app

# Configure postgres
RUN echo "host all  all    0.0.0.0/0  trust" >> /etc/postgresql/12/main/pg_hba.conf && \
    echo "listen_addresses='*'" >> /etc/postgresql/12/main/postgresql.conf

# Nominatim install
ENV NOMINATIM_VERSION v3.6.0
RUN git clone --recursive https://github.com/openstreetmap/Nominatim ./src
RUN cd ./src && git checkout tags/$NOMINATIM_VERSION && git submodule update --recursive --init && \
    mkdir build && cd build && cmake .. && make -j5

# Osmium install to run continuous updates
RUN pip3 install osmium
RUN pip3 install psycopg2
# Apache configure
COPY nominatim.conf /etc/apache2/sites-enabled/000-default.conf

# Load initial data
RUN curl http://www.nominatim.org/data/country_grid.sql.gz > /app/src/data/country_osm_grid.sql.gz
RUN chmod o=rwx /app/src/build

# Configure Nomimatim (local.php)
RUN echo "<?php" > /app/src/build/settings/local.php && \
    echo "@define('CONST_Postgresql_Version', '12');" >> /app/src/build/settings/local.php && \
    echo "@define('CONST_Postgis_Version', '3.0');" >> /app/src/build/settings/local.php && \
    echo "@define('CONST_Website_BaseURL', '/');" >> /app/src/build/settings/local.php && \
    echo "@define('CONST_Replication_Url', 'http://download.geofabrik.de/${REGION}-updates');" >> /app/src/build/settings/local.php && \
    echo "@define('CONST_Replication_MaxInterval', '86400');" >> /app/src/build/settings/local.php && \
    echo "@define('CONST_Replication_Update_Interval', '86400');" >> /app/src/build/settings/local.php && \
    echo "@define('CONST_Replication_Recheck_Interval', '900');" >> /app/src/build/settings/local.php && \
    echo "@define('CONST_Pyosmium_Binary', '/usr/local/bin/pyosmium-get-changes');" >> /app/src/build/settings/local.php

# Initialize database with specified region (init.sh)
RUN sudo curl http://download.geofabrik.de/${REGION}-latest.osm.pbf -o /latest.osm.pbf && \
    sudo rm -rf /var/lib/postgresql/12/main && \
    sudo mkdir -p /var/lib/postgresql/12/main && \
    sudo chown -R postgres:postgres /var/lib/postgresql/12/main && \
    sudo -u postgres /usr/lib/postgresql/12/bin/initdb -D /var/lib/postgresql/12/main && \
    sudo -u postgres /usr/lib/postgresql/12/bin/pg_ctl start -D /var/lib/postgresql/12/main && \
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='nominatim'" | grep -q 1 || sudo -u postgres createuser -s nominatim && \
    sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || sudo -u postgres createuser -SDR www-data && \
    sudo -u postgres psql postgres -c "DROP DATABASE IF EXISTS nominatim" && \
    useradd -m -p password1234 nominatim && \
    chown -R nominatim:nominatim ./src && \
    sudo -u nominatim ./src/build/utils/setup.php --osm-file /latest.osm.pbf --all --threads 5 && \
    sudo -u postgres /usr/lib/postgresql/12/bin/pg_ctl stop -D /var/lib/postgresql/12/main && \
    sudo chown -R postgres:postgres /var/lib/postgresql/12/main && \
    sudo rm /latest.osm.pbf

EXPOSE 80
EXPOSE 5432

COPY start.sh /app/start.sh
COPY startapache.sh /app/startapache.sh
COPY startpostgres.sh /app/startpostgres.sh

CMD bash /app/start.sh
