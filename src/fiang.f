C*DECK FIANG
      SUBROUTINE FIANG(ISB,IRB,
     *      N1,N2,L,LS,LR,M,JM,JS,JR,KM,KS,KR,  JL,JG,KL,KG)
C                                 CHECKED TASHI 10/25/89 HUCC
      EXTERNAL IOR,ISP
      DIMENSION JM(5),JS(6),JR(6),KM(5),KS(6),KR(6)
      DIMENSION ISB(2),IRB(2)
C
      GO TO (7,21,7,21,8,8,7,8,9),L
    7 IF (JM(M).NE.KM(M)) GO TO 10
      GO TO 11
    8 IF (JS(M).NE.KS(M).OR.JR(M).NE.KR(M)) GO TO 10
      GO TO 11
    9 IF (JM(M).EQ.KM(M)) GO TO 8
   10 JG=-1
      RETURN
   11 GO TO (21,21,23,21,21,26,27,26,12),L
   21 JMS=LS
      JMR=LR
      GO TO 30
   23 JMS=ISB(N1)
      JMR=IRB(N1)
      GO TO 30
   26 JMR=IRB(M)
      JMS=ISB(M)
      GO TO 30
   27 JMS=ISB(N2)
      JMR=IRB(N2)
   30 KMT=KM(M)
      KMS=ISP(KMT)
      KMR=IOR(KMT)
      KSL=IABS(KMS-KS(M))+1
      KRL=IABS(KMR-KR(M))+1
      KSG=KMS+KS(M)-1
      KRG=KMR+KR(M)-1
      LL=IABS(JMS-JS(M+1))+1
      ML=IABS(JMR-JR(M+1))+1
      LG=JMS+JS(M+1)-1
      MG=JMR+JR(M+1)-1
      JL=MAX0(KSL,LL)
      KL=MAX0(KRL,ML)
      JG=MIN0(KSG,LG)
      KG=MIN0(KRG,MG)
      IF(JG.LT.JL) GO TO 10
      IF(KG.LT.KL) GO TO 10
      RETURN
   12 JL=JS(M+1)
      JG=JL
      KL=JR(M+1)
      KG=KL
      RETURN
      END
