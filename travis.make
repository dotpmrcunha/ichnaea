HERE = $(shell pwd)
INSTALL = pip install --no-deps --disable-pip-version-check

LIBMAXMIND_DOWNLOAD = https://github.com/maxmind/libmaxminddb/releases/download
LIBMAXMIND_VERSION = 1.2.0
LIBMAXMIND_NAME = libmaxminddb-$(LIBMAXMIND_VERSION)
MAXMINDDB_VERSION = 1.2.1

.PHONY: all pip build test build_maxmind

all: build

lib/libmaxminddb.0.dylib:
	rm -rf $(HERE)/libmaxminddb
	wget -q $(LIBMAXMIND_DOWNLOAD)/$(LIBMAXMIND_VERSION)/$(LIBMAXMIND_NAME).tar.gz
	tar xzvf $(LIBMAXMIND_NAME).tar.gz
	rm -f $(LIBMAXMIND_NAME).tar.gz
	mv $(LIBMAXMIND_NAME) libmaxminddb
	cd libmaxminddb; ./configure --prefix=$(HERE) && make -s && make install

build_maxmind: lib/libmaxminddb.0.dylib
	CFLAGS=-I$(HERE)/include LDFLAGS=-L$(HERE)/lib \
		$(INSTALL) --no-binary :all: maxminddb==$(MAXMINDDB_VERSION)

pip:
	virtualenv .
	pip install --disable-pip-version-check -r requirements/build.txt

build: pip build_maxmind
	$(INSTALL) -r requirements/binary.txt
	$(INSTALL) -r requirements/python.txt
	cythonize -f ichnaea/geocalc.pyx
	$(INSTALL) -e .
	python -c "from compileall import compile_dir; compile_dir('ichnaea', quiet=True)"
	mysql -utravis -h localhost -e \
		"CREATE DATABASE IF NOT EXISTS location" || echo

test:
	TESTING=true ICHNAEA_CFG=$(HERE)/ichnaea/tests/data/test.ini \
	DB_RW_URI="mysql+pymysql://travis@localhost/location" \
	DB_RO_URI="mysql+pymysql://travis@localhost/location" \
	GEOIP_PATH=$(HERE)/ichnaea/tests/data/GeoIP2-City-Test.mmdb \
	REDIS_HOST=localhost REDIS_PORT=6379 \
	LD_LIBRARY_PATH=$$LD_LIBRARY_PATH:$(HERE)/lib \
	pytest --cov-config=.coveragerc --cov=ichnaea ichnaea
