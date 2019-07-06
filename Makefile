#/usr/bin/make

#
PNAME=piavpn

BIN=/usr/bin
LIB=/usr/lib/${PNAME}

# folders installed by piavpn
ETC=/etc/${PNAME}
RUN=/var/run/${PNAME}

# install binaries
install:
	install -m 755 piavpn.sh ${BIN}/piavpn
	install -d ${LIB}

uninstall: clean
	rm -f ${BIN}/piavpn

clean:
	rm -fr ${LIB}
	rm -fr ${RUN}

purge: uninstall
	rm -fr ${ETC}

reinstall: purge install


