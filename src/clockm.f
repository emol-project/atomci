       SUBROUTINE CLOCKM(I)                                             
C ----------------------------------------------------------------------CLO00020
C                                                                       CLO00030
C     UPDATED  ON JULY 26, 1990  AT IBMKGN  BY FUKASHI                  CLO00040
C     UPDATED  ON MAY  25, 1995  AT IBMKGN  BY Masahiro 
C                                                                       CLO00050
C ----------------------------------------------------------------------CLO00060
C                                                                       CLO00070
        real tarray
        call iqsecs(tarray)
	i = tarray*10;
	END
