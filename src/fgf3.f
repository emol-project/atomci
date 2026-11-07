C*DECK FGF3
      FUNCTION FGF3(IA,IB,K,DA,DB)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8(A-H,O-Z)
      REAL*8 DUMMY
C     DIMENSION FAC(57)
      include 'include/COMWIG'
      DT=DA+DB
      IT=IA+IB
      NP=IB-K-1
      MQ=IA+K
      FX=1.0D+0
      IF(NP.EQ.0) GO TO 90
      DO 5 NN=1,NP
    5 FX=1.0D+0+FX*DT*DFLOAT(NN)/(DB*DFLOAT(MQ+NN))
   90 FX=FX/DB
      IF(IA.NE.IB.OR.DA.NE.DB) GO TO 8
      FY=FX
      GO TO 3
    8 NP=IA-K-1
      MQ=IB+K
      FY=1.0D+0
      IF(NP.EQ.0) GO TO 1
      DO 6 NN=1,NP
    6 FY=1.0D+0+FY*DT*DFLOAT(NN)/(DA*DFLOAT(MQ+NN))
    1 FY=FY/DA
*     ***** CONVERTED MASAHIRO ******
*   3 FGF3=(FX+FY)*FAC(IT)/DT**IT
    3 DUMMY=FAC(IT)/DT**IA
      FGF3=DUMMY*(FX+FY)/DT**IB
      RETURN
      END
C*DECK FGF3G
      FUNCTION FGF3G(IA,IB,K,DA,DB)
*
*     CALCULATE TWO ELECTRON INTEGRALS
*                            CODED   BY TASHI ON NOV.'84 AT HUCC
*                            REVISED BY TASHI ON OCT.'89 AT HUCC
*
*       MOD(IA,2) = MOD(IB,2) = MOD(K,2)
*
*       FGF3G(IA,IB,K,DA,DB)
*     = I(0,INF:S ; S,INF:R)  S**(IB+K)  EXP(-DB*S**2)     R > S
*                           * R**(IA-K-1)EXP(-DA*R**2)
*     + I(0,INF:R ; R,INF:S)  R**(IA+K)  EXP(-DA*R**2)     R < S
*                           * S**(IB-K-1)EXP(-DB*S**2)
*       ,WHERE IA-K-1, IB-K-1 = ODD
*
*     = G(IB+K,IA-K-1,DA) + G(IA+K,IB-K-1,DB)
*
*     DT = DA + DB
*     M  = IB + K,     IA + K
*     N  = IA - K - 1, IB - K - 1
*     IT = N + M - 1 = IA + IB - 2
*     F  = 2 * DA    , 2 * DB
*
*     G  =   1                 / F**1 * RGAUSS(IT,  DT)
*          + (N-1)             / F**2 * RGAUSS(IT-2,DT)
*          + (N-1)*(N-3)       / F**3 * RGAUSS(IT-4,DT)
*          ...
*          + (N-1)*(N-3)...4   / F**[(N-1)/2] * RGAUSS(M+2,DT)
*          + (N-1)*(N-3)...4*2 / F**[(N+1)/2] * RGAUSS(M, ,DT)
*
*
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION RG(50)
C     DIMENSION GAMMA(114)
      include 'include/COMWIG'
*
      IT = IA + IB - 2
C                                             " SET CONSTANT
      DT = DA + DB
*
*     CALCULATE RGAUSS(IT-2I,DT), I=0 TO (N-1)/2
*
      IOUT = ( MAX0(IA,IB) - K - 2 ) / 2
      NN = IT
C     CHANGED BY TASHI AT KGN    12/0
C     RG(1) = 0.5D0 * GAMMA(NN+1) / ( DSQRT(DT)**(NN+1) )
      RG(1) = 0.5D0 * GAMMA(NN+1) * ( 1.D0/DSQRT(DT) )**(NN+1)
      F = 2.D0 * DT
      DO 10 I = 1, IOUT
         NN = NN - 2
         RG(I+1) = RG(I) * F / DFLOAT(NN+1)
   10    CONTINUE
*
*     CASE R > S ( CALCULATE FX )
*
      NN = IA - K
      F = 1.D0 / ( 2.D0 * DA )
      FACTOR = F
      IOUT = ( IA - K - 2 ) / 2
      FX = FACTOR * RG(1)
      DO 20 I = 1, IOUT
         NN = NN - 2
         FACTOR = F * DFLOAT(NN) * FACTOR
         FX = FX + FACTOR * RG(I+1)
   20    CONTINUE
*
*     CASE R < S ( CALUCATE GX )
*
      NN = IB - K
      F = 1.D0 / ( 2.D0 * DB )
      FACTOR = F
      IOUT = ( IB - K - 2 ) / 2
      GX = FACTOR * RG(1)
      DO 30 I = 1, IOUT
         NN = NN - 2
         FACTOR = F * DFLOAT(NN) * FACTOR
         FX = FX + FACTOR * RG(I+1)
   30    CONTINUE
*
      FGF3G = FX + GX
      RETURN
*
      END
