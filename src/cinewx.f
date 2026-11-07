**********************************************************************
*
*  COPYRIGHT FUKASHI SASAKI 1990
*  ALL RIGHTS RESERVED.
*
*  PERMISSION IS GRANTED TO THE MOTECC CLUB TO DISTRIBUTE THIS CODE.
*  PERMISSION IS HEREBY GRANTED TO OTHERS TO USE, BUT NOT TO REPRODUCE
*  OR DISTRIBUTE THIS MATERIAL; THE USE IS RESTRICTED FOR RESEARCH
*  PURPOSES ONLY.  THIS MATERIAL MAY NOT BE REPRODUCED FOR COMMERCIAL
*  PURPOSES OR INCLUDED IN A COMMERCIAL PRODUCT WITHOUT THE SPECIFIC
*  WRITTEN PERMISSION OF FUKASHI SASAKI
*
*  ANY PUBLICATION BASED UPON RESULTS OBTAINED FROM THIS MATERIAL
*  MUST INCLUDE THE FOLLOWING ATTRIBUTION:
*
*       THIS WORK IS BASED, IN PART, ON RESULTS FROM THE
*       MOTECC(TM) PACKAGE.  MOTECC IS A TRADEMARK OF I.B.M.
*
*
**********************************************************************
*  THE NOTICE ABOVE IS THE ORIGINAL OF 1990, KEPT AS A RECORD.  CURRENT
*  TERMS: NON-COMMERCIAL RESEARCH AND EDUCATION ONLY.  SEE LEGENDS.TXT.
*            REVISED  BY M. SEKIYA ON AUG. 31 1990 AT KGN
*            REVISED  BY M. SEKIYA ON DEC. 12 1991 AT U of A
*
*
C*DECK CARDVC
      SUBROUTINE CARDVC(NFTA,NBF,NOB,BUF,NSYM)
C                                 CHECKED TASHI HUCC 10/25/89
      REAL*8 BUF 
      DIMENSION NAME(20),IND(5),BUF(1600),NBF(20),NOB(20)
      character * 1 lett
      DATA IND,IDPRNT,IUNIT/1,5*0,5/
      NAMELIST/BASVC/NAME,IDPRNT,IUNIT
C
      DO 7 I=1,20
  7   call ctoi4 ( '    ', NAME(I))
      REWIND NFTA
      READ(5,BASVC)
      CALL IRDSET(IDPRNT)
      CALL IRISET(IUNIT)
      M=0
      I1=1
      WRITE(NFTA) NAME,I1,NSYM,NBF,NOB,IND
      J=0
      DO 1 I=1,NSYM
      K=NOB(I)*NBF(I)
      IF(K.EQ.0) GO TO 1
      JI=J+1
      JL=J+K
    2 J=J+1
      CALL READfa(BUF(J), lett)
      if ( lett .ne. ')' ) go to 2
      j = j - 1
      IF(J.NE.JL) GO TO 9000
      WRITE(NFTA) M,(BUF(L),L=JI,JL)
      M=M+1
    1 continue
      CALL NEWCD
*     END FILE NFTA
      REWIND NFTA
      RETURN
 9000 WRITE(6,9001) M,J,K
 9001 FORMAT('0ERROR BASVC   M,J,K  ',3I6,'   ERROR *********')
      RETURN
      END
C*DECK CIVIO
      SUBROUTINE CIVIO (NFT,NRW,NK,NS,IK,EI,DV,NI,CV,NALM)
C                                 CHECKED TASHI 10/25/89 HUCC
      REAL*8 EI(*),CV(*),DV(*)
      INTEGER*4 IK(*)
      REAL*8 NI(*)
      CALL CIVIOA (NFT,NRW,NK,NS,IK,EI,DV,NI,NALM)
      IF (NALM.NE.0) GO TO 90
      IB=1
      DO 20 I=1,NS
      M=I
      CALL CIVIOB (NFT,NRW,M,NK,CV(IB),NALM)
      IF (NALM.NE.0) GO TO 90
   20 IB=IB+NK
   90 RETURN
      END
C*DECK CIVIOA
      SUBROUTINE CIVIOA (NFT,NRW,NKEEP,NSTAT,IKEEP,EI,DIV,NIT,NALM)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      INTEGER*4 IKEEP(NKEEP)
      REAL*8 NIT(NSTAT)
      DIMENSION EI(NSTAT),DIV(NSTAT)
  100 NALM=0
      IF (NRW.EQ.1) GO TO 110
      WRITE (NFT,ERR=200) IKEEP,EI,DIV,NIT
C  ******  CONVERTED   F.S.    13/06/80  CHANGED BY MAS 30/08/90
*     WRITE (NFT) IKEEP,EI,DIV,NIT
      GO TO 120
  110 READ  (NFT,END=210,ERR=200) IKEEP,EI,DIV,NIT
  120 RETURN
C
  200 NALM=1
  210 NALM=NALM+1
      WRITE(6,*) ' == IO ERROR IN READING FROM ',NFT
      GO TO 120
      END
C*DECK CIVIOB
      SUBROUTINE CIVIOB (NFT,NRW,NTH,NKEEP,VC,NALM)
C                                 CHECKED TASHI 10/25/89 HUCC
      REAL*8 VC(NKEEP)
  100 IF (NRW.NE.0) GO TO 110
C  ******  CONVERTED    F.S.  14/06/80   ******
C     WRITE (NFT    ) NTH,VC
      WRITE (NFT,ERR=200) NTH,VC
C  ******  CONVERTED    F.S.  14/06/80   ******
      GO TO 120
  110 READ  (NFT,END=200,ERR=200) NTH,VC
  120 NALM=0
  130 RETURN
C
  200 NALM=1
      WRITE(6,*) ' == IO ERROR IN READING FROM ',NFT
      GO TO 130
      END
C*DECK CNTRC
      SUBROUTINE CNTRC(MX,V1,V2,N)
C
C     CNTRC COMPUTES THE PRODUCT OF MATRIX MX TIMES VECTOR V1 AND
C           PLACES THE RESULT IN V2 -- ALL ARRAYS ARE IN CORE AND R*8
C     CALLING SEQUENCE PARAMETERS ARE AS FOLLOWS
C              MX   LOCATION OF LOWER TRIANGLE OF NXN SYMMETRIC MATRIX
C              V1   INITIAL VECTOR
C              V2   FINAL VECTOR
C              N    DIMENSION OF BASIS SET
C                                CHECKE TASHI 10/25/89 HUCC
C
      IMPLICIT REAL*8 (A-H,O-Z)
      REAL*8 MX
      DIMENSION MX(*),V1(*),V2(*)
      KI = 1
C
C     BEGIN COMPONENT OUTER LOOP
C
      DO 10 I=1,N
      K = KI
      V2(I) = 0.D0
C
C     BEGIN COMPONENT INNER LOOP
C
      DO 5 J=1,N
      V2(I) = MX(K)*V1(J) + V2(I)
      K = K+1
      IF (J .GE. I) K=K+J-1
    5 CONTINUE
   10 KI = KI + I
      RETURN
      END
C*DECK COMSH
      SUBROUTINE COMSH(JN,JNP,JM,KN,KNP,KM,   IN,INP,IM)
C                                 CHECKED TASHI 10/25/89 HUCC
      DIMENSION JM(2),KM(2),IM(2)
C
      IN=0
      INP=JNP
      IF (JN*KN.EQ.0) RETURN
      IF(JNP.NE.KNP) RETURN
      IF(JN.EQ.-1 .AND.KN.GT.0) GO TO 34
      IF(KN.EQ.-1) GO TO 53
      K=1
      L=1
   3  IF(JM(K)-KM(L)) 4,5,6
    4 K=K+1
      GO TO 7
    6 L=L+1
    7 IF (K.GT.JN.OR.L.GT.KN) RETURN
      GO TO 3
    5 IN=IN+1
      IM(IN)=JM(K)
      K=K+1
      GO TO 6
   34 DO 54 I=1,KN
C     LPX=JM(1)
C     LMTX=LP3
C     K=MTX
      k = jm(1)/256
      IF(K.EQ.KM(I)) GO TO 35
   54 CONTINUE
      RETURN
   35 IM(1)=JM(1)
   55 IN=-1
      RETURN
   53 IF(JN.GT.0) GO TO 63
      IF(JM(1).NE.KM(1)) RETURN
      GO TO 45
   63 DO 83 I=1,JN
C     LPX=KM(1)
C     LMTX=LP3
C     K=MTX
      k = km(1)/256
      IF(K.EQ.JM(I)) GO TO 45
   83 CONTINUE
      RETURN
   45 IM(1)=KM(1)
      GO TO 55
      END
C*DECK DEFDA
      SUBROUTINE DEFDA ( NFTX, LDSK )
      LOGICAL EX, OP
C     SAVE  MAXREC
      DATA  MAXREC/0/
C
C----------------- DAFILE CONDITION ---------------------------------*
      INQUIRE( UNIT=NFTX, OPENED=OP, EXIST=EX, IOSTAT=IO )
      IF (EX) THEN
             IF (OP) THEN
                     IF ( MAXREC .GT. LDSK ) THEN
                          WRITE( 6 , 2000 ) MAXREC , LDSK
                          RETURN
                     ELSE
                          CLOSE ( UNIT=NFTX )
                     END IF
             END IF
*
*------ DEFINE FILE ------*
C
C>>> OPEN STATEMENT FOR HI-TACH FORTRAN....
C       OPEN ( NFTX, FORM='UNFORMATTED', ACCESS='DIRECT',
C    &         RECL=7200, MAXREC=LDSK, ERR=1111, IOSTAT=IO,
C    &         CLEAR='YES' )
C
C>>> OPEN STATEMENT FOR STANDARD FORTRAN....
        OPEN ( NFTX, FORM='UNFORMATTED', ACCESS='DIRECT',
     &         RECL=7200, ERR=1111, IOSTAT=IO )
C
        MAXREC = LDSK
        RETURN
      ELSE
        WRITE(6,*) ' FILE NOT EXIST >>> ERROR ERROR <<< '
        WRITE(6,*) ' OPEN ERROR >>' , IO
        STOP 111
      END IF
C
1111    WRITE(6,*) 'OPEN ERROR >>' , IO
        WRITE(6,*) 'UNIT NUMBER>>',  NFTX  ,'    (',NFTX,' )'
        WRITE(6,*) 'LDSK NUMBER>>',  LDSK  ,'    (',LDSK,' )'
2000    FORMAT('0---IN DEFDA >> MAXREC = ',I5,'  >> LDSK = ',I5 )
        STOP 111
      END
C*DECK DENIO
      SUBROUTINE DENIO (NFT,NRW,NTH,LDEN,DEN,NALM)
C                                 CHECKED TASHI 10/25/89 HUCC
      REAL*8 DEN(LDEN)
  100 IF (NRW.EQ.0) GO TO 200
      READ (NFT,ERR=400) NTH,DEN
      GO TO 300
C 200 WRITE (NFT,ERR=400) NTH,DEN
C  ******  CONVERTED   F.S.    13/06/80  ******
  200 WRITE (NFT) NTH,DEN
  300 NALM=0
  310 RETURN
C
  400 NALM=1
      GO TO 310
      END
C*DECK DENMX
      SUBROUTINE DENMX
     1(NFTD,NFTH,NKEEP,IDLT,NPFLG,NSTAT,NALM,CV,
     1 NSYM,NOB,LDEN,DEN,DENS,LNIX,IROW,ICOL,NIX,CF)
*          REVISED BY MAS NFTD RECORD STRUCTURE IS CHANGED
*          REVISED BY TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
*     INTEGER*2 IDLT(2),NA(2),KA(2)  DELETE NA
      INTEGER*4 IDLT(*),KA(2)
      REAL * 8  DEN(LDEN),DENS(LDEN),CF(LNIX),CV(*)
      INTEGER * 4 NOB(*),NIX(LNIX),IROW(LNIX),ICOL(LNIX)
*     EQUIVALENCE (NA(1),NAB),(KA(1),MONE)
      DATA KA/1,1/
C
      NALM=0
      DO 80 I=1,LDEN
   80 DENS(I)=0.0D0
      IF (NPFLG.EQ.1) GO TO 84
      IF ( NSTAT .GT. 1 ) WRITE (6,400) NSTAT
      IF ( NSTAT .EQ. 1 ) WRITE (6,401)
   84 NCF=0
      REWIND NFTH
      DO 340 NST=1,NSTAT
   86 DO 90 I=1,LDEN
   90 DEN(I)=0.0D0
C
  100 REWIND NFTD
      READ (NFTD,END=990,ERR=900,IOSTAT=IERR) IDIAG
*     READ (NFTD,ERR=900) NT,NIJ,NIX,CF
      READ (NFTD,IOSTAT=IERR,END=990,ERR=900) NT,IROW,ICOL,NIX,CF
      M=1
      IF (IDIAG.EQ.1) GO TO 120
C
C 110 IF (NIJ(M).NE.MONE) GO TO 120
  110 IF (IROW(M).NE.KA(1).OR.ICOL(M).NE.KA(2))  GO TO 120
      DEN(NIX(M))=DEN(NIX(M))+CF(M)
      M=M+1
      GO TO 110
C
  120 IF (M.LE.NT) GO TO 130
*     READ (NFTD,ERR=900) NT,NIJ,NIX,CF
      READ (NFTD,IOSTAT=IERR,END=990,ERR=900) NT,IROW,ICOL,NIX,CF
      M=1
      IF (NT.EQ.0) GO TO 200
C
C 130 NAB=NIJ(M)   REVISED  BY MAS BECAUSE RECORD STRUCTURE IS CHANGED
C     MA=NA(1)
C     MB=NA(2)
130   CONTINUE
      IA=IDLT(IROW(M))
      IB=IDLT(ICOL(M))
*msekiya 2005/10
*       IF (IA*IB.EQ.0) GO TO 140
*
      IF ((IA.EQ.0).OR.(IB.EQ.0)) GO TO 140
      DEN(NIX(M))=DEN(NIX(M))+CF(M)*CV(NCF+IA)*CV(NCF+IB)
  140 M=M+1
      GO TO 120
*  ******  CONVERTED   M.S.    02/09/90  ******
  200 WRITE (NFTH,ERR=910,IOSTAT=IERR) NST,DEN
C 200 WRITE (NFTH,ERR=910) NST,DEN
C  ******  CONVERTED   F.S.    13/06/80  ******
* 200 WRITE (NFTH) NST,DEN
      DO 210 I=1,LDEN
  210 DENS(I)=DENS(I)+DEN(I)
C
  300 IF (NPFLG.NE.0) GO TO 340
      CALL PRTDN (NST,NSYM,NOB,DEN)
C
  340 NCF=NCF+NKEEP
C
      IF (NSTAT.EQ.1) GO TO 342
      NST=NSTAT+1
*  ******  CONVERTED   M.S.    02/09/90  ******
      WRITE (NFTH,ERR=910,IOSTAT=IERR) NST,DENS
C     WRITE (NFTH,ERR=910) NST,DENS
C  ******  CONVERTED   F.S.    13/06/80  ******
*     WRITE (NFTH) NST,DENS
      IF (NPFLG.NE.0) GO TO 342
      CALL PRTDN  (NST,NSYM,NOB,DENS)
  342 REWIND NFTH
      REWIND NFTD
  350 RETURN
C
  401 FORMAT ('0 1ST ORDER DENSITY MATRIX ' )
  400 FORMAT ('0 1ST ORDER DENSITY MATRIX FOR', I5,2X,
     1 'STATES (THE LAST IS A SUM)')
C
*     REVISED ERROR ID#
  900 WRITE (6,920) NFTD,IERR
      NALM = 7321
      RETURN
*     GO TO 912
  990 WRITE (6,921) NFTD
  912 NALM = 7322
      RETURN
*     GO TO 350
C
  910 WRITE (6,922) NFTH,IERR
      NALM= 7331
      RETURN
*     GO TO 350
  920 FORMAT ('0 READ ERROR OF NFCID IN DENMX  UNIT = ',I4 /
     *        '       ERROR CODE IS      ',I5 )
  921 FORMAT ('0 READ ERROR OF DENMX END OF FILE  "NFCID"  UNIT = ',I4)
  922 FORMAT ('0 WRITE ERROR OF NFCIH IN DENMX  UNIT = ',I4 /
     *       '       ERROR CODE IS      ',I5 )
      END
C*DECK FIND
      SUBROUTINE FIND(NSET,IVCS)
C                                 CHECKED TASHI 10/25/89 HUCC
      DIMENSION NBF(20),NOB(20),NAME(20)
    1 FORMAT('1SET NO FOR VECTOR STORAGE TOO LARGE',/
     X       ' PLEASE CHECK YOUR INPUT OF "IND" ')
C
      GO TO 77777
      ENTRY TELL (ISET)
      RETURN
77777 CONTINUE
C
      M = 0
*     WRITE(6,*) '  DEBUG  ENTRY FIND  >> IVCS = ',IVCS,' << '
      IF (NSET-1) 203,101,102
  101 REWIND IVCS
      RETURN
  102 IF (NSET-ISET-1) 201,202,203
  201 REWIND IVCS
      GO TO 203
  202 RETURN
  203 READ (IVCS,END=301) NAME, N, NSYM, NBF, NOB
      M = M + 1
      DO 300 I = 1, NSYM
  300 IF (NOB(I)*NBF(I) .NE. 0) READ (IVCS,END=311)
      IF (N+1 .NE. NSET) GO TO 203
      RETURN
  301 IF (NSET .NE. 0) GO TO 302
      BACKSPACE IVCS
      NSET = M + 1
      RETURN
  302 WRITE (6,1)
      STOP 222
  311 WRITE (6,*)  ' READ ERROR OCCURED IN FIND  << FILE # = ',IVCS,'>>'
      STOP 230
      END
C*DECK GETVCA
      SUBROUTINE GETVCA(ISYM,IBF,IMEGU,LTRB,BUF,NRDFG)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION IBF(*),BUF(*),NBF(20),NOB(20)
      DIMENSION IND(4,100) ,IDSP(100)
      DIMENSION JBF(20)
C  MT/CGU are the M-value / GU-phase tables read from &GET and consumed
C  by WMEGU when IFLSYM=1.  They MUST be real KBASIS-sized arrays, not the
C  bare scalars they used to be: WMEGU indexes MT(LB) and CGU(IGU,LB) with
C  LB running up to KBASIS = sum of NBF over symmetries (Bucket-2B fix).
C  The CGU subscript order is (IGU,LB) to match WMEGU's own indexing --
C  the sibling routines STOVC/RMEGU use the transposed CGU(basis,IGU)
C  because their inline code indexes CGU that way; here GETVCA and its sole
C  callee WMEGU form a matched pair and must agree.  KBASIS=150 is the same
C  fixed upper bound used at cinewx.f STOVC/TRDRIV.
      PARAMETER (KBASIS=150)
      DIMENSION MT(KBASIS),CGU(2,KBASIS)
      DATA  NBASE/0/ ,IDSP/100*0/
      NAMELIST /GET/ NIND,IND,IVCS,IPAUL,NPAUL,NSHT,NSYM,NBF,NOB,NBASE,
     1       IDSP   ,MT,CGU,IFLSYM
      IFLSYM = 0
      IPAUL  = 0
      IF(NRDFG.NE.0) READ(5,GET)
      IF (IVCS .EQ. 0) RETURN
      DO 50 I = 1, NIND
      IND(1,I) = IND(1,I) + NBASE
   50 CONTINUE
    1 FORMAT('0VECTOR HISTORY'/(4I4))
      REWIND IVCS
      CALL TELL(0)
      IF (IPAUL .LT. 0) CALL RPAULC(NPAUL,IVCS,NSHT,NSYM,NBF,NOB,BUF)
      IF (IPAUL .GT. 0) CALL RPAUL(IPAUL,NPAUL,IVCS,BUF)
      IF (NIND .EQ. 0) RETURN
      WRITE (6,1) ((IND(J,I),J=1,4),I=1,NIND)
      JSYM = ISYM
      DO 60 I = 1, ISYM
   60 JBF(I) = IBF(I)
      IF (IFLSYM .NE. 2) GO TO 99
      J = 1
      DO 70 I = 1, ISYM
      JBF(J) = IBF(I)
      JBF(J+1) = IBF(I)
   70 J = J + 2
      JSYM = ISYM + ISYM
   99 L = 0
      DO 100 I = 1, ISYM
      L = MAX0(L,IBF(I)**2)
  100 CONTINUE
      CALL WMEGU(NIND,IND,JSYM,JBF,LTRB,IMEGU,IVCS,BUF,BUF(L+1),
     1           IFLSYM,MT,CGU,IDSP)
      RETURN
      END
C*DECK GINPUT
      SUBROUTINE GINPUT(NWT,IDPRNT,
     *            NPQN,NWLF,DEL,NTERM,OE,CE,
     *            INXT,ISSH,IFST,ICRNT,LMAX,Z,NAME,NFTD,LOEI)
*
*         GAUSSIAN  READ INPUT DATA
*
*         BASIC FUNCTION ... R**(L-1) * EXP( -D * R**2 ) Y(L,M)
*              ( NOTE : INPUT PRINCIPAL QUANTUM NUMBER IS REPLACED
*                       BY L-1. )
*
*                         CODED BY TASHI & MASA ON NOV.'84 AT HUCC
*                         REVISED BY TASHI         OCT.'89 AT HUCC
*
*
      IMPLICIT REAL*8(A-H,O-Z)
      CHARACTER*1 ANG(20)
      CHARACTER*8 F00,F01,F98,F99
      CHARACTER*32 FC1,FC2,FC3,FC4,FC5
      CHARACTER*144 FORM1,FORM2,FORM3,FORM4
      character * 1 lett
      DIMENSION NAME(33),ID(4)
      DIMENSION NWLF(150),DEL(150),NPQN(150),INXT(150),
     * ISSH(20),IFST(20),ICRNT(20)
**** change 1998 Jan
C     DIMENSION NTERM(150),   OE(20,150)      , CE(20,150)
      DIMENSION NTERM(150),   OE(40,150)      , CE(40,150)
*               # OF TERM , ORBITAL EXPORNENT , COEF

      DATA (ANG(I),I=1,20)
     */'S','P','D','F','G','H','I','K','L','M','N','O',
     * ' ',' ',' ',' ',' ',' ',' ',' '/
C*KGN  07/16/90 SAS  SAS
C                  1234567890123456789012345678
C  changed by msekiya at Sep. 11, 1994
      DATA F00/'(1H ,/  '/
      DATA F01/'(1H     '/
      DATA F98/'/  )    '/
      DATA F99/' )      '/

      DATA FC1/',28H          I L   SCALE FACTOR'/
      DATA FC2/',28H        ORB EXP     COEF    '/
      DATA FC3/',         I10,A2,F15.6,1X       '/
      DATA FC4/',         F15.6,1X,F11.6,1X     '/
      DATA FC5/',         28X                   '/
*
*                              *** SET INITIAL DATA ***
*
        FORM1 = F00 // FC1 // FC1 // FC1 // FC1 // F99
        FORM2 = F01 // FC2 // FC2 // FC2 // FC2 // F99
        FORM3 = F01 // FC3 // FC3 // FC3 // FC3 // F99
        NFMAX =144
*
C*KGN  07/16/90
*        IDPRNT=3
*        CALL IRDSET(IDPRNT)
        DO 2 I=1,20
          IFST(I)=0
2         ISSH(I)=0
        DO 3 I=1,150
3         INXT(I)=0
        I=0
        LMAX=0
*                               ****  START  *****
30      CONTINUE
        call readia (k, lett)
        if (lett .eq. ')') go to 120
        call dcoda (lett, k)
        if ( k.eq.0) go to 100
        IC = 1
        I=I+1
        K=K/2+1
        LMAX=MAX0(K,LMAX)
        CALL READia (NTERM(I),lett)
        if ( lett .ne. ',' ) go to 100
        CALL READfa(DEL(I)  ,lett)
        if ( lett .ne. ',' ) go to 100
        DO 40 IC = 1 , NTERM(I)
          CALL READfa(OE(IC,I),lett)
          if ( lett .ne. ',' ) go to 100
40        CONTINUE
        DO 60 IC = 1 , NTERM(I)
          CALL READfa(CE(IC,I),lett)
          if ( lett .ne. ',' ) go to 100
60        CONTINUE
C            sas      FREAD ---> READFA
        IF(ISSH(K).EQ.0) THEN
          IFST(K)=I
        ELSE
          J=ICRNT(K)
          INXT(J)=I
          END IF
        ICRNT(K)=I
        ISSH(K)=ISSH(K)+1
        NWLF(I)=K
        NPQN(I)=K
        GO TO 30
*                         *** PRINT ERROR MESAGE ***
  100   WRITE(6,9001)
        CALL NEWCD
        GO TO 30
*KGN                      *** PRINT ERROR MESAGE ***
* 120   IF(I.NE.NWT) WRITE(6,9002) I,NWT
  120   CONTINUE
        NWT=I
        CALL NEWCD
        LMAXX=LMAX-1
*
*                         *** PRINT ORBITAL INFORMATION ****
*
        WRITE(6,9003) NAME,NWT,NFTD,LOEI,LMAXX,Z
C*KGN
*       WRITE(6,9004) (ISSH(I),I=1,LMAX)
*       WRITE(6,9005) (IFST(I),I=1,LMAX)
*                         *** PRINT CGTO ***
        DO 200 J = 1 , NWT , 4
          FORM4 = F01 // FC4 // FC4 // FC4 // FC4 // F99
          NCOLM = MIN0(J+3,NWT)
          NTMIN = NTERM(J)
          DO 140 I = J + 1, NCOLM
            NTMIN = MIN0( NTMIN , NTERM(I) )
  140       CONTINUE
          IF ( NCOLM .EQ. NWT ) THEN
             NFORM = (NCOLM-J+1) * 32 + 9
             FORM1(NFORM:NFMAX) = F98
             FORM2(NFORM:NFMAX) = F98
             END IF
          WRITE(6,FORM1)
          WRITE(6,FORM3) (I,ANG(NWLF(I)),DEL(I),I=J,NCOLM)
          WRITE(6,FORM2)
          DO 150 K = 1 , NTMIN
            WRITE(6,FORM4) (OE(K,I),CE(K,I), I=J,NCOLM)
  150       CONTINUE
*          DO 170 K = NTMIN + 1 , 20
          DO 170 K = NTMIN + 1 , 40
            NFORM = 9
            NID = 0
            DO 160 I = J , NCOLM
              IF ( NTERM(I) .GE. K ) THEN
                NID = NID + 1
                ID ( NID ) = I
              ELSE
                FORM4( NFORM : NFORM+31 ) = FC5
                END IF
              NFORM = NFORM + 32
  160         CONTINUE
            IF ( NID .EQ. 0 )  GO TO 180
            WRITE ( 6, FORM4 ) (OE(K,ID(I)),CE(K,ID(I)),I=1,NID)
  170       CONTINUE
  180       CONTINUE
  200     CONTINUE
      RETURN
 9001 FORMAT('0BASORB FORMAT ERROR     ERROR   *****************')
 9002 FORMAT('0BASORB INPUT ERROR  NWTX =',I5,5X,'NWT =',I5,'   ERROR*')
 9003 FORMAT(///' INPUT BASORB       NAME',/'0',33A4,/'0NWT   =',I5,6X,
     *  'NFTD  =',I5,6X,'LOEI  =',I5,6X,'LMAXX =',I5,6X,'Z   =',F17.10)
 9004 FORMAT('0ISSH  =',20I6)
 9005 FORMAT('0IFST  =',20I6)
      END
C*DECK MODORB
      SUBROUTINE MODORB(IXT,DEL)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION DEL(2)
      RETURN
      ENTRY SETPM
      RETURN
      ENTRY GETVC
      RETURN
      END
C*DECK MOVEW
      SUBROUTINE MOVEW (NFT,NTH,NALM,NPFLG)
C                                 CHECKE TASHI 10/25/89 HUCC
      REAL*8 EDT(61)
      DIMENSION NHD(10),NHE(50)
C     EQUIVALENCE (NHD(1),ICVC),(NHD(2),NOCSF),(NHD(3),NSTAT),
C    1 (NHD(4),NSYM),(NHD(5),KDFLG(1)),(NHD(7),IDEN),(NHD(8),NKEEP),
C    2 (NHD(9),NNUC),(NHD(10),LDEN)
C
      NALM=0
      REWIND NFT
      IF (NTH.EQ.1) GO TO 40
      M=NTH-1
      IF (NTH.EQ.0) M=2000
      DO 30 I=1,M
      READ (NFT,END=50) NT,NHD,NHE,EDT
      IF (NPFLG.EQ.0) GO TO 10
      CALL PRTHD (NT,NHD,NHE,EDT)
   10 NE=0
      IF (NHD(1).NE.0) NE=NHD(3)+1
*                              NHD(3) # OF RECORDS
*                              + 1  MEANS INFORMATION OF IKEEP
      IF (NHD(7).EQ.0) GO TO 18
      NE=NE+NHD(3)
      IF (NHD(3).GT.1) NE=NE+1
*                              + 1 MEANS AVERAGED DENSITY
*                              NE  MEANS # OF SKIP RECORDS
   18 CONTINUE
      DO 20 K=1,NE
   20 READ (NFT)
   30 CONTINUE
   40 RETURN
C
   50 IF (NTH.EQ.0) GO TO 70
      NALM=1
      GO TO 40
   70 NTH=NT+1
      BACKSPACE NFT
      GO TO 40
      END
C*DECK PRCIVC
      SUBROUTINE PRCIVC (NRUN,NOCSF,NKEEP,IKEEP,NSTAT,IDTYP,THRES,
     1  IDFLG,EE,XR,EO,CIV,NSELCT)
*              REVISED BY MAS   23/11/86
*              REVISED BY TASHI 25/10/89
*    1  IDFLG,EE,ET,XR,CIV,DIV,NIT,NSELCT)
*     REVISED BY MAS 30/10/86
      IMPLICIT REAL*8  (A-H,O-Z)
      INTEGER*4 IKEEP(50,*)
      DIMENSION IDTYP(2),IDFLG(2),CIV(50,*)
C
  100 THR=0.0D0
      IF (IDTYP(1).EQ.2) THR=THRES
      IF (IDFLG(1).NE.0) GO TO 110
      NIT=0
      DIV=0.0D0
C
  110 ED=EE-XR
C*KGN
      ED2=EE-EO
C     WRITE (6,500) NRUN,NOCSF,IDTYP,NSTAT,NKEEP,IDFLG,THR
      WRITE (6,500) NRUN,NOCSF,IDTYP,NSTAT,NKEEP,NSELCT,IDFLG,THR
*     WRITE (6,510) EE,ET,XR,ED,DIV,NIT
      WRITE (6,510) EE,XR,EO,ED,ED2
C          REVISED BY MAS
C     JMAX=(NKEEP-1)/50+1
C     IMAX=NKEEP-50*(JMAX-1)
      JMAX=(NSELCT-1)/50+1
      IMAX=NSELCT-50*(JMAX-1)
      JA=1
C
  200 JB=JA+5
      IF (JB.GE.JMAX) GO TO 300
      WRITE (6,520)((IKEEP(I,J),CIV(I,J),J=JA,JB),I=1,50)
      JA=JB+1
      WRITE (6,530)
      GO TO 200
  300 IA=1
  310 DO 320 I=IA,IMAX
  320 WRITE (6,520) (IKEEP(I,J),CIV(I,J),J=JA,JMAX)
      IF (IMAX.EQ.50) GO TO 400
      IF (JA.EQ.JMAX) GO TO 400
      JMAX=JMAX-1
      IA=IMAX+1
      IMAX=50
      GO TO 310
C
  400 CONTINUE
  410 RETURN
C
  500 FORMAT ('1RUN',I7,9X,'NOCSF=',I6,8X,'IDTYP=',2I5/' STATE',I5,9X,
     1'NKEEP=',I6,'(',I5,') ',
     2'JDFLG=',2I5,5X,'THRES=',D10.2/'0',7X,'E (TOTAL)     ',
     3  6X,'E (REFERENCE)',7X,'E (H MATRIX)',
     4  8X,'E (TOTAL-REF)',7X,'E (TOTAL-H MAT)')
*    3 11X,'E (TOTAL)',7X,'E (REFERENCE)',6X,'E (DIFFERENCE)',10X,
*    4'DIVERGENCE',4X,'NO OF ITERATION')
* 510 FORMAT ('0',F19.8,4F20.8,I20/)
  510 FORMAT ('0',F19.8,4F20.8/)
  520 FORMAT((1X,6(I8,F13.5)))
  530 FORMAT ('1'/'0'/'0'/'0')
      END
C*DECK PRDINT
      SUBROUTINE PRDINT (NFTA,IA,ILST,IMIN,IMAX,NEND,XINT)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION NPAR(14),XINT(*)
C
C     NFTA          FILE NO. OF INTEGRAL TAPE
C     IA            INITIAL INDEX FOR XINT
C     ILST          DIMENSION OF XINT
C     IMIN          INITIAL INDEX OF THE CURRENT BLOCK
C     IMAX          LAST    INDEX OF THE CURRENT BLOCK
C     XINT(ILST)
C     NEND          =0,  MORE INTEGRALS
C                   =1,  END OF FILE
C                   =2,  ERROR
C                                  CHECKED TASHI 10/25/89 HUCC
C
C
      GO TO 77777
      ENTRY RDINT (IMIN,IMAX,NEND,IMAXP)
      IB=IMAX-IMAXP
      IF (IB.LE.0) GO TO 104
      IC=IMAXP-IMIN+1
      DO 102 I=1,IB
  102 XINT(I)=XINT(IC+I)
      IA=IB+1
  104 CONTINUE
      IMAX=IMAXP
      IF (NEND.EQ.1) GO TO 300
C
  110 IF (NPAR(2).EQ.NPAR(4).AND.NPAR(3).EQ.NPAR(5)) GO TO 130
      DO 120 K=KA,KB
      IB=IA+NPAR(10)-1
      IF (IB.LE.ILST) GO TO 115
      KA=K
      GO TO 200
C
  115 CALL RDIN (NFTA,XINT(IA),NPAR(10))
  120 IA=IB+1
      GO TO 100
C
  130 DO 140 K=KA,KB
      IB=IA+K-1
      IF (IB.LE.ILST) GO TO 135
      KA=K
      GO TO 200
  135 CALL RDIN (NFTA,XINT(IA),K)
  140 IA=IB+1
      GO TO 100
C
  200 IMIN=IMAX+1
      IMAX=IMIN+IA-2
      IA=1
  210 RETURN
C
  300 NEND=1
      REWIND NFTA
      GO TO 200
C
  400 NEND=2
      GO TO 210
77777 CONTINUE
C
      NEND=0
  100 READ (NFTA,END=300,ERR=400) NPAR
      KA=1
      KB=NPAR(11)
      GO TO 110
C
      END
C*DECK PRINT
      SUBROUTINE PRINT(IVCS,BUF,NPFLG)
      IMPLICIT REAL*8 (A-H,O-Z)
C        REVISED BY MAS  ( PRINTING )
C        REVISED BY TASHI       10/25/89  HUCC
      DIMENSION NBF(20),NOB(20),IND(4,100),BUF(*),NAME(20)
      REWIND IVCS
      WRITE (6,3)
 1111 READ (IVCS,END=9999) NAME, NSET, NSYM, NBF, NOB,
     1                    NIND, ((IND(J,I),J=1,4),I=1,NIND)
C     WRITE (6,1) NSET, NAME, ((IND(J,I),J=1,4),I=1,NIND)
      WRITE (6,1) NSET, NAME
      DO 100 I = 1, NSYM
      IF (NBF(I)*NOB(I) .EQ. 0) GO TO 100
      NVCC = NBF(I) * NOB(I)
      READ (IVCS) M, (BUF(J),J=1,NVCC)
*  Error detected by msekiya Sep 11, 1994
*      IF  (NPFLG.EQ.0)  GOTO 1111
      IF (NPFLG .LT. 2) GO TO 100
      WRITE (6,2) M
      CALL PRVC(BUF,NBF(I),NOB(I))
  100 CONTINUE
      IF (NPFLG .NE. 2) GO TO 101
      WRITE (6,3)
      GO TO 1111
  101 WRITE (6,4) (NBF(I),I=1,NSYM)
      WRITE (6,5) (NOB(I),I=1,NSYM)
      WRITE (6,6)
      GO TO 1111
 9999 RETURN
C   1 FORMAT(' VECTOR SET',I4,3X,20A4//(21X,4I4))
    1 FORMAT(' VECTOR SET',I4,3X,20A4)
    2 FORMAT('0SYMMETRY',I2)
    3 FORMAT('1         ')
    4 FORMAT(/18X,'NBF',20I4)
    5 FORMAT(18X,'NOB',20I4)
    6 FORMAT(///'0                  ')
      END
C*DECK PRNDN
      SUBROUTINE PRTDN (NST,NSYM,NOB,DEN)
C                                 CHECKED TASHI 10/25/89 HUCC
      REAL*8 DEN(*)
      DIMENSION NOB(NSYM)
C
      WRITE (6,100) NST
      MA=1
      DO 30 L=1,NSYM
      MD=NOB(L)
      IF(MD.EQ.0) GO TO 30
      WRITE (6,110) L
      DO 20 N=1,MD
      MB=MA+N-1
      WRITE (6,120) N, (DEN(I),I=MA,MB)
   20 MA=MB+1
   30 CONTINUE
      RETURN
C
  100 FORMAT ('0 STATE   ',I5)
  110 FORMAT ('0    SYMMETRY',I5/)
  120 FORMAT (1X,I5,10F12.8/(6X,10F12.8))
      END
C*DECK PRTHD
      SUBROUTINE  PRTHD (NSET,NHD,NHE,EDT)
C                                 CHECKED TASHI 10/25/89 HUCC
C                                 CHANGED BY MAS 11/12/92 HUCC
      REAL*8 EDT(*)
      DIMENSION NHD(10),NHE(50)
C
      WRITE (6,100)  NSET,(NHE(I),I=1,30)
      WRITE (6,101)      NHD,EDT(1)
      ND=NHD(3)+1
      WRITE (6,102) (EDT(I),I=2,ND)
      ND=NHD(4)+30
      WRITE (6,103) (NHE(I),I=31,ND)
*MAS     REVISED
*     ND=21+NHD(9)
*     WRITE (6,105) (EDT(I),I=22,ND)
*     ND=41+NHD(9)
*     WRITE (6,104) (EDT(I),I=42,ND)
      RETURN
C
  100 FORMAT ('0SET',I4,4X,30A4)
  101 FORMAT (10X,'ICVC =',I5,4X,
     1'NOCSF=',I5,4X,'NSTAT=',I5,4X,'NSYM =',
     1I5,4X,'IDFLG=',2I5/10X,'IDEN =',I5,4X,'NKEEP=',I5,4X,'NNUC =',
     2I5,4X,'LDEN =',I5,4X,'EN   =',F20.10)
  102 FORMAT (10X,'ET   =',5F20.10/(16X,5F20.10))
  103 FORMAT (10X,'NOB  =',20I5)
  104 FORMAT (10X,'CHARG=',10F10.4/(16X,10F10.4))
  105 FORMAT (10X,'XNUC =',10F10.4/(16X,10F10.4))
      END
C*DECK PRVC
      SUBROUTINE PRVC(VC,NBF,NOB)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION VC(NBF,*)
    1 FORMAT(/1X,10(I9,4X))
    2 FORMAT(1X,10F15.8)
    3 FORMAT('                         ')
      DO 100 I1 = 1, NOB, 10
      I2 = MIN0(I1+9,NOB)
      WRITE (6,1) (I,I=I1,I2)
      WRITE (6,3)
      DO 200 J = 1, NBF
      WRITE (6,2) (VC(J,I),I=I1,I2)
  200 CONTINUE
  100 CONTINUE
      RETURN
      END
C*DECK PTCPS
      SUBROUTINE PTCPS (NSYM,NBF,NOB,NTAB,EIG,C)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION NBF(*),NOB(*),NTAB(*),EIG(*),C(*)
C
      GO TO 77777
      ENTRY PTCPSB (NSYM,NBF,NOB,NTAB,EIG,C)
      NCOD=0
      GO TO 10
77777 CONTINUE
C
      NCOD=1
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
      IF (NCOD.EQ.0) GO TO 14
      WRITE (6,204) (EIG(NE+I),I=N,NC)
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
  202 FORMAT (//' ',9X,8I15)
  204 FORMAT (/' ',9X,8F15.8)
  206 FORMAT (1X)
  208 FORMAT (1X,I9,8F15.8)
C
      END
C*DECK RDCP
      SUBROUTINE RDCP  (NCOD,NSYM,NBF,NOBI,NTAB,C,NFTB,LTRB,NALM)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION NBF(*),NOBI(*),NTAB(*),C(*)
C
   10 READ  (NFTB,ERR=90) NCOD,LTRB,NSYM,(NBF(I),I=1,20),
     1     (NOBI(I),I=1,20),(NTAB(I),I=1,21)
      DO 30 L=1,NSYM
      IF (NOBI(L).EQ.0) GO TO 30
      IA=NTAB(L)
      NA=NBF(L)*NOBI(L)
      NC=IA+NA-1
      DO 20 N=1,NA,LTRB
      IB=IA+LTRB-1
      IF (IB.GT.NC) IB=NC
      READ  (NFTB,ERR=90) NT,(C(I),I=IA,IB)
   20 IA=IB+1
   30 CONTINUE
      NALM=0
   40 RETURN
C
   90 WRITE (6,91)
      NALM=1
      GO TO 40
   91 FORMAT ('1 ERROR WHILE WRITING COEF IN WRTCP')
      END
C*DECK RDIN
      SUBROUTINE RDIN (NFTA,XINT,N)
C                                 CHECKED TASHI 10/25/89 HUCC
      REAL*8 XINT(N)
C
      READ (NFTA,END=100,ERR=120,IOSTAT=IOS) (XINT(I),I=1,N)
      RETURN
100   write(6,*) ' end of file ',IOS
      STOP 
120   write(6,*) ' error ',IOS
      STOP 
      END
C*DECK RDINS
      SUBROUTINE RDINS (NFTA,XINT,NT,NALM)
C                                 CHECKED TASHI 10/25/89 HUCC
      REAL*8 XINT(NT)
C
      NALM=0
      READ (NFTA,END=200,ERR=200) NA,NB,NC,(XINT(I),I=1,NT)
  100 RETURN
C
  200 NALM=2
      GO TO 100
      END
C*DECK RDINTS
      SUBROUTINE RDINTS (NFTA,NSYM,NOB,LTRI,ILST,IA,XINT,NALM)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION NOB(*),XINT(*)
C
      DO 200 L=1,NSYM
      NINT=(NOB(L)*(NOB(L)+1))/2
      IF (NINT.EQ.0) GO TO 200
C
      DO 100 N=1,NINT,LTRI
      IB=N+LTRI-1
      IF (IB.GT.NINT) IB=NINT
      NT=IB-N+1
      IF (IA+NT.GT.ILST) GO TO 300
      CALL RDINS (NFTA,XINT(IA),NT,NALM)
      IF (NALM.NE.0) GO TO 210
  100 IA=IA+NT
C
  200 CONTINUE
  210 RETURN
C
  300 NALM=1
      GO TO 210
      END
C*DECK RDSH
      SUBROUTINE RDSH (ICWA,ICWB,NINT,XINT,NFTA,LTRI,NALM)
C                                 CHECKED TASHI 10/25/89 HUCC
C                                 CHANGED BY MAS 11/25/89 HUCC
      REAL*8 XINT(*)
C
      NALM=0
      DO 10 N=1,NINT,LTRI
      IB=N+LTRI-1
      IF (IB.GT.NINT) IB=NINT
      NT=IB-N+1
      READ (NFTA,END=20,ERR=30) NA,NB,NC,(XINT(I),I=N,IB)
      IF (NA.NE.ICWA.OR.NB.NE.ICWB.OR.NC.NE.NT) GO TO 30
   10 CONTINUE
   19 RETURN
C
   20 NALM=10
      WRITE (6,22)
   22 FORMAT ('1 END OF FILE WHILE READING SH IN TRNSH')
      GO TO 19
   30 NALM=11
      WRITE (6,32)
   32 FORMAT ('1 ERROR WHILE READING SH IN TRNSH')
      GO TO 19
      END
C*DECK RDSK
      SUBROUTINE RDSK (MTHCM,NTHCM)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      COMMON  IDSK
      DIMENSION A(2),B(2)
C
      GO TO 77777
      ENTRY STRDSK (NFD,       LPRD,NROW,NROWA,NCLMA,NPR,A,B)
      RETURN
77777 CONTINUE
C
      MA=MTHCM/NCLMA
      NN=NROW*(NTHCM-MTHCM+1)
      DO 40 L=1,NROW,NROWA
      LL=L+NROWA-1
      IF (LL.GT.NROW)  LL=NROW
      I=LPRD
      IDSK=(L/NROWA)*NPR+MA*(((LL-L+1)*NCLMA-1)/LPRD+1)+1
      DO 30 M=L,LL
      DO 20 N=M,NN,NROW
      I=I+1
      IF (I.LE.LPRD) GO TO 20
*     READ (NFD'IDSK) (A(I),I=1,LPRD)
*                CONVERTED FORT77 BY MAS 84/12/5
      READ (UNIT=NFD,REC=IDSK,ERR=1111,IOSTAT=IOSTAT)
     *                (A(I),I=1,LPRD)
       IDSK = IDSK + 1
C
      I=1
   20 B(N)=A(I)
   30 CONTINUE
   40 CONTINUE
      RETURN
1111  WRITE(6,*) 'DA FILE  READ  ERROR >>' , IOSTAT,'<<   '
      STOP 111
      END
C*DECK READT
      SUBROUTINE READT (NFTI,NRS,B)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION B(*)
C
      JA=1
      DO 10 I=1,NRS
      JB=JA+I-1
      READ (NFTI) (B(J),J=JA,JB)
   10 JA=JA+NRS
      IF (NRS.EQ.1) GO TO 40
C
      JB=NRS-1
      DO 30 I=2,NRS
      JA=I
      DO 20 J=2,I
      B(JA)=B(JB+J)
   20 JA=JA+NRS
C
   30 JB=JB+NRS
   40 RETURN
      END
C*DECK RMEGU
      SUBROUTINE RMEGU(IMEGU,NMEGU,IVCS,BUF,NIND,IIND,NAME,MOLTYP,MT,
     1                 CGU,BUF2,NPFLG)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION BUF(*),NBF(20),NOB(20),NTAB(21),IIND(4,100),NAME(20)
      DIMENSION MT(2),CGU(150,2),BUF2(*)
C
      NSET = NMEGU
      REWIND IMEGU
      CALL FIND(NSET,IVCS)
      KP = 2
   99 DO 100 K = 1, KP
      READ (IMEGU,END=999) NCOD,LTRB,NSYM,NBF,NOB,NTAB
      DO 105 I = 1, NSYM
      N = NBF(I) * NOB(I)
      IF (N .LE. 0) GO TO 105
      DO 110 J = 1, N, LTRB
  110 READ (IMEGU)
  105 CONTINUE
  100 CONTINUE
      READ (IMEGU,END=999) NCOD,LTRB,NSYM,NBF,NOB,NTAB
      WRITE (IVCS) NAME, NSET, NSYM, NBF, NOB,
     1            NIND, ((IIND(J,I),J=1,4),I=1,NIND)
      IF (NPFLG .NE. 0) GO TO 299
      WRITE (6,1) NSET, NAME, ((IIND(J,I),J=1,4),I=1,NIND)
  101 WRITE (6,4) (NBF(I),I=1,NSYM)
      WRITE (6,5) (NOB(I),I=1,NSYM)
      WRITE (6,6)
    1 FORMAT(' VECTOR SET',I4,3X,20A4//(21X,4I4))
    4 FORMAT(/18X,'NBF',20I4)
    6 FORMAT(///'0                  ')
    5 FORMAT(18X,'NOB',20I4)
  299 M = 0
      LBF = 0
      DO 300 I = 1, NSYM
      N = NBF(I) * NOB(I)
      IF (N .EQ. 0) GO TO 300
      DO 310 L1 = 1, N, LTRB
      L2 = MIN0(L1+LTRB-1,N)
      READ (IMEGU) NT, (BUF(L),L=L1,L2)
  310 CONTINUE
      IF (MOLTYP .EQ. 1) GO TO 301
      L2 = 0
      JBF = NBF(I)
      JOB = NOB(I)
      IGU = I / 2 + I / 2 - I + 2
      DO 400 J = 1, 2
      L1 = 0
      DO 410 IOB = 1, JOB
      DO 420 IBF = 1, JBF
      IF (DABS(BUF(L1+IBF)) .LT. 1.D-3) GO TO 420
      IF (DABS(BUF(L1+IBF)*CGU(LBF+IBF,IGU)+BUF(L1+MT(LBF+IBF))
     1    *CGU(LBF+MT(LBF+IBF),IGU)) .GT. 1.D-3) GO TO 421
      GO TO 410
  420 CONTINUE
  421 DO 430 IBF = 1,JBF
  430 BUF2(L2+IBF) = BUF(L1+IBF)
      L2 = L2 + JBF
  410 L1 = L1 + JBF
      IGU = 3 - IGU
  400 CONTINUE
      DO 440 L = 1, L2
  440 BUF(L) = BUF2(L)
  301 WRITE (IVCS) M, (BUF(J),J=1,N)
      LBF = LBF + NBF(I)
  300 M = M + 1
      END FILE IVCS
      KP = 1
      BACK SPACE IVCS
      NSET=NSET+1
      GO TO 99
  999 REWIND IVCS
      RETURN
      END
C*DECK RPAUL
      SUBROUTINE RPAUL(IPAUL,NPAUL,IVCS,BUF)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION BUF(2)
      DIMENSION NBF(20),NAME(20),NOB(20),NVC(20)
C
C
      I0 = 0
      DO 200 I = 1, 20
      NBF(I) = 0
  200 NOB(I) = 0
      NSET = NPAUL
      REWIND IPAUL
      CALL FIND(NSET,IVCS)
      READ (IPAUL) NAME, NSYM, NSHT, (NBF(I),I=1,NSYM)
      DO 1000 I = 1, NSHT
      LB = 0
      DO 1100 ISYM = 1, NSYM
      READ (IPAUL) ISHT, ISTAT, L, NOB(ISYM), NVCC, (BUF(LB+J),J=1,NVCC)
      LB = LB + NVCC
 1100 NVC(ISYM) = NVCC
      WRITE (IVCS) NAME, NSET, NSYM, (NBF(J),J=1,20), (NOB(J),J=1,20),
     1     (I0,J=1,5)
      L2 = 0
      DO 1200 ISYM = 1, NSYM
      L1 = L2 + 1
      L2 = L2 + NVC(ISYM)
      M = ISYM - 1
      WRITE (IVCS) M, (BUF(L),L=L1,L2)
 1200 CONTINUE
      NSET = NSET + 1
 1000 CONTINUE
*     END FILE IVCS
      REWIND IVCS
      RETURN
      END
C*DECK RPAULC
      SUBROUTINE RPAULC(NPAUL,IVCS,NSHT,NSYM,NBF,NOB,BUF)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION NBF(20),NOB(20),BUF(2),NAME(20)
C
    1 FORMAT(A8)
    2 FORMAT(2X,4(D16.8,1X)/(7X,4(D16.8,1X)))
    5 FORMAT(20A4)
      I0 = 0
      NSET = NPAUL
      CALL FIND(NSET,IVCS)
      READ (5,5) NAME
      DO 1000 I = 1, NSHT
      WRITE (IVCS) NAME, NSET, NSYM, NBF, NOB, (I0,J=1,5)
      READ (5,1) X
      DO 1100 ISYM = 1, NSYM
      READ (5,1) X
      NO = NOB(ISYM)
      NB = NBF(ISYM)
      L = 0
      DO 1200 J = 1, NO
      READ (5,2) (BUF(L+K),K=1,NB)
 1200 L = L + NB
      M = ISYM - 1
      WRITE (IVCS) M, (BUF(K),K=1,L)
 1100 CONTINUE
 1000 NSET = NSET + 1
*     END FILE IVCS
      REWIND IVCS
      RETURN
      END
C*DECK RTRIAG
      SUBROUTINE RTRIAG (MTHRW,NTHRW)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      COMMON  IDSK
      DIMENSION A(*),B(*)
C
      GO TO 77777
      ENTRY PRTRAG (NFD,       LPRD,NROW,NROWA,      NPR ,NPRA,A,B)
      RETURN
77777 CONTINUE
C
   10 MM=MTHRW/NROWA
      IDSK=MM*NPR+1
      MM=NTHRW-MTHRW+1
      NN=NROWA
      DO 40 L=1,NTHRW,NROWA
      ND=L-1
      I=LPRD
      IF (ND+NROWA.GT.NROW) NN=NROW-ND
      DO 30 M=1,MM
      DO 20 N=1,NN
      I=I+1
      IF (I.LE.LPRD) GO TO 20
*                CONVERTED FORT77 BY MAS 84/12/5
       READ (UNIT=NFD,REC=IDSK,ERR=1111,IOSTAT=IOSTAT)
     *                (A(I),I=1,LPRD)
       IDSK = IDSK + 1
C
*     READ (NFD'IDSK) (A(I),I=1,LPRD)
      I=1
   20 B(ND+N)=A(I)
   30 ND=ND+NROW
   40 CONTINUE
C
   50 IF (NTHRW.EQ.NROW) GO TO 100
      MD=MTHRW/NROWA
      LL=NTHRW+1
C
      DO 90 L=LL,NROW,NROWA
      I=LPRD
      MM=L+NROWA-1
      IF (MM.GT.NROW) MM=NROW
C
      IDSK=(L/NROWA)*NPR+MD*(((MM-L+1)*NROWA-1)/LPRD+1)+1
      DO 80 M=L,MM
      ND=M
      DO 70 N=1,NROWA
      I=I+1
      IF (I.LE.LPRD) GO TO 60
      READ (UNIT=NFD,REC=IDSK,ERR=1111,IOSTAT=IOSTAT)
     *                (A(I),I=1,LPRD)
      IDSK = IDSK + 1
C     READ (NFD'IDSK) (A(I),I=1,LPRD)
      I=1
C
   60 B(ND)=A(I)
   70 ND=ND+NROW
   80 CONTINUE
   90 CONTINUE
C
  100 RETURN
C
1111  WRITE(6,*) 'DA FILE  READ  ERROR >>' , IOSTAT,'<<   '
      STOP 111
      END
C*DECK STOVC
      SUBROUTINE STOVC(LTRB,IMEGU,NAME,NIND,IND,IVCS,NMEGU,NPFLG,
     1                 MOLTYP,MT,ICG,ICU,BUF,LBUF)
C                                 CHECKED TASHI 10/25/89 HUCC
      PARAMETER (KBASIS=150)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION BUF(*),NAME(20)
      DIMENSION IND(4,100)
      DIMENSION MT(KBASIS),ICG(KBASIS),ICU(KBASIS),CGU(KBASIS,2)
      IF (IVCS .EQ. 0) RETURN
      REWIND IMEGU
      REWIND IVCS
      CALL TELL(0)
      IF (NPFLG .EQ. 0) WRITE(6,1)
    1 FORMAT('1                        ')
      IF (MOLTYP .EQ. 1) GO TO 101
      DO 100 I = 1, 150
      CGU(I,1) = ICG(I)
  100 CGU(I,2) = ICU(I)
  101 CALL RMEGU(IMEGU,NMEGU,IVCS,BUF,NIND,IND,NAME,MOLTYP,MT,CGU,
     1           BUF(LBUF/2+1),NPFLG)
      CALL PRINT(IVCS,BUF,NPFLG)
      RETURN
      END
C*DECK TRDRIV
      SUBROUTINE TRDRIV(CR,NR,NCORGD,NRDFG,
     *                  NFTRN,NFTRC,NFAII,NFAIX,NFTRI,NFTRX,NFTRD,
     1                  LTRB1,NPFLG,NAMEC,NFLGS,NSYM,NOB,
     2                  MAXM,NBFT,NBF,NPBF,MBF,LTRA1B,NCODT,
     3                  LTRB,ITVCI,NCODC,MPOB,
     4                  ITRNS,LDSK,IERRCD)
C*KGN
      PARAMETER (KBASIS=150)
C
C          -----     MODIFIED   F.S.   81/01/28     -----
C            ERR=9000,9320  IN WRITE STATEMENTS ARE REMOVED
C
C          -----     MODIFIED   M.S.   86/12/01     -----
C          -----     MODIFIED   M.S.   88/03/01     -----
C          -----     MODIFIED   TASHI  89/10/25     -----
      IMPLICIT REAL*8 (A-H,O-Z)
      INTEGER*2 LCW(8)
      INTEGER*4 NAMEC(33)
C     DIMENSION NBF(20),NPBF(150),MBF(150),CHARG(20),NAME(33),NTABC(21),
C    1          NOB(20),MPOB(150),MOB(150),XNUC(20),
C    2          NR(NCORGD),CR(NCORGD/2)
      DIMENSION NBF(20),NPBF(KBASIS),MBF(KBASIS),CHARG(20),
     +          NAME(33),NTABC(21),
     1          NOB(20),MPOB(KBASIS),MOB(KBASIS),XNUC(20),
     2          NR(NCORGD),CR(NCORGD/2)
C     LOGICAL*1 LOG(4)
C          seems not to be utilized    SAS     94-01-07
C ADDING BY MAS 1988-03-01
C     INTEGER * 4 NPQN(150)
C     REAL    * 8 DEL (150)
      INTEGER * 4 NPQN(KBASIS)
      REAL    * 8 DEL (KBASIS)
      COMMON IDSK
      EQUIVALENCE (LCW(1),CWB1),(LCW(5),CWB2)
C     EQUIVALENCE (LOG(1),NOG),(LCW(1),CWB1),(LCW(5),CWB2)
C
      DATA      LPRDI,MXNBX/1798,200/
C
      IERRCD = 0
C     NMVL=NSYM
C     NCORGI=2*NCORGD
C
C
C      ORDERING OF INTEGRALS
C      THIS STEP IS REMOVED FROM ATOM CI
C                             81/02/10     F.S.
C      COPY RIGHT FROM ATOMCI  BY MASAHIRO S.   ON 1987-12-12  AT IMS
C
C     TRANSFORM
C
C     ITRNS :  SWITCH FOR CARD( =0 ) OR FILES( = 2 )
C
 3000 IF (ITRNS.EQ.0) GO TO 3050
      REWIND NFAII
      READ  (NFAII,ERR=9300) (NAME(I),I=1,33) ,NMVL,NBFT,NNUC,NCODT,
     1 LTRB1, (NBF(I),I=1,NMVL),(NPBF(I),I=1,NBFT),(MBF(I),I=1,NBFT),
     2 (CHARG(I),I=1,NNUC),(XNUC(I),I=1,NNUC),
     3 (NPQN(I), I=1,NBFT),(DEL (I),I=1,NBFT)
C ADDING NPQN & DEL 1988-03-01
*DEBUG  1988-03-03
*     WRITE(6,FMT='(A,20I6)')
*    *    '  NNUC>',NNUC,(CHARG(I),I=1,NNUC)
*     WRITE(6,FMT='(A,20I6)')
*    *    '  NNUC>',NNUC,(XNUC  (I),I=1,NNUC)
*     WRITE(6,FMT='(A,I6,10I10)')
*    *    '  NPQN>',NBFT,(NPQN  (I),I=1,10)
*     WRITE(6,FMT='(A,I6,10F10.3)')
*    *    '  NPQN>',NBFT,(DEL   (I),I=1,10)
*     WRITE(6,FMT='(A,20I6)')
*    *          '  FILES>',NFTRN,NFTRC,NFAII,NFAIX,NFTRI,NFTRX,NFTRD
*     WRITE(6,FMT='(A,20A6)')   '  PARAM>',
*    1                  'LTRB1','NPFLG','NFLGS',
*    2                  'MAXM','NBFT','LTRA1B','NCODT',
*    3                  'LTRB','ITVCI','NCODC',
*    4                  'ITRNS','LDSK','IERRCD'
*     WRITE(6,FMT='(A,20I6)')   '  PARAM>',
*    1                  LTRB1,NPFLG,NFLGS,
*    2                  MAXM,NBFT,LTRA1B,NCODT,
*    3                  LTRB,ITVCI,NCODC,
*    4                  ITRNS,LDSK,IERRCD
*     WRITE(6,FMT='(A,20I6)')
*    1          '  NOB>  ',NSYM,(NOB(I),I=1,NSYM)
*     WRITE(6,FMT='(A,20I6)')
*    1          '  NBF>  ',NSYM,(NBF(I),I=1,NSYM)
*DEBUG  1988-03-03
      IF (ITVCI.EQ.0) GO TO 3020
      IF (ITVCI.GE.2) GO TO 3002
      CALL GETVCA(NSYM,NBF,NFTRC,LTRB,CR,NRDFG)
 3002 REWIND NFTRC
 3010 CALL RDCP (NCODC,NMVL,NBF,NOB,NTABC,CR,NFTRC,LTRB,NALM)
      IF (NALM.NE.0) GO TO 9321
      IF (NCODC.NE.ITVCI) GO TO 3010
      GO TO 3030
C
 3020 CALL CARDVC(NFTRN,NBF,NOB,CR,NSYM)
C
 3030 IF (ITVCI.NE.0) GO TO 3040
C
  104 NTABC(1)=1
      DO 110 L=1,NSYM
  110 NTABC(L+1)=NTABC(L)+NOB(L)*NBF(L)
 3040 CONTINUE
      N=0
      NXFLG=MPOB(1)
      IF (NXFLG.EQ.0) WRITE (6,*)
     1   ' *WARNING*  MPOB NOT SPECIFIED IN &TR -- USING DEFAULT ',
     2   '(IDENTITY) ORDERING '
      DO 120 L=1,NSYM
      M=NOB(L)
      IF (M.EQ.0) GO TO 120
      DO 114 K=1,M
      N=N+1
      MOB(N)=L-1
 114  IF(NXFLG.EQ.0) MPOB(N)=K
  120 CONTINUE
      NOBT=N
C
 3050 CONTINUE
C
  200 WRITE (6,250) (NAME(I),I=1,33)
  250 FORMAT ('1',33A4)
      WRITE (6,252) NMVL,NFTRN,LTRA1B,MAXM,NFTRC,LTRB1,NBFT,NFAII,
     1      NCORGD,NNUC,NFTRI,NSYM,NFTRD,LPRDI,NOBT,MXNBX
C*KGN
      IF ( NMVL .NE. NSYM ) THEN
C*KGN    INPUT DATA ERROR
         WRITE(6,*) ' == INPUT ERROR == NSYM  == '
         WRITE(6,*) ' == NSYM  ( READING FROM AI )',NMVL
         WRITE(6,*) ' == NSYM  ( YOUR INPUT DATA )',NSYM
         WRITE(6,*) ' == PLEASE CHECK YOUT INPUT == '
         IERRCD = 4101
         RETURN
         END IF
*     WRITE (6,253) NCODT,NFLGS
      WRITE (6,254) (NBF(I),I=1,NMVL)
*     WRITE (6,256) (NPBF(I),I=1,NBFT)
*     WRITE (6,257) ( MBF(I),I=1,NBFT)
*     DELETED BY MAS       DEC.- 1 - 1986
      IF (ITRNS.EQ.0) GO TO 5000
C
  252 FORMAT ('0NMVL =',I9,8X,'NFTRN =',I9,8X,'LTRA1B =',I9/' MAXM =',
     1I9,8X,'NFTA2 =',I9,8X,'LTRB1  =',I9/' NBFT =',I9,8X,'NFAII =',I9,
     28X,'NCORGD =',I9/' NNUC =',I9,8X,'NFTRI =',I9,8X/
     3' NSYM =',I9,8X,'NFTRD =',I9,8X,'LPRDI  =',I9/
     4' NOBT =',I9,8X,'MXNBX =',I9)
  253 FORMAT ('0NCODT=',I5,8X,'NFLGS =',I5)
  254 FORMAT ('0NBF =',20I5)
*     CHANGED BY MAS
* 256 FORMAT ('0',8X,'I',6X,'NPBF',7X,'MBF'/(1X,I9,2I10))
  256 FORMAT ('0NPBF=',20I5/6X,20I5)
  257 FORMAT ('0MBF =',20I5/6X,20I5)
* 258 FORMAT ('0 CHARGE ON NUCLEUS',4X,10F10.1)
C
*     WRITE (6,269) ITVCI,NCODC,NFTRC,LTRB
      WRITE (6,260) (NOB(I),I=1,NSYM)
*     WRITE (6,261) (MPOB(I),I=1,NOBT)
*     WRITE (6,262) (MOB(I),I=1,NOBT)
      ND=NSYM+1
*     WRITE (6,263) (NTABC(I),I=1,ND)
      WRITE (6,264)
  264 FORMAT ('1 INPUT VECTORS')
      CALL PTCPSB (NSYM,NBF,NOB,NTABC,CR,CR)
  260 FORMAT ('0MOB =',20I5)
*     CHANGED BY MAS
  261 FORMAT ('0MPOB=',20I5/6X,20I5)
  262 FORMAT ('0NOB =',20I5/6X,20I5)
  263 FORMAT ('0 NTABC=',20I5)
  269 FORMAT ('0ITVCI=',I3,4X,'NCODC=',I3,4X,'NFTRC=',I3,4X,'LTRB=',I5)
C
      IF (ITRNS.EQ.1) GO TO 3300
C
      WRITE (NFTRI) (NAME(I),I=1,33),NSYM,NOBT,NNUC,NFLGS,
     1 LTRB1,(NOB(I),I=1,NSYM),(MPOB(I),I=1,NOBT),(MOB(I),I=1,NOBT),
     2 (CHARG(I),I=1,NNUC),(XNUC(I),I=1,NNUC)
C
 3300 KCR=NTABC(NSYM+1) + 2
      NCOR=NCORGD-KCR
C
 3400 KS=KCR
      KEG=KS+(NBFT*(NBFT+1))/2
      CALL NORMST (1.0D-10)
      K=0
      DO 3500 L=1,NSYM
      KSYM = L
      IF (NBF(L).EQ.0) GO TO 3500
      NT =(NBF(L)*(NBF(L)+1))/2
      CALL RDSH (1,L,NT,CR(KS),NFAII,LTRB1,NALM)
      IF (NALM.NE.0) GO TO 9322
      IF (NOB(L).EQ.0) GO TO 3500
      CALL NORM (CR(KS),CR(NTABC(L)),NBF(L),NOB(L),CR(KEG),*9323)
      IF(NXFLG.EQ.0) GO TO 3500
      NM=NOB(L)
      DO 3451 N=1,NM
      K=K+1
      NA=MPOB(K)
 3451 NPBF(NA)=N
      DO 3452 N=1,NM
      IF(NPBF(N).EQ.N) GO TO 3452
      DO 3453 NA=N,NM
 3453 IF(NPBF(NA).EQ.N) GO TO 3454
      WRITE(6,3460)
 3460 FORMAT('0INPUT MPOB ERROR')
      GO TO 9999
 3454 NPBF(NA)=NPBF(N)
      II=NTABC(L)+(N-1)*NBF(L)
      IL=II+NBF(L)-1
      ID=(NA-N)*NBF(L)
      DO 3455 I=II,IL
      X=CR(I)
      CR(I)=CR(I+ID)
 3455 CR(I+ID)= X
 3452 CONTINUE
 3500 CONTINUE
C
      WRITE (6,265)
  265 FORMAT (/' ORTHONORMALIZED VECTORS')
      CALL PTCPSB (NSYM,NBF,NOB,NTABC,CR,CR)
C**** mas
      CALL PRTTCP (NSYM,NBF,NOB,NTABC,CR,CR)
C
      REWIND NFTRC
      CALL WRTCP (    1,NSYM,NBF,NOB,NTABC,CR,NFTRC,LTRB,NALM)
      IF (NALM.NE.0) GO TO 9324
      REWIND NFTRC
C
 3530 CONTINUE
      REWIND NFAII
      READ (NFAII)
C
      IF (ITRNS.EQ.1) GO TO 4500
C
C
      CALL TRNSH (NMVL,NBF,NOB,CR,NFAII,NFTRI,LTRB1,NCOR,CR(KCR),
     1     CR(KCR),NALM)
      IF (NALM.NE.0) GO TO 9320
C
      LPRD=LPRDI/2
 4000 CALL TRNSFM (NOB,NTABC,CR,NFAII,NFTRI,NFTRD,LPRD,LDSK,
     1    NCOR,CR(KCR),NFLGS,NALM)
      IF (NALM.NE.0) GO TO 9400
      END FILE NFTRI
 4100 IF (ITRNS.EQ.2) GO TO 4400
      IF (NFTRI.EQ.NFTRX) GO TO 4200
 4110 REWIND NFTRX
 4200 WRITE (NFTRX) (NAME(I),I=1,33),NSYM,NOBT,NNUC,NFLGS,
     1 LTRB1,(NOB(I),I=1,NSYM),(MPOB(I),I=1,NOBT),(MOB(I),I=1,NOBT),
     2 (CHARG(I),I=1,NNUC),(XNUC(I),I=1,NNUC)
      IF (NFAII.EQ.NFAIX) GO TO 4300
      REWIND NFAIX
 4300 READ (NFAIX)
      CALL TRNONE (NSYM,NFAIX,NFTRX,NCOR,NALM,NBF,NOB,NTABC,
     1     NR(2*KCR-1),CR,CR(KCR))
      END FILE NFTRX
      REWIND NFAIX
      REWIND NFTRX
 4400 REWIND NFAII
      REWIND NFTRI
 4410 IF (NPFLG.EQ.0) GO TO 100
C     SWITCH FOR PRINT 100 IS RETURN
      GO TO 5000
C
 4500 IF (NFAII.NE.NFAIX) GO TO 4520
 4510 READ (NFAII,END=4530)
      GO TO 4510
 4520 REWIND NFAIX
 4530 READ (NFAIX)
      IF (NFTRI.NE.NFTRX) GOTO 4550
      READ  (NFTRI,ERR=9325) (NAME(I),I=1,33),NSYM,NOBT,NNUC,NFLGS,
     1 LTRB1,(NOB(I),I=1,NSYM),(MPOB(I),I=1,NOBT),(MOB(I),I=1,NOBT),
     2 (CHARG(I),I=1,NNUC),(XNUC(I),I=1,NNUC)
 4540 READ (NFTRI,END=4560)
      GO TO 4540
C
 4550 REWIND NFTRX
 4560 WRITE (NFTRX) (NAME(I),I=1,33),NSYM,NOBT,NNUC,NFLGS,
     1 LTRB1,(NOB(I),I=1,NSYM),(MPOB(I),I=1,NOBT),(MOB(I),I=1,NOBT),
     2 (CHARG(I),I=1,NNUC),(XNUC(I),I=1,NNUC)
      CALL TRNONE (NSYM,NFAIX,NFTRX,NCOR,NALM,NBF,NOB,NTABC,
     1     NR(2*KCR-1),CR,CR(KCR))
      END FILE NFTRX
      REWIND NFAIX
      REWIND NFTRX
      IF (NFTRI.EQ.NFTRX) GO TO 4570
      IF (NFTRI.NE.0) REWIND NFTRI
 4570 IF (NFAII.NE.NFAIX) REWIND NFAII
      GO TO 4410
C
C
C     PRINT TRANSFORMED INTEGRALS
C
 5000 IF (NPFLG.EQ.0) GO TO 100
      IF (NPFLG.EQ.1) GO TO 5060
      READ (NFTRI)
      WRITE (6,5100)
      DO 5010 L=1,NSYM
      IF (NOB(L).EQ.0) GO TO 5010
      NINT=(NOB(L)*(NOB(L)+1))/2
      CALL RDSH (1,L,NINT,CR,NFTRI,LTRB1,NALM)
      M=L-1
      WRITE (6,5102) M,(CR(I),I=1,NINT)
 5010 CONTINUE
C
      WRITE (6,5104)
      DO 5020 L=1,NSYM
      IF (NOB(L).EQ.0) GO TO 5020
      NINT=(NOB(L)*(NOB(L)+1))/2
      CALL RDSH (2,L,NINT,CR,NFTRI,LTRB1,NALM)
      M=L-1
      WRITE (6,5102) M,(CR(I),I=1,NINT)
 5020 CONTINUE
C
 5030 READ (NFTRI,END=5050) (MOB(I),I=1,14)
      WRITE (6,5106) (MOB(I),I=1,14)
      KA=MOB(11)
      KB=MOB(10)
      DO 5040 K=1,KA
      IF (MOB(12).EQ.1) KB=K
      READ (NFTRI) (CR(I),I=1,KB)
      KC=8
      IF (NPFLG.EQ.2) KC=KB
      IF (KB.LT.KC) KC=KB
      WRITE (6,5108) K, (CR(I),I=1,KC)
 5040 CONTINUE
      GO TO 5030
C
 5050 IF (NPFLG.NE.2) GO TO 5070
      REWIND NFTRI
      GO TO 100
C
 5060 IF (NFTRI.NE.NFTRX) GO TO 5070
 5062 READ (NFTRI,END=5070)
      GO TO 5060
C
 5070 READ (NFTRX)
      READ (NFTRX) NEOT,LMTAB,LC ,(NR(I),I=1,LMTAB),
     1             (CR(500+I),I=1,LC )
      WRITE (6,5110)
      MLAST=NSYM+1
      NA=0
      DO 5072 N=1,LMTAB,MLAST
      WRITE (6,5112) NA,(NR(N+I-1),I=1,MLAST)
 5072 NA=NA+1
C
      DO 5074 N=1,NEOT
      READ (NFTRX)  CWB1,CWB2,NINT,(CR(I),I=1,NINT)
      WRITE(6,5114) (LCW(I),I=1,8),NINT,(CR(I),I=1,NINT)
 5074 CONTINUE
      REWIND NFTRX
      IF (NPFLG.EQ.3.AND.NFTRI.NE.NFTRX) REWIND NFTRI
      GO TO 100
C
 5110 FORMAT ('1ONE ELECTRON INTEGRALS, MTAB'/4X,'M AND SM')
 5112 FORMAT (1X,I4,20I5)
 5114 FORMAT ('0 CODE=',2X,8I3,2X,'NO.=',I5//(1X,8D16.8))
C
 5100 FORMAT ('0 S INTEGRALS')
 5102 FORMAT ('0 M=',I3/(1X,8D15.8))
 5104 FORMAT ('0 H INTEGRALS')
 5106 FORMAT ('0 M =',5I2,4X,'MBF=',4I3,4X,'NPQ=',2I5,4X,'CODES=',3I2)
 5108 FORMAT (1X,I5,8D15.8/(6X,8D15.8))
C
 9999 RETURN
C
 9000 WRITE (6,9010)
*     IERRCD =  4010
 9010 FORMAT ('1 WRITE ERROR IN NFAII, 1ST RECORD')
      GO TO 100
C
 9100 WRITE (6,9110)
*     IERRCD =  4100
 9110 FORMAT ('1 ERROR IN ORDRSH')
      GO TO 100
C
 9200 WRITE (6,9210)
*     IERRCD =  4200
 9210 FORMAT ('1 ERROR IN ORDER')
      GO TO 100
C
 9300 WRITE (6,9310)
      IERRCD =  4300
 9310 FORMAT ('1 READ ERROR IN NFAII, 1ST RECORD')
      GO TO 100
C     ********  ADDED ERROR MESAGE 84-11-05 *****
 9320 WRITE (6,9330)
      IERRCD =  4320
 9330 FORMAT ('1 ERROR IN TRNSH')
      GO TO 100
C
 9321 WRITE (6,9331)
      IERRCD =  4321
 9331 FORMAT ('1 ERROR IN RDCP ')
      GO TO 100
C
 9322 WRITE (6,9332)
      IERRCD =  4322
 9332 FORMAT ('1 ERROR IN RDSH ')
      GO TO 100
C
 9323 WRITE (6,9333) KSYM
      IERRCD =  4323
 9333 FORMAT ('1 ERROR IN NORM  ORBITAL SYMMETRY IS ',I4)
      GO TO 100
C
 9324 WRITE (6,9334)
      IERRCD =  4324
 9334 FORMAT ('1 ERROR IN WRTCP')
      GO TO 100
C
 9325 WRITE (6,9335)
      IERRCD =  4325
 9335 FORMAT ('1 READ ERROR IN NFTRI')
      GO TO 100
C
 9400 WRITE (6,9410)
      IERRCD =  4400
 9410 FORMAT ('1 ERROR IN TRNSFM')
      GO TO 100
  100 RETURN
      END
C*DECK TRNONE
      SUBROUTINE TRNONE (NSYM,NFTA,NFTB,NCOR,NALM,NBF,NOB,NCTAB,
     1                   NR,CC,CR)
C                           CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION NBF(*),NOB(*),NCTAB(*),NR(*),CC(*),CR(*)
C
      LMVL=2*NSYM-1
      LMTA=NSYM+1
      LMTAB=LMVL*LMTA
      KMTAB=1
      KNTAB=KMTAB+LMTAB
      KMTA =KNTAB+LMTAB
      KNTA =KMTA+LMTA
      KCA  =(KNTA+LMTA)/2+2
C
      READ (NFTA,ERR=900) NOET,LNTAB,LCW,(NR(KMTAB+I-1),I=1,LNTAB),
     1                    (CR(KCA+I-1),I=1,LCW)
C
      NK=KNTAB-1
      DO 10 I=1,LMTAB
   10 NR(NK+I)=0
C
      DO 30 I=1,LMVL
      NBGN=I/2+1
      DO 20 N=NBGN,NSYM
      M=IABS(I-N)+1
      IF (N.NE.M) GO TO 15
      NR(NK+N+1 )=NR(NK+N)+(NOB(N)*(NOB(N)+1))/2
      GO TO 20
   15 NR(NK+N+1 )=NR(NK+N)+NOB(N)*NOB(M)
   20 CONTINUE
      NK=NK+LMTA
   30 CONTINUE
C
      MAXM=0
      NBGN=KMTAB+NSYM
      NLST=KMTAB+LMTAB-1
      DO 40 N=NBGN,NLST,LMTA
      IF (MAXM.LT.NR(N)) MAXM=NR(N)
   40 CONTINUE
C
      KCB=KCA+MAXM
      KCT=KCB+MAXM
      IF (NCOR.LT.KCT+2*MAXM) GO TO 910
C
C  ******  CONVERTED   F.S.    13/06/80  ******
C     WRITE (NFTB,ERR=920) NOET,LMTAB,LCW,(NR(KNTAB+I-1),I=1,LMTAB),
      WRITE (NFTB        ) NOET,LMTAB,LCW,(NR(KNTAB+I-1),I=1,LMTAB),
C  ******  CONVERTED   F.S.    13/06/80  ******
     1                     (CR(KCA+I-1),I=1,LCW)
C
      CALL TRNONA (NSYM,NOET,NFTA,NFTB,NALM,NBF,NOB,NR(KMTAB),NR(KNTAB),
     1             NCTAB,NR(KMTA),NR(KNTA),CR(KCA),CR(KCB),CC,CR(KCT))
   50 RETURN
C
  900 WRITE (6,901)
  901 FORMAT ('1 READ ERROR IN TRNONE')
      GO TO 922
  910 WRITE (6,911)
  911 FORMAT ('1 NEED MORE SPACE IN TRNONE')
      GO TO 922
C  ******  CONVERTED   F.S.    13/06/80  ******
C 920 WRITE (6,921)
C 921 FORMAT ('1 WRITE ERROR IN TRNONE')
C  ******  CONVERTED   F.S.    13/06/80  ******
  922 NALM=1
      GO TO 50
      END
C*DECK TRNSCF
      SUBROUTINE TRNSCF (NSYM,NBF,NOBI,NOBO,NTABA,CBF,NTABB,CPO,
     1                   NTABC,CPB)
C                              CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION NBF(*),NOBI(*),NOBO(*),NTABA(*),NTABB(*),NTABC(*),
     1           CBF(*),CPO(*),CPB(*)
      DATA THRS4/1.0D-10/
C
      KA=NTABC(NSYM+1)-1
      DO 10 N=1,KA
   10 CPB(N)=0.0D0
C
      DO 50 L=1,NSYM
      NBFP=NBF(L)
      NOBIP=NOBI(L)
      NOBOP=NOBO(L)
      KAI=NTABA(L)-1
      KB=NTABB(L)-1
      KC=NTABC(L)-1
      IF (NOBOP.EQ.0) GO TO 50
C
      DO 40 K=1,NOBOP
      KA=KAI
      DO 30 M=1,NOBIP
      CT=CPO(KB+M)
      IF (DABS(CT).LT.THRS4) GO TO 30
C
      DO 20 N=1,NBFP
   20 CPB(KC+N)=CT*CBF(KA+N) +CPB(KC+N)
C
   30 KA=KA+NBFP
      KB=KB+NOBIP
   40 KC=KC+NBFP
   50 CONTINUE
C
   80 RETURN
      END
C*DECK TRNSPS
      SUBROUTINE TRNSPS (NR,NC,B)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION B(*)
C                                 CHECKED TASHI 10/25/89 HUCC
      IF (NC.LE.1) GO TO 25
      NB=NR-1
      DO 20 M=2,NC
      NA=M
      DO 10 N=2,M
      T=B(NA)
      B(NA)=B(NB+N)
      B(NB+N)=T
   10 NA=NA+NR
   20 NB=NB+NR
C
   25 IF (NR.EQ.NC) GO TO 50
      NB=NC*NR
      MM=NC+1
      DO 40 M=MM,NR
      NA=M
      DO 30 N=1,NC
      B(NA)=B(NB+N)
   30 NA=NA+NR
   40 NB=NB+NR
   50 RETURN
      END
C*DECK WDSK
      SUBROUTINE WDSK (MTHRW,NTHRW)
C                              CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      COMMON  IDSK
      DIMENSION A(*),B(*)
C
      GO TO 77777
      ENTRY STWDSK (NFD,       LPRD,NROWA,NCLM,NCLMA,NPR,B,A)
      LL=NCLMA*((NCLM-1)/NCLMA )+1
      RETURN
77777 CONTINUE
C
      IDSK=(MTHRW/NROWA)*NPR+1
      LB=NCLM*(NTHRW-MTHRW+1)
      ID=NCLMA-1
      DO 30 L=1,NCLM,NCLMA
      K=0
      IF (L.EQ.LL) ID=NCLM-L
      DO 20 I=L,LB,NCLM
      IB=I+ID
      DO 20 J=I,IB
      K=K+1
      A(K)=B(J)
      IF (K.NE.LPRD) GO TO 20
*                CONVERTED FORT77 BY MAS 84/12/5
       WRITE(UNIT=NFD,REC=IDSK,ERR=1111,IOSTAT=IOSTAT)
     *                 (A(N),N=1,LPRD)
      IDSK = IDSK + 1
*     WRITE (NFD'IDSK) (A(N),N=1,LPRD)
      K=0
   20 CONTINUE
      IF (K.EQ.0) GO TO 30
       WRITE(UNIT=NFD,REC=IDSK,ERR=1111,IOSTAT=IOSTAT)
     *                 (A(N),N=1,LPRD)
      IDSK = IDSK + 1
*     WRITE (NFD'IDSK) (A(N),N=1,LPRD)
   30 CONTINUE
      RETURN
1111  WRITE(6,*) 'DA FILE  WRITE ERROR >>' , IOSTAT,'<<   '
      STOP 111
C
      END
C*DECK WMEGU
      SUBROUTINE WMEGU(NIND,IND,NSYM,NBF,LTRB,IMEGU,IVCS,BUF1,BUF2,
     1                 IFLSYM,MT,CGU,IDSP)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION IND(4,*),NBF(*),BUF1(*),BUF2(*),IDSP(*)
      DIMENSION NOB(20),NTAB(21),IBF(20),IOB(20),NAME(20)
C  MT/CGU come from GETVCA's &GET namelist.  When IFLSYM=1 the block at
C  label 2001 indexes MT(LB1) and CGU(IGU,LB2) with LB reaching KBASIS =
C  sum of NBF over symmetries, so these dummies must be KBASIS-sized, not
C  the old MT(2)/CGU(2,2) which under-declared them and produced an
C  out-of-bounds read (Bucket-2B).  CGU is (IGU,LB): phase index first,
C  basis index second -- matching GETVCA's backing array.  KBASIS=150 is
C  the same fixed upper bound used at cinewx.f STOVC/TRDRIV.
      PARAMETER (KBASIS=150)
      DIMENSION MT(KBASIS),CGU(2,KBASIS)
    1 FORMAT('1M-VALUE TOO LARGE ',4I3)
    2 FORMAT('1VECTORS NOT INT ORDER OF M-VALUES')
C  ******  CONVERTED   F.S.    13/06/80  ******
C   3 FORMAT('1BASIS SET SIZE INCONSISTENCY')
C  ******  CONVERTED   F.S.    13/06/80  ******
C  ******  CONVERTED   TASHI   25/10/89  ******
    4 FORMAT('1TOO MANY VECTORS ',4I3)
    5 FORMAT('1VECTORS NOT FOUND')
      REWIND IVCS
      REWIND IMEGU
      I1 = 1
      MMAX = NSYM - 1
      DO 100 I = 1, NSYM
  100 NOB(I) = 0
      M = 0
      N = 0
      DO 200 I = 1, NIND
      IF (IND(2,I) .GT. MMAX) GO TO 901
  201 IF (M-IND(2,I)) 202,203,902
  202 NOB(M+1) = N
      M = M + 1
      N = 0
      GO TO 201
  203 N = N + IND(4,I) - IND(3,I) + 1
  200 CONTINUE
      NOB(M+1) = N
      NTAB(1) = 1
      DO 300 I = 1, NSYM
      NTAB(I+1) = NTAB(I) + NBF(I) * NOB(I)
  300 CONTINUE
      IIND = 0
 1000 READ (IVCS,END=1998) NAME, NSET, ISYM, IBF, IOB
      DO 1100 I = 1, ISYM
      IF (IOB(I) .EQ. 0) GO TO 1100
      NVCC = IOB(I) * IBF(I)
      READ (IVCS) M, (BUF1(J),J=1,NVCC)
      L3 = 0
      DO 1200 K = 1, NIND
      IF (IND(1,K) .NE. NSET .OR. IND(2,K) .NE. M) GO TO 1201
C     IF(NBF(M+1).LT.IBF(I)+IDSP(K)) GO TO 903
      L1 = (IND(3,K) - 1) * IBF(I) + 1
      L2 = IND(4,K) * IBF(I)
      IF (L2 .GT. NVCC) GO TO 904
      LL = L3
      NBFM=NBF(M+1)
      INA=IND(4,K)-IND(3,K)+1
      DO 1300 INB=1,INA
      L=L1
      IF(IDSP(K).LT.0) L=L-IDSP(K)
      DO 1301 INC=1,NBFM
      IF(INC.LE.IDSP(K).OR.INC.GT.IBF(I)+IDSP(K)) GO TO 1302
      BUF2(LL+1) = BUF1(L)
      L=L+1
      GO TO 1301
 1302 BUF2(LL+1)=0.0D0
 1301 LL=LL+1
 1300 L1=L1+IBF(I)
      IIND = IIND + 1
 1201 L3 = L3 + (IND(4,K) - IND(3,K) + 1) * NBF(IND(2,K)+1)
      IF (IIND .EQ. NIND) GO TO 1999
 1200 CONTINUE
 1100 CONTINUE
      GO TO 1000
 1998 L3 = 0
      DO 1500 K = 1, NIND
      IF (IND(1,K) .GE. 0) GO TO 1501
      L2 = (IND(4,K) - IND(3,K) + 1) * NBF(IND(2,K)+1)
      LL = L3
      DO 1600 L = 1, L2
      BUF2(LL+1) = 0.D0
 1600 LL = LL + 1
      L2 = L3 + 1
      NB = NBF(IND(2,K)+1)
      I = IND(3,K) - 1
      DO 1700 L = L2, LL, NB
      BUF2(L+I) = 1.D0
 1700 I = I + 1
      IIND = IIND + 1
 1501 L3 = L3 + (IND(4,K) - IND(3,K) + 1) * NBF(IND(2,K)+1)
 1500 CONTINUE
      IF (IIND .LT. NIND) GO TO 905
      BACKSPACE IVCS
 1999 IF (IFLSYM .NE. 2) GO TO 1997
      NSYM = NSYM / 2
      J = 1
      DO 1990 I = 1, NSYM
      NBF(I) = NBF(J)
      NOB(I) = NOB(J) + NOB(J+1)
      NTAB(I+1) = NTAB(J+2)
 1990 J = J + 2
 1997 WRITE (IMEGU) I1, LTRB, NSYM, (NBF(I),I=1,20), (NOB(I),I=1,20),
     1     (NTAB(I),I=1,21)
      IF (IFLSYM .NE. 1) GO TO 2001
      L = 0
      LB = 0
      DO 2200 I = 1, NSYM
      NO = NOB(I)
      NB = NBF(I)
      IF (NO .LE. 0) GO TO 2200
      DO 2300 IO = 1, NO
      IGU = 1
      IF (BUF2(L+1)*BUF2(L+MT(LB+1))*CGU(1,LB+1)*CGU(1,LB+MT(LB+1))
     1        .LT. 0.D0) IGU = 2
      DO 2400 IB = 1, NB
      L1 = L + IB
      LB1 = LB + IB
      L2 = L + MT(LB1)
      LB2 = LB + MT(LB1)
      T = (BUF2(L1)*CGU(IGU,LB1) + BUF2(L2)*CGU(IGU,LB2)) * .5D0
      BUF2(L1) = T * CGU(IGU,LB1)
 2400 BUF2(L2) = T * CGU(IGU,LB2)
 2300 L = L + NB
 2200 LB = LB + NB
 2001 DO 2000 I = 1, NSYM
      L1 = NTAB(I)
      L2 = NTAB(I+1) - 1
      IF (L2 .LT. L1) GO TO 2000
      DO 2100 J1 = L1, L2, LTRB
      J2 = MIN0(J1+LTRB-1,L2)
      N = J2 - J1 + 1
      WRITE (IMEGU) N, (BUF2(J),J=J1,J2)
 2100 CONTINUE
 2000 CONTINUE
      CALL TELL(NSET)
      RETURN
  901 WRITE (6,1) (IND(J,I),J=1,4)
      STOP 111
  902 WRITE (6,2)
      STOP 111
C  ******  CONVERTED   F.S.    13/06/80  ******
C 903 WRITE (6,3)
C     STOP 111
C  ******  CONVERTED   F.S.    13/06/80  ******
  904 WRITE (6,4) (IND(J,I),J=1,4)
      STOP 111
  905 WRITE (6,5)
      STOP 111
      END
C*DECK WRTCP
      SUBROUTINE WRTCP (NCOD,NSYM,NBF,NOBI,NTAB,C,NFTB,LTRB,NALM)
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION NBF(*),NOBI(*),NTAB(*),C(*)
C
C  ******  CONVERTED   F.S.    13/06/80  ******
C  ******  CONVERTED   TASHI   25/10/89  ******
C  10 WRITE (NFTB,ERR=90) NCOD,LTRB,NSYM,(NBF(I),I=1,20),
   10 WRITE (NFTB       ) NCOD,LTRB,NSYM,(NBF(I),I=1,20),
C  ******  CONVERTED   F.S.    13/06/80  ******
     1     (NOBI(I),I=1,20),(NTAB(I),I=1,21)
      DO 30 L=1,NSYM
      IF (NOBI(L).EQ.0) GO TO 30
      IA=NTAB(L)
      NA=NBF(L)*NOBI(L)
      NC=IA+NA-1
      DO 20 N=1,NA,LTRB
      IB=IA+LTRB-1
      IF (IB.GT.NC) IB=NC
      NT=IB-IA+1
C  ******  CONVERTED   F.S.    13/06/80  ******
C     WRITE (NFTB,ERR=90) NT,(C(I),I=IA,IB)
      WRITE (NFTB       ) NT,(C(I),I=IA,IB)
C  ******  CONVERTED   F.S.    13/06/80  ******
   20 IA=IB+1
   30 CONTINUE
      NALM=0
   40 RETURN
C
C  ******  CONVERTED   F.S.    13/06/80  ******
C  90 WRITE (6,91)
C     NALM=1
C     GO TO 40
C  91 FORMAT ('1 ERROR WHILE WRITING COEF IN WRTCP')
C  ******  CONVERTED   F.S.    13/06/80  ******
      END
C*DECK WRTSH
      SUBROUTINE WRTSH (ICWA,ICWB,NINT,XINT,NFTB,LTRI,NALM)
C                                 CHECKED TASHI 10/25/89 HUCC
      REAL*8 XINT(*)
C
      DO 10 N=1,NINT,LTRI
      IB=N+LTRI-1
      IF (IB.GT.NINT) IB=NINT
      NT=IB-N+1
C  ******  CONVERTED   F.S.    13/06/80  ******
C     WRITE (NFTB,ERR=20) ICWA,ICWB,NT,(XINT(I),I=N,IB)
      WRITE (NFTB) ICWA,ICWB,NT,(XINT(I),I=N,IB)
C  ******  CONVERTED   F.S.    13/06/80  ******
   10 CONTINUE
      RETURN
C  ******  CONVERTED   F.S.    13/06/80  ******
C  20 NALM=3
C     WRITE (6,30)
C  30 FORMAT ('1 ERROR WHILE WRITING S,H INTEGRALS IN WRTSH')
C     RETURN
C  ******  CONVERTED   F.S.    13/06/80  ******
      END
C*DECK WTRIAG
      SUBROUTINE WTRIAG (NFT,NFD,      LPRD,NROW,NROWA,NPR,A,B)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      COMMON  IDSK
      DIMENSION A(*),B(*)
C
      DO 70 L=1,NROW,NROWA
      LL=L+NROWA-1
      IF (LL.GT.NROW) LL=NROW
      IA=1
      DO 20 M=L,LL
      IB=IA+M-1
      READ (NFT) (B(I),I=IA,IB)
   20 IA=IA+NROW
      IB=NROW-1
      MA=L+1
      DO 26 M=MA,LL
      IA=M
      DO 24 N=MA,M
      B(IA)=B(IB+N)
   24 IA=IA+NROW
   26 IB=IB+NROW
C
   30 IDSK=(L/NROWA)*NPR+1
      MM=LL-L+1
      DO 60 K=1,LL,NROWA
      ND=K-1
      I=0
      NN=NROWA
      IF (K+NROWA.GT.NROW) NN=NROW-ND
      DO 50 M=1,MM
      DO 40 N=1,NN
      I=I+1
      A(I)=B(ND+N)
      IF (I.NE.LPRD) GO TO 40
*                CONVERTED FORT77 BY MAS 84/12/5
       WRITE(UNIT=NFD,REC=IDSK,ERR=1111,IOSTAT=IOSTAT)
     *                 (A(I),I=1,LPRD)
       IDSK = IDSK + 1
*     WRITE (NFD'IDSK) (A(I),I=1,LPRD)
      I=0
   40 CONTINUE
   50 ND=ND+NROW
      IF (I.EQ.0) GO TO 60
       WRITE(UNIT=NFD,REC=IDSK,ERR=1111,IOSTAT=IOSTAT)
     *                 (A(I),I=1,LPRD)
*   ERROR           BY MAS 1988/02/17    !!!!
       IDSK = IDSK + 1
*     WRITE (NFD'IDSK) (A(I),I=1,LPRD)
   60 CONTINUE
   70 CONTINUE
      RETURN
1111  WRITE(6,*) 'DA FILE  WRITE ERROR >>' , IOSTAT,'<<   '
      STOP 111
C
      END
