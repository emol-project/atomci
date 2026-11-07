C*DECK IOR
C      revised   SAS     94-01-08
C      presetting of array failed for News F77
C      converted in accord to the standard Fortran 
      FUNCTION IOR(JM)
      include 'include/COMCFP'
      save itt
C     DATA ITT/1/  changed by msekiya Oct. 07 1994
      DATA ITT/0/
C     LPX=JM
C     LMTX=LP3
C     K=MTX
C     LMTX=LP4
C     KTU=MTX
      k = jm/256
      ktu = and(255,jm)
      KT=ICONNT(5,K)+KTU-1
      IOR=ILFUNC(KT)
      IF(ITT.NE.0) GO TO 9010
      RETURN
C
 9010 WRITE(6,9011) JM,IOR, k, ktu, kt
 9011 FORMAT('    IOR ',Z10,I10,3i8)
      RETURN
C
C      trace input
C
      ENTRY IORTST(itrace)
      ITT=itrace
      RETURN
      END
