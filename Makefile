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
	install -m 755 globals.conf ${LIB}/globals
	install -m 755 shared_scripts.sh ${LIB}/shared_scripts
	install -m 755 diagnose_tools.sh ${LIB}/diagnose_tools

uninstall: clean
	rm -f ${BIN}/piavpn

clean:
	rm -fr ${LIB}
	rm -fr ${RUN}

purge: uninstall
	rm -fr ${ETC}

reinstall: purge install


