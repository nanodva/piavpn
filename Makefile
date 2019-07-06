#/usr/bin/make

PNAME = piavpn
SHELL = /bin/bash

# PREFIX ?= /usr/local
# BIN = $(DESTDIR)$(PREFIX)/bin
BIN = $(DESTDIR)/usr//bin
#LIB = $(DESTDIR)$(PREFIX)/lib/${PNAME}
LIB = $(DESTDIR)/usr/lib/$(PNAME)

# folders installed by piavpn
ETC = $(DESTDIR)/etc/$(PNAME)
RUN = $(DESTDIR)/var/run/$(PNAME)

# install binaries
install:
	install -d $(BIN)
	install -m 755 piavpn.sh $(BIN)/piavpn

remove: clean
	rm -f $(BIN)/piavpn

clean:
	rm -fr $(LIB)
	rm -fr $(RUN)

uninstall: remove
purge: remove
	rm -fr $(ETC)

reinstall: purge install


