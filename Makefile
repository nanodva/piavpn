#/usr/bin/make

#

BIN=/usr/local/bin

# folders installed by piavpn
PNAME=piavpn
LIBPATH="/etc/${PNAME}"
RUNPATH="/var/run/${PNAME}"

install:
	install -m 755 piavpn.sh ${BIN}/piavpn

uninstall:
	rm ${BIN}/piavpn

clean:
	rm -fr ${LIBPATH}
	rm -fr ${RUNPATH}

