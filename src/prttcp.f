C*DECK PTCPS
      SUBROUTINE PRTTCP (NSYM,NBF,NOB,NTAB,EIG,C)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION NBF(*),NOB(*),NTAB(*),EIG(*),C(*)
C
77777 CONTINUE
C
   10 NE=0
      DO 40 L=1,NSYM
      IF (NBF(L).EQ.0) GO TO 40
      IF (NOB(L).EQ.0) GO TO 40
      IA=NTAB(L)
      NA=NOB(L)
      NB=NBF(L)
C
      WRITE (6,200) L
      DO 30 N=1,NA,8
      NC=N+7
      IF (NC.GT.NA) NC=NA
      ND=NC-N+1
      WRITE (6,202) (I,I=N,NC)
   14 IB=IA+ND*NB-1
      WRITE (6,206)
      DO 20 K=1,NB
      WRITE (6,208) K,(C(I),I=IA,IB,NB)
   20 IA=IA+1
   30 IA=IB+1
      NE=NE+NOB(L)
   40 CONTINUE
      RETURN
C
  200 FORMAT (//' SYM=',I3)
  202 FORMAT (//' ',9X,8I25)
  204 FORMAT (/' ',9X,8F25.15)
  206 FORMAT (1X)
  208 FORMAT (1X,I9,8e25.15)
C
      END

