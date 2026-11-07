C*DECK SCHMIT 
      SUBROUTINE SCHMIT(MS,SS,AS,SBAR) 
C     SCHMIDT ORTHO-NORMALIZATION                                               
C     MS NUMBER OF VECTORS TO BE PROCESSED  SHOULD BE LARGER THAN 2             
C     SS OVERLAP MATRIX OF ORIGINAL VECTORS                                     
C     AS ANSWERS   COEFFICIENT MATRIX A                                         
      IMPLICIT DOUBLE PRECISION(A-H,O-Z)                                        
      DIMENSION SS(MS,MS),AS(MS,MS),SBAR(MS)                                    
C                                                                               
      AS(1,1)=1.0D0/DSQRT(SS(1,1))                                              
      MM1=MS-1                                                                  
      DO 60 K=1,MM1                                                             
      KP1=K+1                                                                   
      DO 20 I=1,K                                                               
      SUM=0.0D0                                                                 
      DO 10 J=1,I                                                               
      SUM=SUM+SS(KP1,J)*AS(I,J)                                                 
   10 CONTINUE                                                                  
      SBAR(I)=SUM                                                               
   20 CONTINUE                                                                  
      SUM=0.0D0                                                                 
      DO 30 I=1,K                                                               
      SUM=SUM+SBAR(I)**2                                                        
   30 CONTINUE                                                                  
      SUM=SS(KP1,KP1)-SUM                                                       
      RT=1.0D0/DSQRT(SUM)                                                       
      DO 50 I=1,K                                                               
      SUM=0.0D0                                                                 
      DO 40 J=I,K                                                               
   40 SUM=SUM+SBAR(J)*AS(J,I)                                                   
      AS(KP1,I)=-SUM*RT                                                         
   50 CONTINUE                                                                  
      AS(KP1,KP1)=RT                                                            
   60 CONTINUE                                                                  
      DO 70 J=2,MS                                                              
      JM1=J-1                                                                   
      DO 70 I=1,JM1                                                             
      AS(I,J)=0.0D0                                                             
   70 CONTINUE                                                                  
      RETURN                                                                    
      END                                                                       
C*DECK PRVCX
      SUBROUTINE PRVCX(VC,NBF,NOB)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION VC(NBF,2)
    1 FORMAT(/1X,10(I9,4X))
    2 FORMAT(1X,10D13.5)
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

C*DECK JACYCT
      SUBROUTINE JACYCT(N,NA,ITMAX,EPS3,A,T,AIK)
C             CYCLIC JACOBI WITH THRESHOLD 
C       REFERENCES: 
C   (1) B.CARNAHAN, H.A.LUTHER, J.O.WILKES, APPLIED NUMERICAL METHODS, 
C          WILEY 1969, PP.253-257. 
C   (2) J.A.JENSEN, J.H.ROWLAND, METHODS OF COMPUTATION, 1975, P.107. 
C   (3) C.-E.FROEBERG, INTRODUCTION TO NUMERICAL ANALYSIS, 
C          ADDISON-WESLEY 1969, P.122. 
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION A(NA,NA),T(NA,NA),AIK(NA)
C     CALL PRINT2(6,A,NA,NA,N,N) 
      EPS1=1.D-13
      EPS2=1.D-13
      NM1=N - 1
      OOSQR2=1.D0/DSQRT(2.D0)
C            COMPUTE SIGMA1 & S. 
      SIGMA1=0.D0
      OFFDSQ=0.D0
      DO 10 I=1,N
      SIGMA1=SIGMA1 + A(I,I)**2
      IP1=I + 1
      IF(I.GE.N) GO TO 20
      DO 10 J=IP1,N
   10 OFFDSQ=OFFDSQ + A(I,J)**2
   20 S=2.D0*OFFDSQ + SIGMA1
C            BEGIN JACOBI ITERATION. 
      DO 140 ITER=1,ITMAX
      DO 110 I=1,NM1
      IP1=I + 1
      DO 110 J=IP1,N
      Q=DABS(A(J,J) - A(I,I))
C            COMPUTE SINE & COSINE OF THE ROTATION ANGLE. 
      IF(Q.LE.EPS1) GO TO 30
      IF(DABS(A(I,J)).LE.EPS2) GO TO 110
      P=2.D0*A(I,J)*Q/(A(I,I) - A(J,J))
      SPQ=DSQRT(P*P + Q*Q)
      CSA=DSQRT((1.D0 + Q/SPQ)/2.D0)
      SNA=P/(2.D0*CSA*SPQ)
      GO TO 40
   30 CSA=OOSQR2
      SNA=CSA
   40 CONTINUE
C                UPDATE COLUMNS I & J OF T -- EQUIVALENT TO 
C                MULTIPLICATION BY THE ANNIHILATION MATRIX. 
      DO 50 K=1,N
      HOLDKI=T(K,I)
      T(K,I)=HOLDKI*CSA + T(K,J)*SNA
   50 T(K,J)=HOLDKI*SNA - T(K,J)*CSA
C                COMPUTE NEW ELEMENTS OF A IN ROWS I & J. 
      DO 80 K=I,N
      IF(K.GT.J) GO TO 70
      AIK(K)=A(I,K)
      A(I,K)=CSA*AIK(K) + SNA*A(K,J)
      IF(K.NE.J) GO TO 60
      A(J,K)=SNA*AIK(K) -CSA*A(J,K)
   60 GO TO 80
   70 HOLDIK=A(I,K)
      A(I,K)=CSA*HOLDIK + SNA*A(J,K)
      A(J,K)=SNA*HOLDIK - CSA*A(J,K)
   80 CONTINUE
C                COMPUTE NEW ELEMENTS OF A IN COLUMNS I & J. 
      AIK(J)=SNA*AIK(I) - CSA*AIK(J)
C            WHEN K IS LARGER THAN  I. 
      DO 100 K=1,J
      IF(K.LE.I) GO TO 90
      A(K,J)=SNA*AIK(K) - CSA*A(K,J)
      GO TO 100
   90 HOLDKI=A(K,I)
      A(K,I)=CSA*HOLDKI + SNA*A(K,J)
      A(K,J)=SNA*HOLDKI - CSA*A(K,J)
  100 CONTINUE
  110 A(I,J)=0.D0
C            FIND SIGMA2 FOR TRANSFORMED A & TEST FOR CONVERGENCE. 
      SIGMA2=0.D0
      DO 120 I=1,N
      EIGENI=A(I,I)
  120 SIGMA2=SIGMA2 + EIGENI**2
      IF(1.D0 - SIGMA1/SIGMA2. GE.EPS3) GO TO 130
C     WRITE(6,202) ITER,SIGMA1,SIGMA2 
      GO TO 150
  130 CONTINUE
  140 SIGMA1=SIGMA2
C            NO CONVERGENCE 
      WRITE(6,170) ITER,S,SIGMA1,SIGMA2
  150 RETURN
  160 FORMAT(' ITER  SIGMA1  SIGMA2',I4,2D15.7)
  170 FORMAT('0*** NO CONVERGENCE -- ITER S SIGMA1 SIGMA2',I4,3D15.7)
      END
