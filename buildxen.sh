#!/bin/sh

IFS=' '
BUILDXENMETAL_MKCONF="# maxphys = 32k is a Xen limitation (64k - overhead)
CPPFLAGS+=-DMAXPHYS=32768
.if defined(LIB) && \${LIB} == \"pthread\"
.PATH:	$(pwd)
PTHREAD_MAKELWP=pthread_makelwp_rumprunxen.c
CPPFLAGS+=      -D_PTHREAD_GETTCB_EXT=_lwp_rumpxen_gettcb
.endif  # LIB == pthread
CFLAGS+=-fno-stack-protector -fno-builtin-sin -fno-builtin-cos
CFLAGS+=-fno-builtin-sinf -fno-builtin-cosf"
unset IFS

export BUILDXENMETAL_MKCONF
export BUILDXENMETAL_PCI_P=true

[ ! -f ./buildrump.sh/subr.sh ] && git submodule update --init buildrump.sh
. ./buildrump.sh/subr.sh
./buildrump.sh/xenbaremetal.sh "$@" || die xenbaremetal.sh failed

# build unwind bits if we support c++
RUMPMAKE=$(pwd)/rumptools/rumpmake
if havecxx; then
	( cd librumprun_unwind &&
		${RUMPMAKE} dependall &&
		${RUMPMAKE} install
	) || die build of librumprun_unwind failed
fi

makekernlib ()
{
	lib=$1
	OBJS=`pwd`/rumpobj/$lib
	mkdir -p ${OBJS}
	( cd ${lib} &&
		${RUMPMAKE} MAKEOBJDIRPREFIX=${OBJS} obj &&
		${RUMPMAKE} MAKEOBJDIRPREFIX=${OBJS} dependall &&
		${RUMPMAKE} MAKEOBJDIRPREFIX=${OBJS} install
	) || die makekernlib $lib failed
}
make -C xen links
makekernlib rumpxenif
makekernlib rumpxendev

# build the domU image
CONFIG_CXX=no
havecxx && CONFIG_CXX=yes
make CONFIG_CXX="${CONFIG_CXX}" || die make failed

echo
echo ">> $0 ran successfully"
exit 0
