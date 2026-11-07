C*DECK ATREAD                                                           ATL00010
      SUBROUTINE ATREAD(NFT05,NPRTY,MOCCN,NORBT,NSCHL,                  ATL00020
     *                  CORBT,CSCHL,NAMSL,TIT80,TIT01,NKIND,            ATL00030
     *                  MKIND,MSCHL,NCLET,MBORB,                        ATL00040
     *                                          LPOUT)                  ATL00050
C================================================================       ATL00060
C  ATREAD                                                               ATL00070
C     GET INPUT DATA AND PRISET                                         ATL00080
C                           CODED U.NAGASHIMA                           ATL00090
C                           CHECKED TASHI                               ATL00100
C================================================================       ATL00110
C     CALLED  SUBROUTINE                                                ATL00120
C     ATGDRV                                                            ATL00130
C================================================================       ATL00140
C     CALLING SUBROUTINE                                                ATL00150
C================================================================       ATL00160
C   INPUT DATA                                                          ATL00170
C   RULE                                                                ATL00180
C    1) COMMENT RECORD HAS ' OR " CHARACTER IN 1ST COLUMM.              ATL00190
C    2) INPUT DATA ARE ALL FREE FORMAT.                                 ATL00200
C    3) THREE KINDS OF DATA IS READ IN THIS SUBROUTINE                  ATL00210
C       A) NUMBER OF S,P,D,F,G,H... ORBITALS                            ATL00220
C       B) COUPLING SCHIME OF REFERENCE CONF.                           ATL00230
C       C) REFERENCE CONFIGURATIONS                                     ATL00240
C    4) THE END OF EACH DATA IS INDICATED BY ))).                       ATL00250
C----------------------------------------------------------------       ATL00260
C     EXSAMPLE AND EXPLANATION OF INPUT DATA                            ATL00270
C                                                                       ATL00280
C  0--------1---------2---------3---------4---------5                   ATL00290
C  ' INPUT DATA FOR ATGEN PROGRAM             ---- COMMENT              ATL00300
C  ' NUMBER OF S,P,D,F,G,H... ORBITALS WITHOUT CORE  ---- COMMENT       ATL00310
C    6S 4P 3D 3F 2G)))                                                  ATL00320
C  ' COUPLING SCHIME OF REFERENCE             ---- COMMENT              ATL00330
C     4S 5S 4P 3D)))                                                    ATL00340
C  ' REFERENCE CONFIGURATIONS                 ---- COMMENT              ATL00350
C   3D*10) 4S*2))                             ---- 1ST REFERENCE        ATL00360
C   3D*10) 5S*2))                             ---- 2ND REFERENCE        ATL00370
C   3D*10) 4P*2)))                            ---- 3RD REFERENCE & END  ATL00380
C  ' END                                                                ATL00390
C================================================================       ATL00400
C   ----- ARREY (GIVEN) -----                                           ATL00410
C   NFT05  : LOGICAL UNIT NUMBER OF NFT05                   I4          ATL00420
C   TIT80  : READING BUFFER                                C80          ATL00430
C   TIT01  : READING BUFFER                              80*C1          ATL00440
C   MKIND  : MAX NUMBER OF ORBUTAL KIND                     I4          ATL00450
C   MBORB  : MAX NUMBER OF ORBUTAL IN EACH SCHELL           I4          ATL00460
C   NCLET  : MKIND+2                                        I4          ATL00470
C   LPOUT  : DEBUG FLAG                                     I4          ATL00480
C                                                                       ATL00490
C   ----- ARREY (RETURN)-----                                           ATL00500
C   NPRTY  : PARITY OF  S,P,D,F..ORBITALS                MKIND*I4       ATL00510
C   MOCCN  : MAXIMUM NUMBERS OF S,P,D,F..SCHELLS         MKIND*I4       ATL00520
C   NORBT  : NUMBERS OF S,P,D,F..SCHELLS                 MKIND*I4       ATL00530
C   NSCHL  : NUMBERS OF S,P,D,F..SCHELLS                 MKIND*I4       ATL00540
C   NAMSL  : NAME OF EACH SCHELL                        MBORB*MKIND     ATL00550
C   CORBT  : CHARACTER OF  'S','P','D',                   8*C1          ATL00560
C   NKIND  : ACTUAL NUMBERS OF ORBITAL KINDS                I4          ATL00570
C   MSCHL  : TOTAL  NUMBERS OF SCHELL                       I4          ATL00580
C================================================================       ATL00590
      CHARACTER TIT80*80,TIT01(80)*1,C10*10,CORBT(NCLET)*1,APO*1        ATL00600
      CHARACTER NAMSL(MBORB,MKIND)*2,CSCHL(MBORB*MKIND)*2               ATL00610
      DIMENSION NPRTY(MKIND),MOCCN(MKIND),NORBT(MKIND)                  ATL00620
      DIMENSION NSCHL(MKIND)                                            ATL00630
      INTEGER * 4 WFEEST,IOSTAT                                         ATL00640
      DATA APO/1H'/                                                     ATL00650
      IF(LPOUT.GT.0) CALL ATBIGN('ATREAD')                              ATL00660
      DO 10 I=1,MKIND                                                   ATL00670
   10    CORBT(I)=' '                                                   ATL00680
      CORBT(1)='S'                                                      ATL00690
      CORBT(2)='P'                                                      ATL00700
      CORBT(3)='D'                                                      ATL00710
      CORBT(4)='F'                                                      ATL00720
      CORBT(5)='G'                                                      ATL00730
      CORBT(6)='H'                                                      ATL00740
      CORBT(7)='I'                                                      ATL00750
      CORBT(8)='K'                                                      ATL00760
      CORBT(9)='L'                                                      ATL00770
      CORBT(10)='M'                                                     ATL00780
      CORBT(11)=' '                                                     ATL00790
      CORBT(12)=')'                                                     ATL00800
      IF(LPOUT.GT.5) THEN                                               ATL00810
         WRITE(6,*) '  ============================================='   ATL00820
         WRITE(6,*) '  = INPUT DATA                                ='   ATL00830
         WRITE(6,*) '  ============================================='   ATL00840
         WRITE(6,'(10X,''1'',8(''-''),I1,6(9(''-''),I1))')              ATL00850
     *        (I,I=1,7)                                                 ATL00860
         ENDIF                                                          ATL00870
      TIT80(73:80) = '        '                                         ATL00880
      NSTEP= 1                                                          ATL00890
      WFEEST=-1                                                         ATL00900
   20 READ(NFT05,'(72A1)',END=90,ERR=99) (TIT01(JJ),JJ=1,72)            ATL00910
*  20 READ(NFT05,'(A80)',END=90,ERR=99) TIT80                           ATL00920
      IF(LPOUT.GT.5) THEN                                               ATL00930
         WRITE(6,'(''  =DATA=  '',72A1)') ( TIT01(JJ),JJ=1,72 )         ATL00940
*        WRITE(6,'(''  =DATA=  '',A80)') TIT80                          ATL00950
         ENDIF                                                          ATL00960
      IF((TIT01(1).EQ.APO).OR.                                          ATL00970
     *   (TIT01(1).EQ.'"')) GO TO 20                                    ATL00980
C ------- INPUT DATA &WFEE --- CODED BY MAS -------------------         ATL00990
                                                                        ATL01000
      IF(NSTEP.EQ. 0) THEN                                              ATL01010
         IF (TIT80(2:4).EQ.'&WF') THEN                                  ATL01020
C           WRITE(7,'(A80)',ERR=98,IOSTAT=IOSTAT) TIT80                 ATL01030
            WFEEST = INDEX(TIT80,'&END')                                ATL01040
            IF ( WFEEST.GT.0) NSTEP = 1                                 ATL01050
            GO TO 20                                                    ATL01060
         ELSE IF (WFEEST.LT.0) THEN                                     ATL01070
            GO TO 20                                                    ATL01080
         ELSE IF (WFEEST.GE.0) THEN                                     ATL01090
C           WRITE(7,'(A80)',ERR=98,IOSTAT=IOSTAT) TIT80                 ATL01100
            WFEEST = INDEX(TIT80,'&END')                                ATL01110
            IF ( WFEEST.GT.0) NSTEP = 1                                 ATL01120
            GO TO 20                                                    ATL01130
            END IF                                                      ATL01140
         END IF                                                         ATL01150
C ------- NO. OF S,P,D,F... ORBITALS ---------------------------        ATL01160
      IF(NSTEP.EQ.1) THEN                                               ATL01170
         NA=INDEX(TIT80,')))')                                          ATL01180
         IF(NA.EQ.0) NA=72                                              ATL01190
         NKIND=0                                                        ATL01200
         KPREV=0
         I=1                                                            ATL01210
   30    IF(TIT01(I).NE.' ') THEN                                       ATL01220
            IB=I                                                        ATL01230
   32       I=I+1                                                       ATL01240
            IF(I.GE.NA) GO TO 38                                        ATL01250
            KIND=1                                                      ATL01260
            KM=1                                                        ATL01270
            DO 36 K=1,MKIND                                             ATL01280
               IF(TIT01(I).EQ.CORBT(K)) THEN                            ATL01290
                  IE=I-1                                                ATL01300
                  C10=TIT80(IB:IE)                                      ATL01310
                  IF(KIND.LT.K) KIND=K                                  ATL01320
                  IF(KIND.GT.MKIND) GO TO 92                            ATL01330
                  IF(K.LE.KPREV) GO TO 93
                  KPREV=K
                  READ(C10,*) NORBT(K)                                  ATL01340
                  KM=2                                                  ATL01350
                  ENDIF                                                 ATL01360
   36          CONTINUE                                                 ATL01370
            IF(KM.EQ.1) GO TO 32                                        ATL01380
            IF(I.GT.NA) GO TO 38                                        ATL01390
            ENDIF                                                       ATL01400
            I=I+1                                                       ATL01410
            GO TO 30                                                    ATL01420
   38    IF(INDEX(TIT80,')))').NE.0) NSTEP=2                            ATL01430
         GO TO 20                                                       ATL01440
         ENDIF                                                          ATL01450
C ------- NPRTY AND MOCCN            ---------------------------        ATL01460
      IF(KIND.GT.NKIND) NKIND=KIND                                      ATL01470
      KK=NKIND                                                          ATL01480
      IF(MOD(KK,2).NE.0) KK=KK+1                                        ATL01490
      DO 40 I=1,KK,2                                                    ATL01500
         NPRTY(I)=1                                                     ATL01510
   40    NPRTY(I+1)=-1                                                  ATL01520
      DO 42 I=4,MKIND                                                   ATL01530
         NSCHL(I)=0                                                     ATL01540
   42    MOCCN(I)=50                                                    ATL01550
      MOCCN(1)=2                                                        ATL01560
      MOCCN(2)=6                                                        ATL01570
      MOCCN(3)=10                                                       ATL01580
*  bug fix by msekiya at  2/20/96
      MOCCN(4)=14                                                       ATL01580
      MOCCN(5)= 2                                                       ATL01580
      MOCCN(6)= 2                                                       ATL01580
      MOCCN(7)= 2                                                       ATL01580
C ------- COUPLING SCHIME --------------------------------------        ATL01590
      IF(NSTEP.EQ.2) THEN                                               ATL01600
         NA=INDEX(TIT80,')))')                                          ATL01610
         IF(NA.EQ.0) NA=72                                              ATL01620
         I=1                                                            ATL01630
   50    IF(TIT01(I).NE.' ') THEN                                       ATL01640
            IB=I                                                        ATL01650
   52       I=I+1                                                       ATL01660
            IF(I.GE.NA) GO TO 55                                        ATL01670
            KM=1                                                        ATL01680
            DO 54 K=1,NKIND                                             ATL01690
               IF(TIT01(I).EQ.CORBT(K)) THEN                            ATL01700
                  IE=I                                                  ATL01710
C Validation: NAMSL is
C CHARACTER*2 -- a CARD-2 label longer than 2 characters (e.g. '10M',
C the lowest physically-valid M-kind label) silently truncates on
C assignment, dropping the kind letter. Reject instead of truncating.
                  IF(IE-IB+1.GT.2) GO TO 96
                  NSCHL(K)=NSCHL(K)+1                                   ATL01720
                  NAMSL(NSCHL(K),K)=TIT80(IB:IE)                        ATL01730
                  KM=2                                                  ATL01740
                  ENDIF                                                 ATL01750
   54          CONTINUE                                                 ATL01760
            IF(KM.EQ.1) GO TO 52                                        ATL01770
            IF(I.GT.NA) GO TO 55                                        ATL01780
            ENDIF                                                       ATL01790
            I=I+1                                                       ATL01800
            GO TO 50                                                    ATL01810
   55       CONTINUE                                                    ATL01820
         IF(INDEX(TIT80,')))').NE.0) THEN                               ATL01830
            NSTEP=3                                                     ATL01840
            MSCHL=0                                                     ATL01850
            DO 56 J=1,NKIND                                             ATL01860
               NSCHL(J)=NSCHL(J)+1                                      ATL01870
               NAMSL(NSCHL(J),J)='N'//CORBT(J)                          ATL01880
   56          MSCHL=NSCHL(J)+MSCHL                                     ATL01890
            GO TO 90                                                    ATL01900
            ENDIF                                                       ATL01910
         GO TO 20                                                       ATL01920
         ENDIF                                                          ATL01930
   90 CONTINUE                                                          ATL01940
      IF(NSTEP.LT.3) GO TO 92                                           ATL01950
                                                                        ATL01960
* STORE NAMSL TO CSCHL BY MAS                                           ATL01970
      KK = 0                                                            ATL01980
      DO 110 I = 1, NKIND                                               ATL01990
         DO 110 J = 1, NSCHL(I)                                         ATL02000
            KK = KK + 1                                                 ATL02010
110         CSCHL(KK) = NAMSL(J,I)                                      ATL02020
* STORE NAMSL TO CSCHL BY MAS                                           ATL02030
      IF(LPOUT.GT.30) THEN                                              ATL02040
C        WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATREAD ********'     ATL02050
C        WRITE(6,'(2X,''MKIND,NKIND,MSCHL,NSTEP = '',4I5)')             ATL02060
C    *                  MKIND,NKIND,MSCHL,NSTEP                         ATL02070
C        WRITE(6,'(2X,''NPRTY = '',10I4)') (NPRTY(I),I=1,NKIND)         ATL02080
C        WRITE(6,'(2X,''MOCCN = '',10I4)') (MOCCN(I),I=1,NKIND)         ATL02090
C        WRITE(6,'(2X,''NORBT = '',10I4)') (NORBT(I),I=1,NKIND)         ATL02100
C        WRITE(6,'(2X,''NSCHL = '',10I4)') (NSCHL(I),I=1,NKIND)         ATL02110
C        WRITE(6,'(2X,''CORBT =  '',10(2X,A1,1X)') (CORBT(I),I=1,NKIND) ATL02120
C        WRITE(6,'(2X,''NAMSL =  '',10(1X,A2,1X)')                      ATL02130
C    *        (NAMSL(J,1),J=1,NSCHL(1))                                 ATL02140
C        DO 91 I=2,NKIND                                                ATL02150
C  91    WRITE(6,'(2X,''         '',10(1X,A2,1X)')                      ATL02160
C    *        (NAMSL(J,I),J=1,NSCHL(I))                                 ATL02170
         ENDIF                                                          ATL02180
      IF(LPOUT.GT.0) CALL ATENDS('ATREAD')                              ATL02190
      RETURN                                                            ATL02200
   92 CONTINUE                                                          ATL02210
      WRITE(6,*) ' **************************************************'  ATL02220
      WRITE(6,*) ' ** ERROR STOP IN SUB.ATREAD                     **'  ATL02230
      WRITE(6,*) ' **************************************************'  ATL02240
      WRITE(6,*) ' - INPUT DATA ARE NOT COMPLEAT. CHECK YOUR DATA. -'   ATL02250
      WRITE(6,*) ' - PROCESS IS ABEND.                             -'   ATL02260
      WRITE(6,*) '   STEP,NKIND= ',NSTEP,NKIND                          ATL02270
      STOP 920                                                          ATL02280
C Validation: NKIND is
C derived from the LAST CARD-1 token matched, not a running maximum, so
C CARD 1 must list its symmetry-kind tokens in strictly ascending order
C (S,P,D,F,...) or NKIND silently comes out wrong. Reject instead.
   93 CONTINUE
      WRITE(6,*) ' **************************************************'
      WRITE(6,*) ' ** ERROR STOP IN SUB.ATREAD                     **'
      WRITE(6,*) ' **************************************************'
      WRITE(6,*) ' - CARD 1 KIND TOKENS ARE NOT STRICTLY ASCENDING.-'
      WRITE(6,*) ' - EXPECTED ORDER: S,P,D,F,G,H,I,K,L,M (ASCENDING) -'
      WRITE(6,*) ' - PROCESS IS ABEND.                             -'
      WRITE(6,*) ' - TOKEN KIND =',CORBT(K),' PREVIOUS KIND =',
     *           CORBT(KPREV)
      STOP 921
C Validation: a CARD-2
C label rendered to more than 2 characters (NAMSL is CHARACTER*2).
   96 CONTINUE
      WRITE(6,*) ' **************************************************'
      WRITE(6,*) ' ** ERROR STOP IN SUB.ATREAD                     **'
      WRITE(6,*) ' **************************************************'
      WRITE(6,*) ' - CARD 2 LABEL EXCEEDS THE 2-CHARACTER FIELD.   -'
      WRITE(6,*) ' - (E.G. A KIND M SHELL NUMBERED 10 OR HIGHER).  -'
      WRITE(6,*) ' - PROCESS IS ABEND.                             -'
      WRITE(6,*) '   KIND =',CORBT(K),' LABEL =',TIT80(IB:IE)
      STOP 925
   98 CONTINUE                                                          ATL02290
      WRITE(6,*) ' **************************************************'  ATL02300
      WRITE(6,*) ' ** ERROR STOP IN SUB.ATREAD                     **'  ATL02310
      WRITE(6,*) ' **************************************************'  ATL02320
      WRITE(6,*) ' - WRITE ERROR OCCUERD IN UNIT 7                 -'   ATL02330
      WRITE(6,*) ' - PROCESS IS ABEND.                             -'   ATL02340
      WRITE(6,*) ' - STEP,NKIND  = ',NSTEP,NKIND                        ATL02350
      WRITE(6,*) ' - RETURN CODE IS',IOSTAT                             ATL02360
      STOP 980                                                          ATL02370
   99 CONTINUE                                                          ATL02380
      WRITE(6,*) ' **************************************************'  ATL02390
      WRITE(6,*) ' ** ERROR STOP IN SUB.ATREAD                     **'  ATL02400
      WRITE(6,*) ' **************************************************'  ATL02410
      WRITE(6,*) ' - SOME ERROR DITECTED ON NFT05.CHECK YOUR DATA. -'   ATL02420
      WRITE(6,*) '  NFT05= ',NFT05                                      ATL02430
      STOP 990                                                          ATL02440
      END                                                               ATL02450
C*DECK ATMEMB                                                           ATL02460
*============*                                                          ATL02470
*= ATMEMB   =* REVISED BY MAS   APR. 15  1987                           ATL02480
*============* CHECKED BY TASHI OCT. 27  1989                           ATL02490
      SUBROUTINE ATMEMB(NKIND,MSCHL,MSCH2,MCONF,KCONF,                  ATL02500
     *                  NTOPN,NORTS,NBORB,NSTOR,MAXOC,NRTAB,NCONF,      ATL02510
     *                  LLOPN,LLRTS,LLORB,LLTOR,LLXOC,LLTAB,LLONF,      ATL02520
     *                  MXREF,NREFN,NSCON,LPOUT)                        ATL02530
      DIMENSION NRTAB(MSCH2,NREFN),NTOPN(NKIND)                         ATL02540
      DIMENSION NORTS(2,NKIND),NBORB(2,MSCH2)                           ATL02550
      DIMENSION NCONF(MSCH2,KCONF),NSTOR(MSCHL),MAXOC(MSCHL)            ATL02560
      DIMENSION LLTAB(MSCH2,MXREF),LLOPN(NKIND)                         ATL02570
      DIMENSION LLRTS(2,NKIND),LLORB(2,MSCH2)                           ATL02580
      DIMENSION LLONF(MSCH2,MCONF),LLTOR(MSCHL),LLXOC(MSCHL)            ATL02590
      IF(LPOUT.GT.0) CALL ATBIGN('ATMEMB')                              ATL02600
      IF(LPOUT.GT.50) THEN                                              ATL02610
         WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATMEMB ********'     ATL02620
         WRITE(6,*) ' ** GIVEN     PARAMETERS ARE FOLLOWING     **'     ATL02630
C        WRITE(6,'(2X,''NKIND,MSCHL,MSCH2,MCONF = '',4I5)')             ATL02640
C    *                  NKIND,MSCHL,MSCH2,MCONF                         ATL02650
C        WRITE(6,'(2X,''KCONF,MXREF,NREFN,NSCON = '',4I5)')             ATL02660
C    *                  KCONF,MXREF,NREFN,NSCON                         ATL02670
C        WRITE(6,'(2X,''NTOPN = '',15I4)') (LLOPN(I),I=1,NKIND)         ATL02680
C        WRITE(6,'(2X,''NORTS = '',15I4)') (LLRTS(1,I),I=1,NKIND)       ATL02690
C        WRITE(6,'(2X,''        '',15I4)') (LLRTS(2,I),I=1,NKIND)       ATL02700
C        WRITE(6,'(2X,''NBORB = '',15I4)') (LLORB(1,I),I=1,MSCHL)       ATL02710
C        WRITE(6,'(2X,''        '',15I4)') (LLORB(2,I),I=1,MSCHL)       ATL02720
C        WRITE(6,'(2X,''NSTOR = '',15I4)') (LLTOR(I),I=1,MSCHL)         ATL02730
C        WRITE(6,'(2X,''MAXOC = '',15I4)') (LLXOC(I),I=1,MSCHL)         ATL02740
         J=1                                                            ATL02750
C        WRITE(6,'(/1X,''NRTAB = '',I5,5X,15I4)')                       ATL02760
C    *         J,(LLTAB(I,J),I=1,MSCH2)                                 ATL02770
C        DO 10 J=2,NREFN                                                ATL02780
C  10       WRITE(6,'(1X,''        '',I5,5X,15I4)')                     ATL02790
C    *            J,(LLTAB(I,J),I=1,MSCH2)                              ATL02800
         J=1                                                            ATL02810
C        WRITE(6,'(1X,''NCONF = '',I10,15I4)')                          ATL02820
C    *         J,(LLONF(I,J),I=1,MSCH2)                                 ATL02830
C        DO 12 J=2,NSCON                                                ATL02840
C  12       WRITE(6,'(1X,''        '',I10,15I4)')                       ATL02850
C    *            J,(LLONF(I,J),I=1,MSCH2)                              ATL02860
         ENDIF                                                          ATL02870
      DO 14 I=1,NKIND                                                   ATL02880
   14    NTOPN(I)=LLOPN(I)                                              ATL02890
      DO 20 I=1,NKIND                                                   ATL02900
         NORTS(1,I)=LLRTS(1,I)                                          ATL02910
   20    NORTS(2,I)=LLRTS(2,I)                                          ATL02920
      DO 22 I=1,MSCH2                                                   ATL02930
         NBORB(1,I)=LLORB(1,I)                                          ATL02940
         NBORB(2,I)=LLORB(2,I)                                          ATL02950
   22    CONTINUE                                                       ATL02960
      DO 24 I=1,MSCHL                                                   ATL02970
   24    NSTOR(I)=LLTOR(I)                                              ATL02980
      DO 26 I=1,MSCHL                                                   ATL02990
   26    MAXOC(I)=LLXOC(I)                                              ATL03000
      DO 30 I=1,NREFN                                                   ATL03010
         DO 28 J=1,MSCH2                                                ATL03020
   28       NRTAB(J,I)=LLTAB(J,I)                                       ATL03030
   30    CONTINUE                                                       ATL03040
      DO 34 I=1,NSCON                                                   ATL03050
         DO 32 J=1,MSCH2                                                ATL03060
   32       NCONF(J,I)=LLONF(J,I)                                       ATL03070
   34    CONTINUE                                                       ATL03080
      IF(LPOUT.GT.30) THEN                                              ATL03090
C        WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATMEMB ********'     ATL03100
C        WRITE(6,*) ' ** COPIED    PARAMETERS ARE FOLLOWING     **'     ATL03110
C        WRITE(6,'(2X,''NTOPN = '',15I4)') (NTOPN(I),I=1,NKIND)         ATL03120
C        WRITE(6,'(2X,''NORTS = '',15I4)') (NORTS(1,I),I=1,NKIND)       ATL03130
C        WRITE(6,'(2X,''        '',15I4)') (NORTS(2,I),I=1,NKIND)       ATL03140
C        WRITE(6,'(2X,''NBORB = '',15I4)') (NBORB(1,I),I=1,MSCHL)       ATL03150
C        WRITE(6,'(2X,''        '',15I4)') (NBORB(2,I),I=1,MSCHL)       ATL03160
C        WRITE(6,'(2X,''NSTOR = '',15I4)') (NSTOR(I),I=1,MSCHL)         ATL03170
C        WRITE(6,'(2X,''MAXOC = '',15I4)') (MAXOC(I),I=1,MSCHL)         ATL03180
         J=1                                                            ATL03190
C        WRITE(6,'(/1X,''NRTAB = '',I5,5X,15I4)')                       ATL03200
C    *         J,(NRTAB(I,J),I=1,MSCH2)                                 ATL03210
C        DO 80 J=2,NREFN                                                ATL03220
C  80       WRITE(6,'(1X,''        '',I5,5X,15I4)')                     ATL03230
C    *            J,(NRTAB(I,J),I=1,MSCH2)                              ATL03240
         J=1                                                            ATL03250
C        WRITE(6,'(1X,''NCONF = '',I10,15I4)')                          ATL03260
C    *         J,(NCONF(I,J),I=1,MSCH2)                                 ATL03270
C        DO 82 J=2,NSCON                                                ATL03280
C  82       WRITE(6,'(1X,''        '',I10,15I4)')                       ATL03290
C    *            J,(NCONF(I,J),I=1,MSCH2)                              ATL03300
         ENDIF                                                          ATL03310
      IF(LPOUT.GT.0) CALL ATENDS('ATMEMB')                              ATL03320
      RETURN                                                            ATL03330
      END                                                               ATL03340
C*DECK ATDGEN                                                           ATL03350
*============*                                                          ATL03360
*= ATDGEN   =* REVISED BY MAS   APR. 15  1987                           ATL03370
*============* CHECKED BY TASHI OCT. 27  1989                           ATL03380
      SUBROUTINE ATDGEN(NPRTY,MOCCN,NORBT,NSCHL,                        ATL03390
     *                  CORBT,CSCHL,NTOPN,NORTS,NBORB,                  ATL03400
     *                  NSTOR,MAXOC,NCONF,                              ATL03410
     *                  NKIND,MSCHL,NCLET,                              ATL03420
     *                  MCONF,MSCH3,NREFN,NSCON,NDCON,                  ATL03430
     *                                          LPOUT)                  ATL03440
C================================================================       ATL03450
C  ATDGEN                                                               ATL03460
C    READ REFERENCE AND GENERATE SINGLE EXCITATION                      ATL03470
C                       CODED BY U.NAGASHIMA                            ATL03480
C================================================================       ATL03490
C     CALLED  SUBROUTINE                                                ATL03500
C     ATGDRV                                                            ATL03510
C================================================================       ATL03520
C     CALLING SUBROUTINE                                                ATL03530
C================================================================       ATL03540
C================================================================       ATL03550
C   ----- ARREY (GIVEN) -----                                           ATL03560
C   NPRTY  : PARITY OF  S,P,D,F..ORBITALS                MKIND*I4       ATL03570
C   MOCCN  : MAXIMUM NUMBERS OF S,P,D,F..SCHELLS         MKIND*I4       ATL03580
C   NORBT  : NUMBERS OF ORBITALS IN S,P,D,F..SCHELLS     MKIND*I4       ATL03590
C   NSCHL  : NUMBERS OF S,P,D,F..SCHELLS                 MKIND*I4       ATL03600
C   CORBT  : CHARACTER OF  'S','P','D',                  12*C1          ATL03610
C   CSCHL  : NAME OF EACH SCHELL                         12*C1          ATL03620
C   MKIND  : MAX NUMBER OF ORBITAL KIND                     I4          ATL03630
C   NKIND  : ACTUAL NUMBERS OF ORBITAL KINDS                I4          ATL03640
C   MSCHL  : TOTAL  NUMBERS OF SCHELL                       I4          ATL03650
C   MCONF  : MAXIMUM NUMBER OF CONFIGURATION                I4          ATL03660
C   NCLET  : MKIND+2                                        I4          ATL03670
C   MSCH3  : MSCHL+1+NREFN*4                                I4          ATL03680
C   LPOUT  : DEBUG FLAG                                     I4          ATL03690
C   NTOPN  : INDEXING TABLE FIRST ORBITAL NO. OF SCHELL     NKIND*I4    ATL03700
C   NORTS  : INDEXING TABLE ORBITAL NO. TO SCHELL NO.       2*NKIND*I4  ATL03710
C   NBORB  : TOP AND END ORBITAL NO. IN EACH SHELLS         2*MSCHL*I4  ATL03720
C   NSTOR  : INDEXING TABLE SCHELL NO.TO ORBITAL NO.        MSCHL*I4    ATL03730
C   MAXOC  : MAX OCCUPATION NUMBER OF EACH SCHELL           MSCHL*I4    ATL03740
C   NCONF  : CONFIGURATION TABLE                        MSCHL*MCONF*I4  ATL03750
C   NREFN  : ACTUAL REFERENCE NUMBER                        I4          ATL03760
C   NSCON  : ACTUAL SINGLE CONFIGURATION NUMBER             I4          ATL03770
C                                                                       ATL03780
C   ---- ARREY ---- RETURN                                              ATL03790
C                                                                       ATL03800
C   NDCON  : ACTUAL DOUBLE CONFIGURATION NUMBER             I4          ATL03810
C================================================================       ATL03820
C     CHARACTER CORBT(NCLET)*1,APO*1,C10*10                             ATL03830
C     CHARACTER CSCHL(MSCHL)*2,C1*1                                     ATL03840
      CHARACTER CORBT(NCLET)*1    
      CHARACTER CSCHL(MSCHL)*2             
      DIMENSION NPRTY(NKIND),MOCCN(NKIND),NORBT(NKIND)                  ATL03850
      DIMENSION NSCHL(NKIND)                                            ATL03860
      DIMENSION NORTS(2,NKIND),NBORB(2,MSCHL)                           ATL03870
      DIMENSION NCONF(MSCH3,MCONF),NSTOR(MSCHL),MAXOC(MSCHL)            ATL03880
      INTEGER * 2 NCONF                                                 ATL03890
      DIMENSION NTOPN(NKIND)                                            ATL03900
      IF(LPOUT.GT.0) CALL ATBIGN('ATDGEN')                              ATL03910
      IF(LPOUT.GT.15) THEN                                              ATL03920
C        WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATDGEN ********'     ATL03930
C        WRITE(6,*) ' ** GIVEN PARAMETERS ARE FOLLOWING   ********'     ATL03940
C        WRITE(6,'(2X,''NKIND,MSCHL             = '',4I5)')             ATL03950
C    *                  NKIND,MSCHL                                     ATL03960
C        WRITE(6,'(2X,''MCONF,NCLET,MSCH3       = '',4I5)')             ATL03970
C    *                  MCONF,NCLET,MSCH3                               ATL03980
C        WRITE(6,'(2X,''NPRTY = '',15I4)') (NPRTY(I),I=1,NKIND)         ATL03990
C        WRITE(6,'(2X,''MOCCN = '',15I4)') (MOCCN(I),I=1,NKIND)         ATL04000
C        WRITE(6,'(2X,''NORBT = '',15I4)') (NORBT(I),I=1,NKIND)         ATL04010
C        WRITE(6,'(2X,''NSCHL = '',15I4)') (NSCHL(I),I=1,NKIND)         ATL04020
C        WRITE(6,'(2X,''CORBT =  '',15(2X,A1,1X)') (CORBT(I),I=1,NCLET) ATL04030
C        WRITE(6,'(2X,''CSCHL =  '',15(1X,A2,1X)') (CSCHL(I),I=1,MSCHL) ATL04040
C        WRITE(6,'(2X,''NREFN,NSCON             = '',2I5)')             ATL04050
C    *                  NREFN,NSCON                                     ATL04060
C        WRITE(6,'(/2X,''-TYPE-   '',15(2X,A1,1X)')                     ATL04070
C    *        (CORBT(I),I=1,NKIND)                                      ATL04080
C        WRITE(6,'(2X,''NORTS = '',15I4)') (NORTS(1,I),I=1,NKIND)       ATL04090
C        WRITE(6,'(2X,''        '',15I4)') (NORTS(2,I),I=1,NKIND)       ATL04100
C        WRITE(6,'(/2X,''-TYPE-   '',15(2X,A1,1X)')                     ATL04110
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL04120
C        WRITE(6,'(2X,''-NAME-   '',15(1X,A2,1X)')                      ATL04130
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL04140
C        WRITE(6,'(2X,''NSTOR = '',15I4)') (NSTOR(I),I=1,MSCHL)         ATL04150
C        WRITE(6,'(2X,''MAXOC = '',15I4)') (MAXOC(I),I=1,MSCHL)         ATL04160
C        WRITE(6,'(2X,''NBORB = '',15I4)') (NBORB(1,I),I=1,MSCHL)       ATL04170
C        WRITE(6,'(2X,''        '',15I4)') (NBORB(2,I),I=1,MSCHL)       ATL04180
         J=1                                                            ATL04190
C        WRITE(6,'(/1X,''== READED REFERENCE CONFIGURATION '',          ATL04200
C    *                ''AND SINGLE EXCITED CONFIGURATION =='')')        ATL04210
C        WRITE(6,'(/1X,''-TYPE-         NO.'',36(2X,A1)')               ATL04220
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL04230
C        WRITE(6,'(1X,''-NAME-   '',9X,36(1X,A2)')                      ATL04240
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL04250
C        WRITE(6,'(1X,''NCONF = '',I10,36I3)')                          ATL04260
C    *         J,(NCONF(I,J),I=1,MSCH3)                                 ATL04270
* REVISED BY MAS                                                        ATL04280
C        DO 12 J=2,NSCON                                                ATL04290
C           IF(MOD(J,10).EQ.0) THEN                                     ATL04300
C              WRITE(6,'(/1X,''-TYPE-         NO.'',36(2X,A1)')         ATL04310
C    *              (CORBT(NSTOR(I)),I=1,MSCHL)                         ATL04320
C              WRITE(6,'(1X,''-NAME-   '',9X,36(1X,A2)')                ATL04330
C    *           (CSCHL(I),I=1,MSCHL)                                   ATL04340
C               ENDIF                                                   ATL04350
C  12       WRITE(6,'(1X,''        '',I10,36I3)')                       ATL04360
C    *            J,(NCONF(I,J),I=1,MSCH3)                              ATL04370
         ENDIF                                                          ATL04380
C ------- DOUBLE EXCITATIONS         ---------------------------        ATL04390
      NSA=1                                                             ATL04400
      NCO=NSCON                                                         ATL04410
C     ITOP=NREFN+1                                                      ATL04420
      ITOP=1                                                            ATL04430
      IEND=NSCON                                                        ATL04440
      DO 68 I=ITOP,IEND                                                 ATL04450
         JEND=MSCHL-1                                                   ATL04460
         DO 66  J=1,JEND                                                ATL04470
            NDAM=NCONF(J,I)-NSA                                         ATL04480
            IF(NDAM.LT.0) GO TO 66                                      ATL04490
            DO 64 K=1,MSCHL                                             ATL04500
               IF(K.EQ.J) GO TO 64                                      ATL04510
               MDAM=NCONF(K,I)+NSA                                      ATL04520
               IF(MDAM.GT.MAXOC(K)) GO TO 64                            ATL04530
               JPT=NPRTY(NSTOR(J))*NPRTY(NSTOR(K))*NCONF(MSCHL+1,I)     ATL04540
               IF(JPT.EQ.1) THEN                                        ATL04550
                  NCO=NCO+1                                             ATL04560
                  IF( NCO .GT. MCONF ) THEN                             ATL04570
                     WRITE(6,*) ' == NEED MORE CORE == EMERGENCY STOP ' ATL04580
                     WRITE(6,*) ' == STOP AT ',I,' (TOTAL',NSCON,       ATL04590
     *                          ' )',NCO,' WAS MADE == '                ATL04600
                     STOP                                               ATL04610
                     END IF                                             ATL04620
                  DO 56 L=1,MSCHL                                       ATL04630
   56                NCONF(L,NCO)=NCONF(L,I)                            ATL04640
                  DO 57 L=MSCHL + 1,MSCH3                               ATL04650
   57                NCONF(L,NCO)=0                                     ATL04660
                  NCONF(J,NCO)=NDAM                                     ATL04670
                  NCONF(K,NCO)=MDAM                                     ATL04680
                  NCO1=NCO-1                                            ATL04690
                  DO 60 LL=1,NCO1                                       ATL04700
                     DO 58 L=1,MSCHL                                    ATL04710
   58                   IF(NCONF(L,NCO).NE.NCONF(L,LL)) GO TO 60        ATL04720
* CHECK DUPLICATION                                                     ATL04730
                     NCO=NCO1                                           ATL04740
                     DO 59 IR = 1, NREFN                                ATL04750
                        KR = MSCHL + 1 + (IR-1) * 4                     ATL04760
                        IF (( NCONF(KR+1,I) .EQ. 0 ) .OR.               ATL04770
     *                      ( NCONF(KR+3,I) .NE. 0 ) .OR.               ATL04780
     *                      ( NCONF(KR+1,LL).NE. 0 )) GOTO 59           ATL04790
                           NCONF(KR+1,LL)=NCONF(KR+1,I)                 ATL04800
                           NCONF(KR+2,LL)=NCONF(KR+2,I)                 ATL04810
                           NCONF(KR+3,LL)=J                             ATL04820
                           NCONF(KR+4,LL)=K                             ATL04830
   59                   CONTINUE                                        ATL04840
                     GO TO 64                                           ATL04850
   60                CONTINUE                                           ATL04860
*                    IF ( NCO .EQ. NCO1 ) GOTO 64                       ATL04870
                     DO 62 IR = 1, NREFN                                ATL04880
                        KR = MSCHL + 1 + (IR-1) * 4                     ATL04890
                        IF  ((NCONF(KR+1,I) .EQ. 0 )  .OR.              ATL04900
     *                       (NCONF(KR+3,I) .NE. 0 )) GOTO 62           ATL04910
                           NCONF(KR+1,NCO)=NCONF(KR+1,I)                ATL04920
                           NCONF(KR+2,NCO)=NCONF(KR+2,I)                ATL04930
                           NCONF(KR+3,NCO)=J                            ATL04940
                           NCONF(KR+4,NCO)=K                            ATL04950
   62                   CONTINUE                                        ATL04960
                  ENDIF                                                 ATL04970
   64          CONTINUE                                                 ATL04980
   66       CONTINUE                                                    ATL04990
   68    CONTINUE                                                       ATL05000
      NDCON=NCO                                                         ATL05010
      IF(LPOUT.GT.10) THEN                                              ATL05020
C       WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATDGEN ********'      ATL05030
C       WRITE(6,*) ' ** GENERATED PARAMETERS ARE FOLLOWING     **'      ATL05040
        J=1                                                             ATL05050
C       WRITE(6,'(/1X,''== READED REFERENCE CONFIGURATION =='')')       ATL05060
C       WRITE(6,'(/1X,''-TYPE-         NO.'',36(2X,A1)')                ATL05070
C   *        (CORBT(NSTOR(I)),I=1,MSCHL)                                ATL05080
C       WRITE(6,'(1X,''-NAME-            '',36(1X,A2)')                 ATL05090
C   *        (CSCHL(I),I=1,MSCHL)                                       ATL05100
C       WRITE(6,'(/1X,''REF   = '',I10,36I3)')                          ATL05110
C   *         J,(NCONF(I,J),I=1,MSCH3)                                  ATL05120
C       DO 80 J=2,NREFN                                                 ATL05130
C 80       WRITE(6,'(1X,''        '',I10,36I3)')                        ATL05140
C   *            J,(NCONF(I,J),I=1,MSCH3)                               ATL05150
         J=NREFN+1                                                      ATL05160
C       WRITE(6,'(/1X,''== SINGLE EXCITED CONFIGURATION =='')')         ATL05170
C       WRITE(6,'(/1X,''-TYPE-         NO.'',36(2X,A1)')                ATL05180
C   *        (CORBT(NSTOR(I)),I=1,MSCHL)                                ATL05190
C       WRITE(6,'(1X,''-NAME-   '',9X,36(1X,A2)')                       ATL05200
C   *        (CSCHL(I),I=1,MSCHL)                                       ATL05210
C       WRITE(6,'(1X,''NCONF = '',I10,36I3)')                           ATL05220
C   *         J,(NCONF(I,J),I=1,MSCH3)                                  ATL05230
         JTOP=J+1                                                       ATL05240
         JEND=NSCON                                                     ATL05250
C       DO 82 J=JTOP,JEND                                               ATL05260
C          IF(MOD(J,10).EQ.0) THEN                                      ATL05270
C        WRITE(6,'(/1X,''-TYPE-         NO.'',36(2X,A1)')               ATL05280
C   *        (CORBT(NSTOR(I)),I=1,MSCHL)                                ATL05290
C       WRITE(6,'(1X,''-NAME-   '',9X,36(1X,A2)')                       ATL05300
C   *        (CSCHL(I),I=1,MSCHL)                                       ATL05310
C             ENDIF                                                     ATL05320
C 82       WRITE(6,'(1X,''        '',I10,36I3)')                        ATL05330
C   *            J,(NCONF(I,J),I=1,MSCH3)                               ATL05340
         J=JEND + 1                                                     ATL05350
C        WRITE(6,'(/1X,''== DOUBLE EXCITED CONFIGURATION =='')')        ATL05360
C        WRITE(6,'(/1X,''-TYPE-         NO.'',36(2X,A1)')               ATL05370
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL05380
C        WRITE(6,'(1X,''-NAME-   '',9X,36(1X,A2)')                      ATL05390
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL05400
C        WRITE(6,'(1X,''NCONF = '',I10,36I3)')                          ATL05410
C    *         J,(NCONF(I,J),I=1,MSCH3)                                 ATL05420
         JTOP=J+1                                                       ATL05430
C        DO 84 J=JTOP,NCO                                               ATL05440
C           IF(MOD(J,10).EQ.0) THEN                                     ATL05450
C        WRITE(6,'(/1X,''-TYPE-         NO.'',36(2X,A1)')               ATL05460
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL05470
C        WRITE(6,'(1X,''-NAME-   '',9X,36(1X,A2)')                      ATL05480
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL05490
C              ENDIF                                                    ATL05500
C  84       WRITE(6,'(1X,''        '',I10,36I3)')                       ATL05510
C    *            J,(NCONF(I,J),I=1,MSCH3)                              ATL05520
         ENDIF                                                          ATL05530
      WRITE(6,'(//1X,''== TOTAL NUMBER OF OCCUPATION == '',I6 )') NDCON ATL05540
      IF(LPOUT.GT.0) CALL ATENDS('ATDGEN')                              ATL05550
      RETURN                                                            ATL05560
      END                                                               ATL05570
C*DECK ATMEMA                                                           ATL05580
*============*                                                          ATL05590
*= ATMEMA   =* REVISED BY MAS   APR. 15  1987                           ATL05600
*============* CHECKED BY TASHI OCT. 27  1989                           ATL05610
      SUBROUTINE ATMEMA(LLRTY,LLCCN,LLRBT,LLCHL,DDRBT,LLMSL,            ATL05620
     *                  NPRTY,MOCCN,NORBT,NSCHL,CORBT,CSCHL,            ATL05630
     *            MSCHL,NKIND,MKIND,NCLET,NBORB,MBORB,LPOUT)            ATL05640
      CHARACTER CORBT(NCLET)*1                                          ATL05650
      CHARACTER CSCHL(MSCHL)*2                                          ATL05660
      DIMENSION NPRTY(NKIND),MOCCN(NKIND),NORBT(NKIND)                  ATL05670
      DIMENSION NSCHL(NKIND)                                            ATL05680
      CHARACTER DDRBT(NCLET)*1                                          ATL05690
      CHARACTER LLMSL(MBORB,MKIND)*2                                    ATL05700
      DIMENSION LLRTY(MKIND),LLCCN(MKIND),LLRBT(MKIND)                  ATL05710
      DIMENSION LLCHL(MKIND)                                            ATL05720
      IF(LPOUT.GT.0) CALL ATBIGN('ATMEMA')                              ATL05730
      IF(LPOUT.GT.50) THEN                                              ATL05740
C        WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATMEMA ********'     ATL05750
C        WRITE(6,'(2X,''MKIND,NKIND,MSCHL,NCLET = '',4I5)')             ATL05760
C    *                  MKIND,NKIND,MSCHL,NCLET                         ATL05770
C        WRITE(6,'(2X,''NBORB,MBORB,            = '',2I5)')             ATL05780
C    *                  NBORB,MBORB                                     ATL05790
C        WRITE(6,'(2X,''NPRTY = '',10I4)') (LLRTY(I),I=1,NKIND)         ATL05800
C        WRITE(6,'(2X,''MOCCN = '',10I4)') (LLCCN(I),I=1,NKIND)         ATL05810
C        WRITE(6,'(2X,''NORBT = '',10I4)') (LLRBT(I),I=1,NKIND)         ATL05820
C        WRITE(6,'(2X,''NSCHL = '',10I4)') (LLCHL(I),I=1,NKIND)         ATL05830
C        WRITE(6,'(2X,''CORBT =  '',10(2X,A1,1X)') (DDRBT(I),I=1,NKIND) ATL05840
C        WRITE(6,'(2X,''NAMSL =  '',10(1X,A2,1X)')                      ATL05850
C    *        (LLMSL(J,1),J=1,LLCHL(1))                                 ATL05860
C        DO 91 I=2,NKIND                                                ATL05870
C  91    WRITE(6,'(2X,''         '',10(1X,A2,1X)')                      ATL05880
C    *        (LLMSL(J,I),J=1,LLCHL(I))                                 ATL05890
         ENDIF                                                          ATL05900
      DO 10 I=1,NKIND                                                   ATL05910
   10    NPRTY(I)=LLRTY(I)                                              ATL05920
      DO 12 I=1,NKIND                                                   ATL05930
   12    MOCCN(I)=LLCCN(I)                                              ATL05940
      DO 14 I=1,NKIND                                                   ATL05950
   14    NORBT(I)=LLRBT(I)                                              ATL05960
      DO 16 I=1,NKIND                                                   ATL05970
   16    NSCHL(I)=LLCHL(I)                                              ATL05980
      DO 18 J=1,NCLET                                                   ATL05990
   18    CORBT(J)=DDRBT(J)                                              ATL06000
      KK=0                                                              ATL06010
      DO 22 I=1,NKIND                                                   ATL06020
         DO 20 J=1,NSCHL(I)                                             ATL06030
            KK=KK+1                                                     ATL06040
   20       CSCHL(KK)=LLMSL(J,I)                                        ATL06050
   22       CONTINUE                                                    ATL06060
C        WRITE(6,'(2X,''CSCHL*=  '',10(1X,A,1X)') (CSCHL(I),I=1,MSCHL)  ATL06070
         WRITE(6,'(2X,''CSCHL*=  '',10(1X,A,1X))') (CSCHL(I),I=1,MSCHL) ATL06080
      IF(LPOUT.GT.50) THEN                                              ATL06090
C        WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATMEMA ********'     ATL06100
C        WRITE(6,'(2X,''NPRTY = '',10I4)') (NPRTY(I),I=1,NKIND)         ATL06110
C        WRITE(6,'(2X,''MOCCN = '',10I4)') (MOCCN(I),I=1,NKIND)         ATL06120
C        WRITE(6,'(2X,''NORBT = '',10I4)') (NORBT(I),I=1,NKIND)         ATL06130
C        WRITE(6,'(2X,''NSCHL = '',10I4)') (NSCHL(I),I=1,NKIND)         ATL06140
C        WRITE(6,'(2X,''CORBT =  '',10(2X,A1,1X))') (CORBT(I),I=1,NKIND)ATL06150
C        WRITE(6,'(2X,''CSCHL =  '',15(1X,A2,1X))') (CSCHL(I),I=1,MSCHL)ATL06160
         ENDIF                                                          ATL06170
      IF(LPOUT.GT.0) CALL ATENDS('ATMEMA')                              ATL06180
      RETURN                                                            ATL06190
      END                                                               ATL06200
C*DECK ATRGEN                                                           ATL06210
*============*                                                          ATL06220
*= ATRGEN   =* REVISED BY MAS  APR. 15  1987                            ATL06230
*============*                                                          ATL06240
      SUBROUTINE ATRGEN(NFT05,NPRTY,MOCCN,NORBT,NSCHL,                  ATL06250
     *                  CORBT,CSCHL,NKIND,MKIND,                        ATL06260
     *                  MSCHL,NCLET,MCONF,MSCH3,                        ATL06270
     *                  NTOPN,NORTS,NBORB,NSTOR,MAXOC,                  ATL06280
     *                  NCONF,NREFN,LPOUT)                              ATL06290
C================================================================       ATL06300
C  ATRGEN                                                               ATL06310
C    READ REFERENCE AND GENERATE SINGLE EXCITATION                      ATL06320
C                       CODED BY U.NAGASHIMA                            ATL06330
C================================================================       ATL06340
C     CALLED  SUBROUTINE                                                ATL06350
C     ATGDRV                                                            ATL06360
C================================================================       ATL06370
C     CALLING SUBROUTINE                                                ATL06380
C================================================================       ATL06390
C================================================================       ATL06400
C   ----- ARREY (GIVEN) -----                                           ATL06410
C   NFT05  : LOGICAL UNIT NUMBER OF NFT05                   I4          ATL06420
C   NPRTY  : PARITY OF  S,P,D,F..ORBITALS                MKIND*I4       ATL06430
C   MOCCN  : MAXIMUM NUMBERS OF S,P,D,F..SCHELLS         MKIND*I4       ATL06440
C   NORBT  : NUMBERS OF ORBITALS IN S,P,D,F..SCHELLS     MKIND*I4       ATL06450
C   NSCHL  : NUMBERS OF S,P,D,F..SCHELLS                 MKIND*I4       ATL06460
C   CORBT  : CHARACTER OF  'S','P','D',                  12*C1          ATL06470
C   CSCHL  : NAME OF EACH SCHELL                         12*C1          ATL06480
C   MKIND  : MAX NUMBER OF ORBITAL KIND                     I4          ATL06490
C   NKIND  : ACTUAL NUMBERS OF ORBITAL KINDS                I4          ATL06500
C   MSCHL  : TOTAL  NUMBERS OF SCHELL                       I4          ATL06510
C   MCONF  : MAXIMUM NUMBER OF CONFIGURATION                I4          ATL06520
C   NCLET  : MKIND+2                                        I4          ATL06530
C   MSCH3  : MSCHL+MXREF*4 + 1                              I4          ATL06540
C   LPOUT  : DEBUG FLAG                                     I4          ATL06550
C                                                                       ATL06560
C   ----- ARREY (RETURN)-----                                           ATL06570
C   NTOPN  : INDEXING TABLE FIRST ORBITAL NO. OF SCHELL NKIND*I4        ATL06580
C   NORTS  : INDEXING TABLE ORBITAL NO. TO SCHELL NO.   2*NKIND*I4      ATL06590
C   NBORB  : TOP AND END ORBITAL NO. IN EACH SHELLS     2*MSCHL*I4      ATL06600
C   NSTOR  : INDEXING TABLE SCHELL NO.TO ORBITAL NO.    MSCHL*I4        ATL06610
C   MAXOC  : MAX OCCUPATION NUMBER OF EACH SCHELL       MSCHL*I4        ATL06620
C   NCONF  : CONFIGURATION TABLE                        MSCHL*MCONF*I4  ATL06630
C   NREFN  : ACTUAL REFERENCE NUMBER                        I4          ATL06640
C================================================================       ATL06650
      CHARACTER CORBT(NCLET)*1,APO*1,C10*10,TIT72*72                    ATL06660
      CHARACTER TIT200*200
      CHARACTER CSCHL(MSCHL)*2,C1*1                                     ATL06670
      DIMENSION NPRTY(MKIND),MOCCN(MKIND),NORBT(MKIND)                  ATL06680
      DIMENSION NSCHL(MKIND)                                            ATL06690
      DIMENSION NORTS(2,NKIND),NBORB(2,MSCHL)                           ATL06700
      DIMENSION NCONF(MSCH3,MCONF),NSTOR(MSCHL),MAXOC(MSCHL)            ATL06710
      INTEGER * 2 NCONF                                                 ATL06720
      DIMENSION NTOPN(NKIND)                                            ATL06730
      DATA APO/1H'/                                                     ATL06740
      IF(LPOUT.GT.0) CALL ATBIGN('ATRGEN')                              ATL06750
      IF(LPOUT.GT.50) THEN                                              ATL06760
C        WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATRGEN ********'     ATL06770
C        WRITE(6,*) ' ** GIVEN PARAMETERS ARE FOLLOWING   ********'     ATL06780
C        WRITE(6,'(2X,''NFT05,MKIND,NKIND,MSCHL = '',4I5)')             ATL06790
C    *                  NFT05,MKIND,NKIND,MSCHL                         ATL06800
C        WRITE(6,'(2X,''MCONF,NCLET,MSCH3       = '',4I5)')             ATL06810
C    *                  MCONF,NCLET,MSCH3                               ATL06820
C        WRITE(6,'(2X,''NPRTY = '',15I4)') (NPRTY(I),I=1,NKIND)         ATL06830
C        WRITE(6,'(2X,''MOCCN = '',15I4)') (MOCCN(I),I=1,NKIND)         ATL06840
C        WRITE(6,'(2X,''NORBT = '',15I4)') (NORBT(I),I=1,NKIND)         ATL06850
C        WRITE(6,'(2X,''NSCHL = '',15I4)') (NSCHL(I),I=1,NKIND)         ATL06860
C        WRITE(6,'(2X,''CORBT =  '',15(2X,A1,1X)/11X,15(2X,A1,1X))')    ATL06870
C    *                                             (CORBT(I),I=1,NCLET) ATL06880
C        WRITE(6,'(2X,''CSCHL =  '',15(2X,A1,1X)/11X,15(2X,A1,1X))')    ATL06890
C    *                                             (CSCHL(I),I=1,MSCHL) ATL06900
         ENDIF                                                          ATL06910
      IT=1                                                              ATL06920
      DO 16 I=1,NKIND                                                   ATL06930
         NORTS(1,I)=IT                                                  ATL06940
         NORTS(2,I)=NORTS(1,I)+NSCHL(I)-1                               ATL06950
         DO 10 J=NORTS(1,I),NORTS(2,I)                                  ATL06960
            MAXOC(J)=MOCCN(I)                                           ATL06970
   10       NSTOR(J)=I                                                  ATL06980
*  REVISED BY MAS                                                       ATL06990
*        MAXOC(NORTS(2,I))=MOCCN(I)*(NORBT(I)-NSCHL(I)+1)               ATL07000
         MAXOC(NORTS(2,I))=MOCCN(I)*NORBT(I)                            ATL07010
         IY=I                                                           ATL07020
         DO 12 J=NORTS(1,I),NORTS(2,I)                                  ATL07030
            NBORB(1,J)=IY                                               ATL07040
            IF(J.EQ.NORTS(2,I)) IY=NORBT(I)+I-1                         ATL07050
            NBORB(2,J)=IY                                               ATL07060
   12       IY=IY+1                                                     ATL07070
   16    IT=NORTS(2,I)+1                                                ATL07080
      DO 18 I=1,NKIND                                                   ATL07090
         NTOPN(I)=0                                                     ATL07100
         C1=CSCHL(NORTS(1,I))(1:1)                                      ATL07110
         IF(C1.NE.'N') THEN                                             ATL07120
            READ(C1,*) II                                               ATL07130
            NTOPN(I)=II-I                                               ATL07140
C           WRITE(6,*) NTOPN(I)                                         ATL07150
C Validation: IA's
C mapping of a CARD-3 shell label to its table row (below) assumes a
C kind's named CARD-2 shells are numbered consecutively from II -- verify
C that instead of just assuming it (this is what a gapped/non-consecutive
C same-kind numbering, e.g. 1S,3S, silently violates).
            DO 17 J=NORTS(1,I)+1,NORTS(2,I)-1
               C1=CSCHL(J)(1:1)
               READ(C1,*) IJ
               IF(IJ.NE.II+(J-NORTS(1,I))) GO TO 94
   17          CONTINUE
            ENDIF                                                       ATL07160
   18    CONTINUE                                                       ATL07170
C ======= READ REFERENCE =======================================        ATL07180
*  FIXED BY MAS  JUNE/01/90                                             ATL07190
      NREFN=1                                                           ATL07200
      DO 28 J=1,MSCHL                                                   ATL07210
   28    NCONF(J,NREFN)=0                                               ATL07220
*     TIT72(73:80) = '        '                                         ATL07230
C Validation: TIT72
C is CHARACTER*72 -- a physical CARD-3 line longer than 72 columns
C silently truncates on a plain (A) read into it, with no way to detect
C the truncation from TIT72 alone. Read into a wider buffer instead and
C check the tail for it.
   20 READ(NFT05,'(A)',END=92,ERR=99)  TIT200
      TIT72=TIT200(1:72)
      IF(LPOUT.GT.5) THEN                                               ATL07250
         WRITE(6,'(''  =DATA=  '',A)') TIT72                            ATL07260
         ENDIF                                                          ATL07270
      IF((TIT72(1:1).EQ.APO).OR.                                        ATL07280
     *   (TIT72(1:1).EQ.'"')) GO TO 20                                  ATL07290
      IF(TIT200(73:200).NE.' ') GO TO 95
C ------- GET OCCUPATION NUMBER OF EACH SCHELL OF NREFN TH REF.-        ATL07300
      NT=INDEX(TIT72,')))')                                             ATL07310
      NA=NT                                                             ATL07320
      IF(NT.EQ.0) NA=72                                                 ATL07330
*   FIXWD BY MAS JUNE/01/90                                             ATL07340
*     DO 28 J=1,MSCHL                                                   ATL07350
*  28    NCONF(J,NREFN)=0                                               ATL07360
      I=1                                                               ATL07370
   30 IF(TIT72(I:I).NE.' ') THEN                                        ATL07380
         C10='          '                                               ATL07390
         IF(I.EQ.NT) GO TO 38                                           ATL07400
         K=I                                                            ATL07410
   32    K=K+1                                                          ATL07420
         IF(K.GT.NA) GO TO 38                                           ATL07430
         IF(TIT72(K:K).NE.')') GO TO 32                                 ATL07440
         C10=TIT72(I:K-1)                                               ATL07450
         NS=INDEX(C10,'*')                                              ATL07460
         C10(NS:NS)=' '                                                 ATL07470
         DO 36 J=1,MKIND                                                ATL07480
            IJ=INDEX(C10,CORBT(J))                                      ATL07490
            IF(IJ.NE.0) THEN                                            ATL07500
               L=J                                                      ATL07510
               C10(IJ:IJ)=' '                                           ATL07520
               READ(C10,*,ERR=36,END=36) N,M                            ATL07530
C     WRITE(6,'('' ===== DEBUG N L M   = '',I4,A1,I2)') N,CORBT(L),M    ATL07540
               IA=NORTS(1,L)+N-L-NTOPN(L)                               ATL07550
               NCONF(IA,NREFN)=M                                        ATL07560
C     WRITE(6,'('' ===== DEBUG IA NREFN OCC= '',3I4)') IA,NREFN,M       ATL07570
               ENDIF                                                    ATL07580
   36       CONTINUE                                                    ATL07590
         ND=INDEX(TIT72,'))')                                           ATL07600
C     WRITE(6,'('' ***** DEBUG NT,ND,K = '',3I4)') NT,ND,K              ATL07610
         IF(ND.EQ.K) THEN                                               ATL07620
            IF(ND.EQ.NT) GO TO 38                                       ATL07630
            NREFN=NREFN+1                                               ATL07640
            DO 37 J=1,MSCHL                                             ATL07650
   37          NCONF(J,NREFN)=0                                         ATL07660
            I=K+2                                                       ATL07670
            ELSE                                                        ATL07680
            I=K+1                                                       ATL07690
            ENDIF                                                       ATL07700
         ENDIF                                                          ATL07710
         I=I+1                                                          ATL07720
         IF(I.GE.NA) GO TO 38                                           ATL07730
         GO TO 30                                                       ATL07740
   38 IF(NT.EQ.0) GO TO 20                                              ATL07750
      NREFN = NREFN - 1                                                 ATL07760
      WRITE(6,*) '== # OF REFERENCE CONFIGURATIONS == ',NREFN           ATL07770
*     CHECK CONFIGURATION AND PARITY     *  MUST BE INSERTED !!         ATL07780
      DO 40 I = 1, NREFN                                                ATL07790
40       NCONF(MSCHL+1,I) = 1                                           ATL07800
      IF(LPOUT.GT.30) THEN                                              ATL07810
C        WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATRGEN ********'     ATL07820
C        WRITE(6,*) ' ** GENERATED PARAMETERS ARE FOLLOWING     **'     ATL07830
C        WRITE(6,'(2X,''NREFN                   = '',2I5)')             ATL07840
C    *                  NREFN                                           ATL07850
C        WRITE(6,'(/2X,''-TYPE-   '',15(2X,A1,1X)')                     ATL07860
C    *        (CORBT(I),I=1,NKIND)                                      ATL07870
C        WRITE(6,'(2X,''NORTS = '',15I4)') (NORTS(1,I),I=1,NKIND)       ATL07880
C        WRITE(6,'(2X,''        '',15I4)') (NORTS(2,I),I=1,NKIND)       ATL07890
C        WRITE(6,'(/2X,''-TYPE-   '',15(2X,A1,1X)')                     ATL07900
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL07910
C        WRITE(6,'(2X,''-NAME-   '',15(1X,A2,1X)')                      ATL07920
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL07930
C        WRITE(6,'(2X,''NSTOR = '',15I4)') (NSTOR(I),I=1,MSCHL)         ATL07940
C        WRITE(6,'(2X,''MAXOC = '',15I4)') (MAXOC(I),I=1,MSCHL)         ATL07950
C        WRITE(6,'(2X,''NBORB = '',15I4)') (NBORB(1,I),I=1,MSCHL)       ATL07960
C        WRITE(6,'(2X,''        '',15I4)') (NBORB(2,I),I=1,MSCHL)       ATL07970
C        J=1                                                            ATL07980
C        WRITE(6,'(/1X,''== READ REFERENCE CONFIGURATION =='')')        ATL07990
C        WRITE(6,'(/1X,''-TYPE-      NO.    '',15(2X,A1,1X)')           ATL08000
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL08010
C        WRITE(6,'(1X,''-NAME-   '',10X,15(1X,A2,1X)')                  ATL08020
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL08030
C        WRITE(6,'(/1X,''NCONF = '',I10,5X,15I4)')                      ATL08040
C    *         J,(NCONF(I,J),I=1,MSCHL)                                 ATL08050
C        DO 80 J=2,NREFN                                                ATL08060
C  80       WRITE(6,'(1X,''        '',I10,5X,15I4)')                    ATL08070
C    *            J,(NCONF(I,J),I=1,MSCHL)                              ATL08080
         END IF                                                         ATL08090
      IF(LPOUT.GT.0) CALL ATENDS('ATRGEN')                              ATL08100
      RETURN                                                            ATL08110
   92 CONTINUE                                                          ATL08120
      WRITE(6,*) ' **************************************************'  ATL08130
      WRITE(6,*) ' ** ERROR STOP IN SUB.ATRGEN                     **'  ATL08140
      WRITE(6,*) ' **************************************************'  ATL08150
      WRITE(6,*) ' - INPUT DATA ARE NOT COMPLETED. CHECK YOUR DATA. -'  ATL08160
      WRITE(6,*) ' - PROCESS IS ABEND.                              -'  ATL08170
      WRITE(6,*) '   NREFN     = ',NREFN                                ATL08180
      STOP 920                                                          ATL08190
C Validation: a
C kind's named CARD-2 shells were not numbered consecutively.
   94 CONTINUE
      WRITE(6,*) ' **************************************************'
      WRITE(6,*) ' ** ERROR STOP IN SUB.ATRGEN                     **'
      WRITE(6,*) ' **************************************************'
      WRITE(6,*) ' - CARD 2 SAME-KIND SHELLS ARE NOT CONSECUTIVELY -'
      WRITE(6,*) ' - NUMBERED (E.G. 1S,3S WITH 2S OMITTED).        -'
      WRITE(6,*) ' - PROCESS IS ABEND.                              -'
      WRITE(6,*) '   KIND =',CORBT(I),' SHELL ROW =',J
      STOP 922
C Validation: a
C physical CARD-3 line exceeded the 72-column limit.
   95 CONTINUE
      WRITE(6,*) ' **************************************************'
      WRITE(6,*) ' ** ERROR STOP IN SUB.ATRGEN                     **'
      WRITE(6,*) ' **************************************************'
      WRITE(6,*) ' - A CARD 3 PHYSICAL LINE EXCEEDS 72 COLUMNS.    -'
      WRITE(6,*) ' - SPLIT IT ACROSS MULTIPLE RECORDS INSTEAD.     -'
      WRITE(6,*) ' - PROCESS IS ABEND.                              -'
      STOP 924
   99 CONTINUE                                                          ATL08200
      WRITE(6,*) ' **************************************************'  ATL08210
      WRITE(6,*) ' ** ERROR STOP IN SUB.ATRGEN                     **'  ATL08220
      WRITE(6,*) ' **************************************************'  ATL08230
      WRITE(6,*) ' - SOME ERROR DITECTED ON NFT05.CHECK YOUR DATA. -'   ATL08240
      WRITE(6,*) '  NFT05= ',NFT05                                      ATL08250
      STOP 990                                                          ATL08260
      END                                                               ATL08270
C*DECK ATSGEN                                                           ATL08280
*============*                                                          ATL08290
*= ATSGEN   =* REVISED BY MAS   APR. 15  1987                           ATL08300
*============* CHECHED BY TASHI OCT. 27  1989                           ATL08310
      SUBROUTINE ATSGEN(NPRTY,MOCCN,NORBT,NSCHL,                        ATL08320
     *                  CORBT,CSCHL,NKIND,MKIND,                        ATL08330
     *                  MSCHL,NCLET,MCONF,MSCH1,MSDUMY,                 ATL08340
     *                  NTOPN,NORTS,NBORB,NSTOR,MAXOC,                  ATL08350
     *                  NCONF,WKCONF,NREFN,NSCON,LPOUT)                 ATL08360
C================================================================       ATL08370
C  ATSGEN                                                               ATL08380
C    READ REFERENCE AND GENERATE SINGLE EXCITATION                      ATL08390
C                       CODED BY U.NAGASHIMA                            ATL08400
C================================================================       ATL08410
C     CALLED  SUBROUTINE                                                ATL08420
C     ATGDRV                                                            ATL08430
C================================================================       ATL08440
C     CALLING SUBROUTINE                                                ATL08450
C================================================================       ATL08460
C================================================================       ATL08470
C   ----- ARREY (GIVEN) -----                                           ATL08480
C   NPRTY  : PARITY OF  S,P,D,F..ORBITALS                MKIND*I4       ATL08490
C   MOCCN  : MAXIMUM NUMBERS OF S,P,D,F..SCHELLS         MKIND*I4       ATL08500
C   NORBT  : NUMBERS OF ORBITALS IN S,P,D,F..SCHELLS     MKIND*I4       ATL08510
C   NSCHL  : NUMBERS OF S,P,D,F..SCHELLS                 MKIND*I4       ATL08520
C   CORBT  : CHARACTER OF  'S','P','D',                  12*C1          ATL08530
C   CSCHL  : NAME OF EACH SCHELL                         12*C1          ATL08540
C   MKIND  : MAX NUMBER OF ORBITAL KIND                     I4          ATL08550
C   NKIND  : ACTUAL NUMBERS OF ORBITAL KINDS                I4          ATL08560
C   MSCHL  : TOTAL  NUMBERS OF SCHELL                       I4          ATL08570
C   MCONF  : MAXIMUM NUMBER OF CONFIGURATION                I4          ATL08580
C   NCLET  : MKIND+2                                        I4          ATL08590
C   MSCH1  : MSCHL+1+NREFN*4                                I4          ATL08600
C   LPOUT  : DEBUG FLAG                                     I4          ATL08610
C                                                                       ATL08620
C   ----- ARREY (RETURN)-----                                           ATL08630
C   NTOPN  : INDEXING TABLE FIRST ORBITAL NO. OF SCHELL NKIND*I4        ATL08640
C   NORTS  : INDEXING TABLE ORBITAL NO. TO SCHELL NO.   2*NKIND*I4      ATL08650
C   NBORB  : TOP AND END ORBITAL NO. IN EACH SHELLS     2*MSCHL*I4      ATL08660
C   NSTOR  : INDEXING TABLE SCHELL NO.TO ORBITAL NO.    MSCHL*I4        ATL08670
C   MAXOC  : MAX OCCUPATION NUMBER OF EACH SCHELL       MSCHL*I4        ATL08680
C   NCONF  : CONFIGURATION TABLE                        MSCHL*MCONF*I4  ATL08690
C  WKCONF  : CONFIGURATION TABLE ( WORK REGION )                        ATL08700
C   NREFN  : ACTUAL REFERENCE NUMBER                        I4          ATL08710
C   NSCON  : ACTUAL SINGLE CONFIGURATION NUMBER             I4          ATL08720
C================================================================       ATL08730
C     CHARACTER CORBT(NCLET)*1,APO*1,C10*10,TIT72*72                    ATL08740
C     CHARACTER CSCHL(MSCHL)*2,C1*1                                     ATL08750
      CHARACTER CORBT(NCLET)*1,APO*1       
      CHARACTER CSCHL(MSCHL)*2                     
      DIMENSION NPRTY(MKIND),MOCCN(MKIND),NORBT(MKIND)                  ATL08760
      DIMENSION NSCHL(MKIND)                                            ATL08770
      DIMENSION NORTS(2,NKIND),NBORB(2,MSCHL)                           ATL08780
      DIMENSION NSTOR(MSCHL),MAXOC(MSCHL)                               ATL08790
      DIMENSION NTOPN(NKIND)                                            ATL08800
      INTEGER * 2 NCONF(MSCH1,MCONF)                                    ATL08810
      INTEGER * 2 WKCONF(MSDUMY,NREFN)                                  ATL08820
      DATA APO/1H'/                                                     ATL08830
      IF(LPOUT.GT.0) CALL ATBIGN('ATSGEN')                              ATL08840
      IF(LPOUT.GT.50) THEN                                              ATL08850
C        WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATSGEN ********'     ATL08860
C        WRITE(6,*) ' ** GIVEN PARAMETERS ARE FOLLOWING   ********'     ATL08870
C        WRITE(6,'(2X,''MKIND,NKIND,MSCHL       = '',4I5)')             ATL08880
C    *                  MKIND,NKIND,MSCHL                               ATL08890
C        WRITE(6,'(2X,''MCONF,NCLET,MSCH1       = '',4I5)')             ATL08900
C    *                  MCONF,NCLET,MSCH1                               ATL08910
C        WRITE(6,'(2X,''NPRTY = '',15I4)') (NPRTY(I),I=1,NKIND)         ATL08920
C        WRITE(6,'(2X,''MOCCN = '',15I4)') (MOCCN(I),I=1,NKIND)         ATL08930
C        WRITE(6,'(2X,''NORBT = '',15I4)') (NORBT(I),I=1,NKIND)         ATL08940
C        WRITE(6,'(2X,''NSCHL = '',15I4)') (NSCHL(I),I=1,NKIND)         ATL08950
C        WRITE(6,'(2X,''CORBT =  '',15(2X,A1,1X)/11X,15(2X,A1,1X))')    ATL08960
C    *                                             (CORBT(I),I=1,NCLET) ATL08970
C        WRITE(6,'(2X,''CSCHL =  '',15(2X,A1,1X)/11X,15(2X,A1,1X))')    ATL08980
C    *                                             (CSCHL(I),I=1,MSCHL) ATL08990
C        WRITE(6,'(/1X,''== READED REFERENCE CONFIGURATION =='')')      ATL09000
C        WRITE(6,'(/1X,''-TYPE-      NO.    '',15(2X,A1,1X)')           ATL09010
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL09020
C        WRITE(6,'(1X,''-NAME-   '',10X,15(1X,A2,1X)')                  ATL09030
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL09040
C        WRITE(6,'(/1X,''NCONF = '',I10,5X,15I4)')                      ATL09050
C    *         J,(NCONF(I,J),I=1,MSCHL)                                 ATL09060
C        DO 40 J=2,NREFN                                                ATL09070
C  40       WRITE(6,'(1X,''        '',I10,5X,15I4)')                    ATL09080
C    *            J,(WKCONF(I,J),I=1,MSCHL)                             ATL09090
         ENDIF                                                          ATL09100
C ------- SINGLE EXCITATIONS         ---------------------------        ATL09110
      DO 52 I = 1, NREFN                                                ATL09120
         DO 50 J = 1, MSCHL+1                                           ATL09130
            NCONF(J,I) = WKCONF(J,I)                                    ATL09140
   50       CONTINUE                                                    ATL09150
         DO 51 J = MSCHL+2, MSCH1                                       ATL09160
            NCONF(J,I) = 0                                              ATL09170
   51       CONTINUE                                                    ATL09180
   52    CONTINUE                                                       ATL09190
      NSA=1                                                             ATL09200
      NCO=NREFN                                                         ATL09210
      DO 68 I=1,NREFN                                                   ATL09220
         JEND=MSCHL-1                                                   ATL09230
         DO 66  J=1,JEND                                                ATL09240
            NDAM=NCONF(J,I)-NSA                                         ATL09250
            IF(NDAM.LT.0) GO TO 66                                      ATL09260
            DO 64 K=1,MSCHL                                             ATL09270
               IF(K.EQ.J) GO TO 64                                      ATL09280
               MDAM=NCONF(K,I)+NSA                                      ATL09290
               IF(MDAM.GT.MAXOC(K)) GO TO 64                            ATL09300
               NCO=NCO+1                                                ATL09310
               IF( NCO .GT. MCONF ) THEN                                ATL09320
                  WRITE(6,*) ' == NEED MORE CORE == EMERGENCY STOP '    ATL09330
                  STOP                                                  ATL09340
                  END IF                                                ATL09350
               DO 56 L=1,MSCHL                                          ATL09360
   56             NCONF(L,NCO)=NCONF(L,I)                               ATL09370
               DO 57 L=MSCHL+1,MSCH1                                    ATL09380
   57             NCONF(L,NCO)=0                                        ATL09390
               NCONF(J,NCO)=NDAM                                        ATL09400
               NCONF(K,NCO)=MDAM                                        ATL09410
               NCO1=NCO-1                                               ATL09420
               DO 60 LL=1,NCO1                                          ATL09430
                  DO 58 L=1,MSCHL                                       ATL09440
   58                IF(NCONF(L,NCO).NE.NCONF(L,LL)) GO TO 60           ATL09450
* CHECK SAME OCCUPATIONS                                                ATL09460
                  NCO=NCO1                                              ATL09470
                  KR = MSCHL + 1 + (I-1) * 4                            ATL09480
                  NCONF(KR+1,LL)=J                                      ATL09490
                  NCONF(KR+2,LL)=K                                      ATL09500
                  GOTO 64                                               ATL09510
   60             CONTINUE                                              ATL09520
*              IF ( NCO .EQ. NCO1 ) GOTO 64                             ATL09530
* CLEAR REF                                                             ATL09540
               KR = MSCHL + 1 + (I-1) * 4                               ATL09550
               NCONF(KR+1,NCO)=J                                        ATL09560
               NCONF(KR+2,NCO)=K                                        ATL09570
               NCONF(MSCHL+1,NCO) = NPRTY(NSTOR(J))*NPRTY(NSTOR(K))     ATL09580
   64          CONTINUE                                                 ATL09590
   66       CONTINUE                                                    ATL09600
   68    CONTINUE                                                       ATL09610
      NSCON=NCO                                                         ATL09620
      IF(LPOUT.GT.30) THEN                                              ATL09630
         WRITE(6,*) ' ******** DEBUG OUTPUT IN SUB.ATSGEN ********'     ATL09640
         WRITE(6,*) ' ** GENERATED PARAMETERS ARE FOLLOWING     **'     ATL09650
C        WRITE(6,'(2X,''NREFN,NSCON             = '',2I5)')             ATL09660
C    *                  NREFN,NSCON                                     ATL09670
C        WRITE(6,'(/2X,''-TYPE-   '',15(2X,A1,1X)')                     ATL09680
C    *        (CORBT(I),I=1,NKIND)                                      ATL09690
C        WRITE(6,'(2X,''NORTS = '',15I4)') (NORTS(1,I),I=1,NKIND)       ATL09700
C        WRITE(6,'(2X,''        '',15I4)') (NORTS(2,I),I=1,NKIND)       ATL09710
C        WRITE(6,'(/2X,''-TYPE-   '',15(2X,A1,1X)')                     ATL09720
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL09730
C        WRITE(6,'(2X,''-NAME-   '',15(1X,A2,1X)')                      ATL09740
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL09750
C        WRITE(6,'(2X,''NSTOR = '',15I4)') (NSTOR(I),I=1,MSCHL)         ATL09760
C        WRITE(6,'(2X,''MAXOC = '',15I4)') (MAXOC(I),I=1,MSCHL)         ATL09770
C        WRITE(6,'(2X,''NBORB = '',15I4)') (NBORB(1,I),I=1,MSCHL)       ATL09780
C        WRITE(6,'(2X,''        '',15I4)') (NBORB(2,I),I=1,MSCHL)       ATL09790
         J=1                                                            ATL09800
C        WRITE(6,'(/1X,''== READED REFERENCE CONFIGURATION =='')')      ATL09810
C        WRITE(6,'(/1X,''-TYPE-      NO.    '',15(2X,A1,1X)')           ATL09820
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL09830
C        WRITE(6,'(1X,''-NAME-   '',10X,15(1X,A2,1X)')                  ATL09840
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL09850
C        WRITE(6,'(/1X,''NCONF = '',I10,5X,15I4)')                      ATL09860
C    *         J,(NCONF(I,J),I=1,MSCHL)                                 ATL09870
C        DO 80 J=2,NREFN                                                ATL09880
C  80       WRITE(6,'(1X,''        '',I10,5X,15I4)')                    ATL09890
C    *            J,(NCONF(I,J),I=1,MSCHL)                              ATL09900
         J=NREFN+1                                                      ATL09910
C        WRITE(6,'(/1X,''== SINGLE EXCITED CONFIGURATION =='')')        ATL09920
C        WRITE(6,'(/1X,''-TYPE-         NO. '',15(2X,A1,1X)')           ATL09930
C    *        (CORBT(NSTOR(I)),I=1,MSCHL)                               ATL09940
C        WRITE(6,'(1X,''-NAME-   '',10X,15(1X,A2,1X)')                  ATL09950
C    *        (CSCHL(I),I=1,MSCHL)                                      ATL09960
C        WRITE(6,'(1X,''NCONF = '',I10,15I4)')                          ATL09970
C    *         J,(NCONF(I,J),I=1,MSCH1)                                 ATL09980
         JTOP = J + 1                                                   ATL09990
C        DO 82 J=JTOP,NSCON                                             ATL10000
C            IF(MOD(J,10).EQ.0) THEN                                    ATL10010
C              WRITE(6,'(/1X,''-TYPE-         NO. '',15(2X,A1,1X)')     ATL10020
C    *              (CORBT(NSTOR(I)),I=1,MSCHL)                         ATL10030
C              WRITE(6,'(1X,''-NAME-   '',10X,15(1X,A2,1X)')            ATL10040
C     *           (CSCHL(I),I=1,MSCHL)                                  ATL10050
C              ENDIF                                                    ATL10060
C 82       WRITE(6,'(1X,''        '',I10,15I4)')                        ATL10070
C    *            J,(NCONF(I,J),I=1,MSCH1)                              ATL10080
         ENDIF                                                          ATL10090
      IF(LPOUT.GT.0) CALL ATENDS('ATSGEN')                              ATL10100
      RETURN                                                            ATL10110
      END                                                               ATL10120
C*DECK CPUTIME
      subroutine cputime(time,irtncd)
c     TIME is written back into REAL*8 destinations (SCTIME(*), XTIME) at
c     the call sites; declare it REAL*8 so the full 8 bytes are set.  As an
c     implicit REAL*4 dummy it wrote only 4 of 8 bytes, corrupting the
c     caller's REAL*8 value.  (The 1000*itime expression is unchanged.)
      real*8 time
      call clockm(itime)
      time=1000*itime
      irtncd=0
      return
      end
C*DECK ATTIME                                                           ATL10130
      SUBROUTINE ATTIME                                                 ATL10140
C====================================================================   ATL10150
C   PRINT OUT C-TIME AND E-TIME                                         ATL10160
C                         CODED   BY  U.NAGASHIMA                       ATL10170
C                         REVISED BY  TASHI                             ATL10180
C   CHANGED TO DUMMY ROUTINE BY TASHI AT KGN ON 11/16/89                ATL10190
C                                                                       ATL10200
C====================================================================   ATL10210
C                                                                       ATL10220
C    ARREY ------- GEVEN --------------                                 ATL10230
C                                                                       ATL10240
C    CSUB   : SUBROUTINE NAME WHICH CALL THIS SUBROUTINE. C*6           ATL10250
C                                                                       ATL10260
C    ARREY ------- RETURN -------------                                 ATL10270
C                                                                       ATL10280
C====================================================================   ATL10290
C     CHARACTER CDATE*8,CSUB1*(*),CSUB2*(*)                             ATL10300
C     CHARACTER CTIME*12,KO*1,PI*1   
C     DIMENSION IETIME(100)                                             ATL10320
      CHARACTER CSUB1*(*),CSUB2*(*)            
      CHARACTER KO*1,PI*1  
      REAL * 8 SCTIME(100),XTIME                                        ATL10330
      data      KO/':'/,PI/'.'/ 
      NSTACK=0                                                          ATL10340
C        CALL DATE(CDATE)                                               ATL10350
C        CALL CLOCK                                                     ATL10360
      RETURN                                                            ATL10370
      ENTRY ATBIGN(CSUB1)                                               ATL10380
         NSTACK=NSTACK+1                                                ATL10390
C        CALL CLOCK(CTIME,1)                                            ATL10400
C        CALL CLOCK(CTIME,1)                                            ATL10410
C        CALL CLOCK(SCTIME(NSTACK),5)                                   ATL10420
C        CALL CLOCK(IETIME(NSTACK),2)                                   ATL10430
C        CTIME(3:3)=KO                                                  ATL10440
C        CTIME(6:6)=KO                                                  ATL10450
C        CTIME(9:9)=PI                                                  ATL10460
C        WRITE(6,70000)                                                 ATL10470
C    *   CSUB,CDATE,CTIME                                               ATL10480
70000    FORMAT(1X,'== SUB.',A6,                                        ATL10490
     *    ' BIGIN == DATE ',A8,'  TIME ',A12)                           ATL10500
CMAS  IBM VERSION                                                       ATL10510
         WRITE(6,80000) CSUB1                                           ATL10520
         CALL CPUTIME(SCTIME(NSTACK),IRTNCD)                            ATL10530
80000    FORMAT(1X,'== SUB ',A6,                                        ATL10540
     *    ' BIGIN == ')                                                 ATL10550
      RETURN                                                            ATL10560
      ENTRY ATENDS(CSUB2)                                               ATL10570
C        CALL CLOCK(CTIME,1)                                            ATL10580
C        CALL CLOCK(TIME2,5)                                            ATL10590
C        CALL CLOCK(ITIME2,2)                                           ATL10600
C        CTIME(3:3)=KO                                                  ATL10610
C        CTIME(6:6)=KO                                                  ATL10620
C        CTIME(9:9)=PI                                                  ATL10630
C        TIME3=TIME2-SCTIME(NSTACK)                                     ATL10640
C        ITIME3=(ITIME2-IETIME(NSTACK))*0.01E00                         ATL10650
C        ITIME2= ITIME2*0.01E00                                         ATL10660
C        NSTACK=NSTACK-1                                                ATL10670
C        WRITE(6,70001)                                                 ATL10680
C    *   CSUB,CDATE,CTIME,TIME3,ITIME3,TIME2,ITIME2                     ATL10690
CMAS  IBM VERSION                                                       ATL10700
         CALL CPUTIME(XTIME,IRTNCD)                                     ATL10710
C
         XTIME = XTIME - SCTIME(NSTACK)                                 ATL10720
         NSTACK = NSTACK - 1                                            ATL10730
         WRITE(6,80001) CSUB2,XTIME/1000                                ATL10740
80001    FORMAT(1X,'== SUB ',A6,                                        ATL10750
     *    ' END   == ', F15.1,' M SEC ')                                ATL10760
70001    FORMAT(1X,'== SUB.',A6,                                        ATL10770
     *    ' END   == DATE ',A8,'   TIME ',A12,                          ATL10780
     *    '  C & E-TIME (SEC.)= ',F6.3,1X,I5,                           ATL10790
     *    '  USED C & E-TIME (SEC.)= ',F6.3,1X,I5)                      ATL10800
      RETURN                                                            ATL10810
      END                                                               ATL10820
