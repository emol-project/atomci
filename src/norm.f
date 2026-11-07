C*DECK NORM
      SUBROUTINE NORM(S,VC,N,M,W,*)
C
C     COMPUTES SCHMIDT-ORTHONORMALIZED SET OF VECTORS
C         CALLING SEQUENCE PARAMETERS ARE AS FOLLOWS
C              S    METRIC MATRIX STORED AS LOWER TRIANGLE (R*8)
C              VC   LOCATION OF ORIGINAL NON-ORTHONORMAL VECTORS (R*8)
C                   FINAL ORTHONORMALIZED VECTORS REPLACE ORIGINAL SET
C              N    DIMENSION OF BASIS SET (I*4)
C              M    NUMBER OF VECTORS TO BE ORTHONORMALIZED (I*4)
C              W    TEMPORARY WORKING AREA OF 2*N WORDS (R*8)
C         RETURNS
C              NORMAL RETURN ORTHONORMALIZED SET OBTAINED
C              RETURN 1       INITIAL VECTORS AT VC LINEARLY
C                             DEPENDENT WITHIN THRES HOLD (THNORM)
C         AUXILLIARY ENTRY
C              NORMST(/THNORM/)  SETS LOCATION OF THNORM
C                                CHECKED TASHI 10/25/89 HUCC
C
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION S(*), VC(*), W(*)
      save tnrml
C
      GO TO 77777
      ENTRY NORMST (THNORM)
C     ENTRY NORMST (/THNORM/)
      tnrml=thnorm
      RETURN
77777 CONTINUE
C
      IF (N .GT. 1) GO TO 2
      IF (VC(1)*VC(1) .LE. tnrml) RETURN 1
      VC(1) = 1.D0/DSQRT(S(1))
      RETURN
C
C     BEGIN OUTERMOST LOOP OVER TRIAL VECTOR SET
C
    2 NP1 = N+1
C     TNRML = tnorm
      IVCI = 1
      DO 20 I=1,M
      CALL CNTRC(S,VC(IVCI),W,N)
      T = 0.D0
      TNORM = 0.D0
      IVCJ = 1
      IVCW = N
C
C     BEGIN COEFFICIENTS AND NORMALIZATION LOOP
C
      DO 5 J=1,I
      TNORM = TNORM - T*T
      T = 0.D0
      DO 4 JJ=1,N
      T = VC(IVCJ)*W(JJ) + T
    4 IVCJ = IVCJ + 1
      IVCW = IVCW + 1
    5 W(IVCW) = -T
C     ************************ CONVERTED 84-11-5 ****
C     IF (TNORM + T .LE. TNRML) RETURN 1
      IF (TNORM + T .LE. TNRML) THEN
          WRITE(6,FMT='(1H0,''  ** ERROR IN NORM ** '')')
          WRITE(6,FMT='(1H ,''  ** ORB#  ** '',I3)') I
          WRITE(6,FMT='(1H ,''  ** TNORM ** '',D15.7)') TNORM + T
          RETURN 1
          END IF
C     ************************ END       84-11-5 ****
      TNORM = 1.D0/DSQRT(TNORM + T)
      W(IVCW) = 1.D0
C
C     BEGIN REPLACE VC(I) OUTER LOOP
C
      DO 15 K=1,N
      T = 0.D0
      IVCW = NP1
C
C     BEGIN REPLACE COMPONENT OF VC(I) LOOP
C
      DO 10 J=K,IVCI,N
      T = VC(J)*W(IVCW) + T
   10 IVCW = IVCW + 1
      VC(IVCI) = T*TNORM
   15 IVCI = IVCI + 1
   20 CONTINUE
      RETURN
      END
