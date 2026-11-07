C*DECK TRNONA
      SUBROUTINE TRNONA (NSYM,NOET,NFTA,NFTB,NALM,NBF,NOB,MTAB,NTAB,
     1                   NCTAB,MTA,NTA,CA,CB,CC,CT)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      INTEGER*2 LCWB(4)
      DIMENSION NBF(*),NOB(*),MTAB(*),NTAB(*),NCTAB(*),MTA(*),NTA(*),
     1          CA(*),CB(*),CC(*),CT(*)
      EQUIVALENCE (LCWB(1),CWB2)
C
      DO 200 L=1,NOET
      READ (NFTA,ERR=900) CWB1,CWB2,NINT,(CA(I),I=1,NINT)
      M=0
      M=LCWB(3)
      NB=NSYM+1
      NA=NB*M
      M=M+1
      DO 10 N=1,NB
      NA=NA+1
      MTA(N)=MTAB(NA)
   10 NTA(N)=NTAB(NA)
      NBGN=M/2+1
      NA=NTA(NB)
      IF (NA.EQ.0) NA=1
      DO 20 N=1,NA
   20 CB(N)=0.0D0
C
      DO 100 MA=NBGN,NSYM
      MB=IABS(M-MA)+1
      IF (MA.NE.MB) GO TO 50
      IF (NBF(MA)*NOB(MA).EQ.0) GO TO 100
      CALL NTRNPP 
     *  (1,1,NBF(MA),NOB(MA),CA(MTA(MA)+1),CB(NTA(MA)+1),1,
     *   CC(NCTAB(MA)),CT)
      GO TO 100
C
   50 IF (NBF(MA)*NBF(MB)*NOB(MA)*NOB(MB).EQ.0) GO TO 100
      CALL NTRNQP 
     *  (1,1,NBF(MB),NOB(MB),NBF(MA),NOB(MA),CA(MTA(MA)+1),
     *   CB(NTA(MA)+1),1,CC(NCTAB(MB)),CC(NCTAB(MA)),CT)
C
  100 CONTINUE
C
      NTRN=NTA(NB)
      IF (NTRN.EQ.0) NTRN=1
C  ******  CONVERTED   F.S.    13/06/80  ******
C     WRITE (NFTB,ERR=910) CWB1,CWB2,NTRN,(CB(I),I=1,NTRN)
      WRITE (NFTB        ) CWB1,CWB2,NTRN,(CB(I),I=1,NTRN)
C  ******  CONVERTED   F.S.    13/06/80  ******
C
  200 CONTINUE
      NALM=0
  210 RETURN
C
  900 WRITE (6,901)
  901 FORMAT ('1 READ ERROR IN TRNONA')
      GO TO 912
C  ******  CONVERTED   F.S.    13/06/80  ******
C 910 WRITE (6,911)
C 911 FORMAT ('1 WRITE ERROR IN TRNONA')
C  ******  CONVERTED   F.S.    13/06/80  ******
  912 NALM=1
      GO TO 210
      END
