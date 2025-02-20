# st - simple terminal
# See LICENSE file for copyright and license details.
.POSIX:

include config.mk

SRC = st.c x.c
OBJ = $(SRC:.c=.o)

all: st

config.h:
	cp config.def.h config.h

.c.o:
	$(CC) $(STCFLAGS) -c $<

st.o: config.h st.h win.h
x.o: arg.h config.h st.h win.h

$(OBJ): config.h config.mk

st: $(OBJ)
	$(CC) -o $@ $(OBJ) $(STLDFLAGS)

clean:
	rm -f st $(OBJ) st-$(VERSION).tar.gz

dist: clean
	mkdir -p st-$(VERSION)
	cp -R FAQ LEGACY TODO LICENSE Makefile README config.mk\
		config.def.h st.info st.1 arg.h st.h win.h $(SRC)\
		st-$(VERSION)
	tar -cf - st-$(VERSION) | gzip > st-$(VERSION).tar.gz
	rm -rf st-$(VERSION)

dist.built: st
	mkdir -p st-$(VERSION)
	cp st st.1 st-$(VERSION)
	printf '#!/bin/sh\nset -e\n' >st-$(VERSION)/install
	echo 'install -Dm755 st ${PREFIX}/bin/st' >>st-$(VERSION)/install
	echo 'install -Dm644 st.1 ${MANPREFIX}/man1/st.1' >>st-$(VERSION)/install
	echo 'sed -i "s/VERSION/$(VERSION)/g" ${MANPREFIX}/man1/st.1' >>st-$(VERSION)/install
	chmod +x st-$(VERSION)/install
	tar czf st.tgz st-$(VERSION)
	rm -rf st-${VERSION}

install: st
	install -Dm755 st $(DESTDIR)$(PREFIX)/bin/st
	install -Dm644 st.1 $(DESTDIR)$(MANPREFIX)/man1/st.1
	sed -i "s/VERSION/$(VERSION)/g" $(DESTDIR)$(MANPREFIX)/man1/st.1
	tic -sx st.info

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/st
	rm -f $(DESTDIR)$(MANPREFIX)/man1/st.1

.PHONY: all clean dist install uninstall dist.built
