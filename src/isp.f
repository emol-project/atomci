C*DECK ISP
C      revised   SAS     94-01-08
C      presetting of array failed for News F77
C      converted in accord to the standard Fortran 
      FUNCTION ISP(JM)
      include 'include/COMCFP'
      character * 4 IDS
      DIMENSION IDS(4)
      save itt
C     DATA ITT/1/  changed by msekiya Oct. 07 1994
      DATA ITT/0/
      DATA IDS/'ISP','IOR','ILFO','IQS'/
C
      k = jm/256
      ISP=ICONNT(3,K)
      M=1
      IF(ITT.NE.0) GO TO 9010
      RETURN
C
      ENTRY IQS(JM)
      k = jm/256
      IQS=ICONNT(2,K)
      ISP=IQS
      M=4
      IF(ITT.NE.0) GO TO 9010
      RETURN
C
      ENTRY ILFO(JM)
      k = jm/256
      ILFO=ICONNT(1,K)
      ISP=ILFO
      M=3
      IF(ITT.NE.0) GO TO 9010
      RETURN
C
      ENTRY LSQN(L,IQ,IS)
      M=(L+1)/2
      LSQN=       (L*(L+6-2*IQ)+IQ*(IQ-6)-2*IS+8)/4+ILSTAD(M)
      IF(ITT.NE.0) GO TO 9012
      RETURN
 9012 WRITE(6,9013) LSQN,L,IQ,IS
 9013 FORMAT('    LSQN =',I10,'   PARM (L,IQ,IS) =',3I10)
      RETURN
C
 9010 WRITE(6,9011) IDS(M),ISP, JM
 9011 FORMAT('    ',A4,' = ',I10,'   PARM ( JM ) =',Z10)
      RETURN
C
C      trace input
      ENTRY ISPTST(itrace)
      ITT=itrace
      IDUMM=IORTST(itrace)
      RETURN
      END
