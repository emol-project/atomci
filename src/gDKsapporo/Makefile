AR = ar
ARFLAGS = cr
RANLIB = ranlib
LIB = libgDKsapporo.a

OA = h1test.o clear.o dbsval.o fbsval.o glset.o init.o h1rel2.o oei.o chdns.o initdk.o gdk.o trfm1.o trfm2.o erf.o trmt.o fncset.o dicgam.o dgamm.o
OGDK = chdns.o clear.o dbsval.o dgamm.o dicgam.o erf.o fbsval.o fncset.o gdk.o glset.o h1rel2.o init.o initdk.o oei.o trfm1.o trfm2.o trmt.o

.SUFFIXES:
.SUFFIXES: .o .f

.f.o:
	gfortran -fno-automatic -O -c $<
#	g77 -fno-automatic -O -c $<
#	ifort -O -c $<

all: dkint $(LIB)

# The bundled ../lapack/libplapack.a this used to link is gone;
# link the system BLAS/LAPACK instead (pkg-config lapack+blas, then
# openblas, else a blind -llapack -lblas -- dkint is a standalone
# maintenance tool, not part of the main atomci build, so it doesn't get
# src/Makefile's lapack-guard hard failure; a missing library just fails
# this target's own link with the usual linker error).
LAPACK_LINK := $(shell pkg-config --libs lapack blas 2>/dev/null || pkg-config --libs openblas 2>/dev/null || echo -llapack -lblas)

dkint: $(OA)
	gfortran -fno-automatic -O -o dkint $(OA) $(LAPACK_LINK)
#	gfortran -fno-automatic -O -o dkint $(OA) -Wl,-framework -Wl,vecLib
#	ifort -O -lmkl_ia32 -o dkint $(OA)

$(LIB): $(OGDK)
	$(AR) $(ARFLAGS) $(LIB) $(OGDK)
	$(RANLIB) $(LIB)

#old: o1test.o relcn.o
#	gfortran -fno-automatic -O -o old o1test.o relcn.o -Wl,-framework -Wl,vecLib

clean:
	-rm *.o dkint $(LIB)
