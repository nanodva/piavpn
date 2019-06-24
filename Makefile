BIN=/usr/local/bin

install:
	install -m 755 piavpn.sh ${BIN}/piavpn
	
uninstall:
	rm ${BIN}/piavpn