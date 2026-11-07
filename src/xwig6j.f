C*DECK XWIG6J
      FUNCTION XWIG6J(I1,I2,I3,I4,I5,I6)
C     FUNCTION QWIG6J ( RT, FASQ, DEN, FAC )
      IMPLICIT   REAL*8(A-H,O-Z)
C     DIMENSION RT(57), FASQ(154), DEN(57), FAC(57)
      include 'include/COMWIG'
C     SAVE
      ZIZ(I) = DFLOAT( (-1)**(I/2+1) )
C
      IA=I1
      IB=I2
      IC=I3
      ID=I4
      IE=I5
      IV=I6
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
   20 XWIG6J=0.
      go to 1000
    1 IF (IB.NE.IC.OR.IE.NE.IV)  GO TO 20
      IF (DELTA(ID,IE,IC).EQ.0.) GO TO 20
      XWIG6J=ZIZ(ID+IE+IC)/(RT(IB+1)*RT(IE+1))
      go to 1000
    2 IF (IA.NE.IC.OR.ID.NE.IV)  GO TO 20
      IF (DELTA(ID,IE,IC).EQ.0.) GO TO 20
      XWIG6J=ZIZ(ID+IE+IC)/(RT(IA+1)*RT(ID+1))
      go to 1000
    3 IF (IA.NE.IB.OR.ID.NE.IE)  GO TO 20
      IF (DELTA(IA,IE,IV).EQ.0.) GO TO 20
      XWIG6J=ZIZ(IA+IE+IV)/(RT(IA+1)*RT(ID+1))
      go to 1000
    4 IF (IV.NE.IB.OR.IC.NE.IE)  GO TO 20
      IF (DELTA(IA,IB,IC).EQ.0.) GO TO 20
      XWIG6J=ZIZ(IA+IB+IC)/(RT(IB+1)*RT(IC+1))
      go to 1000
    5 IF (IV.NE.IA.OR.IC.NE.ID)  GO TO 20
      IF (DELTA(IA,IB,IC).EQ.0.) GO TO 20
      XWIG6J=ZIZ(IA+IB+IC)/(RT(IA+1)*RT(IC+1))
      go to 1000
    6 IF (IE.NE.IA.OR.IB.NE.ID)  GO TO 20
      IF (DELTA(IA,IB,IC).EQ.0.) GO TO 20
      XWIG6J=ZIZ(IA+IB+IC)/(RT(IA+1)*RT(IB+1))
      go to 1000
  110 IK=(IA+IB+IC)/2
      IL=(ID+IE+IC)/2
      IM=(ID+IB+IV)/2
      IN=(IA+IE+IV)/2
      KK=(IA+IB+ID+IE-2)/2
      KL=(IA+IC+ID+IV-2)/2
      KM=(IB+IC+IE+IV-2)/2
      IQ=MAX0(IK,IL,IM,IN)
      IP=MIN0(KK,KL,KM)
      G=0.
      IF(IP.GT.56) GO TO 900
      DO 15 IR=IQ,IP
      JK=IR-IK+1
      JL=IR-IL+1
      JM=IR-IM+1
      JN=IR-IN+1
      LK=KK-IR+1
      LL=KL-IR+1
      LM=KM-IR+1
   15 G=G-
     1   DFLOAT((-1)**IR)*FAC(IR+1)/(FAC(JK)*FAC(JL)*FAC(JM)*FAC(JN)*
     2   FAC(LK)*FAC(LL)*FAC(LM))
      XWIG6J =G*A/(DEN(IK+1)*DEN(IL+1)*DEN(IM+1)*DEN(IN+1))
 1000 continue
C     write(6,*)'wig6j:',xwig6j,ia,ib,ic,id,ie,iv
      RETURN
C     ENTRY QWIG6J (RT,FASQ,DEN,FAC)
C     RETURN
      END
C*DECK XWIG9X
C
      FUNCTION XWIG9X(IA,IB,IC,ID,IE,IV,IG,IH,II)
      IMPLICIT   REAL*8(A-H,O-Z)
      XWIG9X=0.0
      KL=MIN0(IA+II,ID+IH,IB+IV)-1
      KS=MAX0(IABS(IA-II),IABS(ID-IH),IABS(IB-IV))+1
      IF (KS.GT.KL.OR.MOD(KL-KS,2).NE.0) RETURN
      DO 1 IR=KS,KL,2
    1 XWIG9X=XWIG9X+
     1           DFLOAT(IR)*WIG6J(IA,IB,IC,IV,II,IR)*
     2   WIG6J(ID,IE,IV,IB,IR,IH)*WIG6J(IG,IH,II,IR,IA,ID)
      XWIG9X=-XWIG9X*
     1            DFLOAT((-1)**KS)
      RETURN
      END
