CC=			gcc
CXX=		g++
CFLAGS=		-Wall -O4 -fomit-frame-pointer
CXXFLAGS=   $(CFLAGS)
DFLAGS=		-DPHYML
DFLAGS_SPEC=-DUNIX -DLH3_REVISION -DLH3_ADDON
PROG=		phyml
LIBOBJS=	bionj.o eigen.o free.o ml.o models.o optimiz.o options.o simu.o \
			utilities.o lh3_addon.o lh3_spec.o
INCLUDES=	-I.
LIBS=		-L. -lphyml -lm
SUBDIRS=	.

.SUFFIXES:.c .cc .o

.c.o:
		$(CC) -c $(DFLAGS) $(DFLAGS_SPEC) $(CFLAGS) $(INCLUDES) $< -o $@

.cc.o:
		$(CXX) -c $(DFLAGS) $(DFLAGS_SPEC) $(CXXFLAGS) $(INCLUDES) $< -o $@

all:$(PROG)

lib-recur all-recur clean-recur install-recur:
		@target=`echo $@ | sed s/-recur//`; \
		wdir=`pwd`; \
		list='$(SUBDIRS)'; for subdir in $$list; do \
			cd $$subdir; \
			$(MAKE) CC="$(CC)" DFLAGS="$(DFLAGS)" CFLAGS="$(CFLAGS)" \
				INCLUDES="$(INCLUDES)" $$target || exit 1; \
			cd $$wdir; \
		done;

lib:libphyml.a

libphyml.a:$(LIBOBJS)
		$(AR) -cru $@ $(LIBOBJS)

phyml:lib-recur main.o
		$(CC) $(CFLAGS) $(DFLAGS) main.o -o $@ $(LIBS)

clean:
		rm -f gmon.out *.o a.out phyml lib*.a
