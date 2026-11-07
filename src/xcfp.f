C*DECK XCFP
      FUNCTION XCFP(IM,KM,KMP,ID)
C     FUNCTION QCFP( ICONNT, ILFUNC, CMTTBL, ICMTDX )
      IMPLICIT REAL*8(A-H,O-Z)
C     DIMENSION ICONNT(9,*),ILFUNC(*),CMTTBL(*),ICMTDX(5,*),DEN(*)
      include 'include/COMCFP'
      include 'include/COMWIG'
      save itsta
      data itsta/0/
C
      XCFP=0.0D0
      CFPV=0.0D0
C     LPX=KM
C     LMTX=LP3
C     KSHL=MTX
C     LMTX=LP4
C     K=MTX
      kshl = km/256
      k = and(255,km)
C     LPX=IM
C     LMTX=LP3
C     ISHL=MTX
C     LMTX=LP4
C     I=MTX
      ishl = im/255
      i = and(255,im)
      LFO=ICONNT(1,KSHL)
      IF(ICONNT(1,ISHL).NE.LFO) GO TO 9002
      KMU=ICONNT(2,KSHL)
      IMU=ICONNT(2,ISHL)
      ISP=ICONNT(3,ISHL)
      KSP=ICONNT(3,KSHL)
C        ITYP       POSITION OF I IS INDICATED BY THE CORRESPONDING
C
C                   ITYP NUMBER
C
C              1           3
C                *       *
C                  *   *
C                    K
C                  *   *
C                *       *
C              2           4
C
C             IMU AXIS  HORIZONTAL
C             ISP AXIS  VERTICAL
C
      ITYP=0
      IF(KMU-IMU.NE.1) GO TO 100
      ICFT=0
      IF(ISP-KSP.NE.1) GO TO 10
      ITYP=1
      ICFT=ICONNT(6,KSHL)
      GO TO 11
  100 IF(KMU-IMU.NE.-1) GO TO 1000
      IF(ISP-KSP.NE.1) GO TO 20
      ITYP=3
      ICFT=ICONNT(8,KSHL)
      GO TO 11
   20 IF(ISP-KSP.NE.-1) GO TO 1000
      ITYP=4
      ICFT=ICONNT(9,KSHL)
      GO TO 11
   10 IF(ISP-KSP.NE.-1) GO TO 1000
      ITYP=2
      ICFT=ICONNT(7,KSHL)
   11 IF(ICFT.EQ.0) GO TO 1000
      NSTAD=ICMTDX(1,ICFT)
      IF(ITYP.GE.3) GO TO 1
      IDIM=ICONNT(4,ISHL)
      NCFP=NSTAD+I+(K-1)*IDIM-1
      GO TO 2
    1 KDIM=ICONNT(4,KSHL)
      NCFP=NSTAD+K+(I-1)*KDIM-1
    2 CFPV=CMTTBL(NCFP)
      IF(ITYP.LT.3) GO TO 212
      ILAD=ICONNT(5,ISHL)
      KLAD=ICONNT(5,KSHL)
      INAD=ILAD+I-1
      KNAD=KLAD+K-1
      IPAR=LFO+ILFUNC(INAD)-ILFUNC(KNAD)+2*ITYP+400
      IF(MOD(IPAR,4).EQ.3) GO TO 212
      CFPV=-CFPV
  212 IQKZ=KMP-LFO
      IF(ID.EQ.1) GO TO 242
      KT=KMU
      KMU=IMU
      IMU=KT
      IQKZ=IQKZ-1
  242 IKP=(KMU+IQKZ+1)/2
      IKM=IKP-IQKZ
      IIM=(IMU-IQKZ)/2
      IIP=IIM+IQKZ+1
      ISUM=(IMU+KMU+3)/2
      XCFP=CFPV*                                    DEN(IKM)*DEN(IIP)*
     1   DELTA(2,KMU,IMU)/(DEN(IKP)*DEN(IIM)*DEN(ISUM))
      IF(ID.EQ.1) GO TO 243
      IF(MOD(KMU*3+IMU,4).EQ.3) XCFP=-XCFP
      GO TO 1000
  243 IF(MOD(KMU+KMU+IMU+IMU,4).EQ.0) XCFP=-XCFP
 1000 IF(ITSTA.NE.0) WRITE(6,9500) IM,KM,KMP,ID,XCFP  ,CFPV
*9500 FORMAT(' CFP   ',4I6,2F25.13)    MODIFYED MAS 86/06/23
 9500 FORMAT(' CFP   ',2X,Z4,2X,Z4,2I6,11X,2F25.13)
      RETURN
C
C     ENTRY QCFP(ICONNT,ILFUNC,CMTTBL,ICMTDX)
C     ITEST1=1
C     RETURN
C     ENTRY QCFTB(DEN)
C     IF(ITEST1.EQ.1) ITEST=1
C     RETURN
C
 9002 WRITE(6,9003) IM,KM
 9003 FORMAT(' CFP MISMATCH     IM =',I10,5X,'KM =',I10,'  ********')
      RETURN
C
      ENTRY TCFP(ICFP)
      ITSTA = ICFP
      RETURN
      END
