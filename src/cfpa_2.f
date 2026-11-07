      FUNCTION   WIG6J(IA,IB,IC,ID,IE,IV)
      IMPLICIT   DOUBLE PRECISION (A-H,O-Z)
      DIMENSION  RT(57),DEN(57),FAC(57)
      SAVE       RT,DEN,FAC
      ZIZ(I)= DBLE ((-1)**(I/2+1))
      IF (IA.EQ.1) GO TO 1
      IF (IB.EQ.1) GO TO 2
      IF (IC.EQ.1) GO TO 3
      IF (ID.EQ.1) GO TO 4
      IF (IE.EQ.1) GO TO 5
      IF (IV.EQ.1) GO TO 6
      A=DELTA(IA,IB,IC)*DELTA(ID,IE,IC)*DELTA(ID,IB,IV)*DELTA(IA,IE,IV)
      IF (A) 20,20,110
  900 WRITE(6,999) IP,IA,IB,IC,ID,IE,IV
  999 FORMAT(///5X,33H***** WIG6J RANGE EXCEEDS 56  IP=,I5,6H   PAR,
     1   3HAM=,6I3,6H *****///)
   20 WIG6J=0.0D0
      RETURN
    1 IF (IB.NE.IC.OR.IE.NE.IV)  GO TO 20
      IF (DELTA(ID,IE,IC).EQ.0.0D0) GO TO 20
      WIG6J=ZIZ(ID+IE+IC)/(RT(IB+1)*RT(IE+1))
      RETURN
    2 IF (IA.NE.IC.OR.ID.NE.IV)  GO TO 20
      IF (DELTA(ID,IE,IC).EQ.0.) GO TO 20
      WIG6J=ZIZ(ID+IE+IC)/(RT(IA+1)*RT(ID+1))
      RETURN
    3 IF (IA.NE.IB.OR.ID.NE.IE)  GO TO 20
      IF (DELTA(IA,IE,IV).EQ.0.) GO TO 20
      WIG6J=ZIZ(IA+IE+IV)/(RT(IA+1)*RT(ID+1))
      RETURN
    4 IF (IV.NE.IB.OR.IC.NE.IE)  GO TO 20
      IF (DELTA(IA,IB,IC).EQ.0.) GO TO 20
      WIG6J=ZIZ(IA+IB+IC)/(RT(IB+1)*RT(IC+1))
      RETURN
    5 IF (IV.NE.IA.OR.IC.NE.ID)  GO TO 20
      IF (DELTA(IA,IB,IC).EQ.0.) GO TO 20
      WIG6J=ZIZ(IA+IB+IC)/(RT(IA+1)*RT(IC+1))
      RETURN
    6 IF (IE.NE.IA.OR.IB.NE.ID)  GO TO 20
      IF (DELTA(IA,IB,IC).EQ.0.) GO TO 20
      WIG6J=ZIZ(IA+IB+IC)/(RT(IA+1)*RT(IB+1))
      RETURN
  110 IK=(IA+IB+IC)/2
      IL=(ID+IE+IC)/2
      IM=(ID+IB+IV)/2
      IN=(IA+IE+IV)/2
      KK=(IA+IB+ID+IE-2)/2
      KL=(IA+IC+ID+IV-2)/2
      KM=(IB+IC+IE+IV-2)/2
      IQ=MAX0(IK,IL,IM,IN)
      IP=MIN0(KK,KL,KM)
      G=0.0D0
      IF(IP.GT.56) GO TO 900
      DO 15 IR=IQ,IP
      JK=IR-IK+1
      JL=IR-IL+1
      JM=IR-IM+1
      JN=IR-IN+1
      LK=KK-IR+1
      LL=KL-IR+1
      LM=KM-IR+1
   15 G=G-DBLE((-1)**IR)*FAC(IR+1)/
     1  (FAC(JK)*FAC(JL)*FAC(JM)*FAC(JN)*FAC(LK)*FAC(LL)*FAC(LM))
      WIG6J =G*A/(DEN(IK+1)*DEN(IL+1)*DEN(IM+1)*DEN(IN+1))
      RETURN
      ENTRY PWIG6J
      FAC(1)=1.0D0
      DO 93 K=1,57
      IF (K.EQ.1) GO TO 92
      FAC(K)= FAC(K-1)*DBLE(K-1)
   92 DEN(K)= DSQRT(FAC(K))
   93 RT(K) = DSQRT(DBLE(K-1))
      RETURN
      END
      FUNCTION  WIG9X(IA,IB,IC,ID,IE,IV,IG,IH,II)
      IMPLICIT   DOUBLE PRECISION (A-H,O-Z)
      WIG9X=0.0D0
      KL=MIN0(IA+II,ID+IH,IB+IV)-1
      KS=MAX0(IABS(IA-II),IABS(ID-IH),IABS(IB-IV))+1
      IF (KS.GT.KL.OR.MOD(KL-KS,2).NE.0) RETURN
      DO 1 IR=KS,KL,2
    1 WIG9X=WIG9X+DBLE(IR)*WIG6J(IA,IB,IC,IV,II,IR)
     1     *WIG6J(ID,IE,IV,IB,IR,IH)*WIG6J(IG,IH,II,IR,IA,ID)
      WIG9X=-WIG9X*DBLE((-1)**KS)
      RETURN
      END
      FUNCTION  F3L(IA,IB,IC)
      IMPLICIT   DOUBLE PRECISION (A-H,O-Z)
      DIMENSION  FASQ(154), FAC(57)
      SAVE       FASQ,  FAC
      F3L=DELTA(IA,IB,IC)
      IF (F3L.EQ.0.0D0) RETURN
      IT=(IA+IB+IC+1)/4
      IU=IA+IB+IC+40
      I1=(IA+IB-IC+3)/4
      I2=(IB+IC-IA+3)/4
      I3=(IC+IA-IB+3)/4
      F3L=F3L*FAC(IT)/(FASQ(IU)*FAC(I1)*FAC(I2)*FAC(I3))
      RETURN
      ENTRY PF3L
      DO 1 K=1,154
    1 FASQ(K)=0.
      FAC(1)=1.0D0
      DO 2 K=1,57
      IF (K.EQ.1) GO TO 2
      FAC(K)= FAC(K-1)*DBLE(K-1)
    2 FASQ(2*K+39)= DSQRT(FAC(K))
      RETURN
      END
      FUNCTION  DELTA (IA,IB,IC)
      IMPLICIT   DOUBLE PRECISION (A-H,O-Z)
      DIMENSION  FASQ(154)
      SAVE       FASQ
      I1= IA+IB-IC+40
      I2= IA-IB+IC+40
      I3=-IA+IB+IC+40
      DELTA=FASQ(I1)*FASQ(I2)*FASQ(I3)
      RETURN
      ENTRY PDELTA
      DO 1 K=1,154
    1 FASQ(K)=0.0D0
      FAC = 1.0D0
      DO 3 K=1,57
      IF (K.EQ.1) GO TO 3
      FAC = FAC*DBLE(K-1)
    3 FASQ(2*K+39) = DSQRT(FAC)
      RETURN
      END
      SUBROUTINE PRTCPU ( TREF,MSG )
      REAL T
      INTEGER TREF
      CHARACTER * (*) MSG
      CHARACTER * 44  PMSG
      PMSG =      ' -------------------------------------------'
      MLEN = LEN (MSG)
      IP   = 44-MLEN
      PMSG (IP:)   = ' '
      PMSG (IP+1:) = MSG
      CALL CLOCKM(IT)
      T=FLOAT(IT-TREF)/1000.0
      WRITE(6,100)  PMSG, T
  100 FORMAT( A, '    USED TIME =', F10.2,' SEC')
      RETURN
      END
