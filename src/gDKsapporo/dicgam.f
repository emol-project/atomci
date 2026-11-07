      REAL*8 FUNCTION DICGAM(ANU,X)
****************************************************
*           incomplete gamma function              *
*              in double precision                 *
*      COPYRIGHT : M.Mori  JUNE 30 1989  V.1       *
****************************************************
      IMPLICIT REAL*8 (A-H,O-Z)
*
      DATA NUMAX /56/, EPS /1.0D-17/
*
*     ---- for single precision ----
*     DATA NUMAX /56/, EPS /1.0E-8/
*
      IF (X .LT. 0.0D0)   GO TO 901
      IF (ANU .LE. 0.0D0) GO TO 902
*
      IF (X .EQ. 0.0D0) THEN
        DICGAM = DGAMM(ANU)
        RETURN
      END IF
*
      XS = X
      BNU = ANU
      IA = 0
      IF (BNU .GT. 1.0D0) THEN
        DO 50 I = 1, NUMAX
          BNU = BNU - 1.0D0
          IA = I
          IF (BNU .LE. 1.0D0) GO TO 51
   50   CONTINUE
*
        GO TO 902
*
   51   CONTINUE
      END IF
*
      W = X
      U = EXP(-W + BNU * LOG(W))
*
      IF (X .LE. 1.0D0) THEN
        P1 = DGAMM(BNU)
        IN = 20
*
*       ---- for single precision ----
*       IN = 10
*
        P0 = 1.0D0
        Q0 = 1.0D0
        DO 10 I = 1, IN
          Q0 = Q0 * X / (BNU + I)
          P0 = P0 + Q0
          IF (Q0 .LE. EPS) GO TO 11
   10   CONTINUE
*
   11   CONTINUE
        V = P1 - U / BNU * P0
*
      ELSE
        IN = 120.0D0 / XS + 5.0D0
*
*       ---- for single precision ----
*       IN = 25.0 / (XS - 0.25) + 2.0
*
        P0 = 0.0D0
        IF (BNU .NE. 1.0D0) THEN
          P1 = 1.0D-78 / (1.0D0 - BNU)
        ELSE
          P1 = 1.0D-78
        END IF
        Q0 = P1
        Q1 = X * Q0
        DO 20 I = 1, IN
          B = I
          A = B - BNU
          P0 = P1 + A * P0
          Q0 = Q1 + A * Q0
          P1 = X * P0 + B * P1
          Q1 = X * Q0 + B * Q1
          IF (I .GE. 50) THEN
            Q0 = Q0 / B
            P0 = P0 / B
            Q1 = Q1 / B
            P1 = P1 / B
          END IF
   20   CONTINUE
        V = U / Q1 * P1
*
      END IF
*
      IF (IA .NE. 0) THEN
        DO 60 I = 1, IA
          V = U + BNU * V
          U = U * X
          BNU = BNU + 1.0D0
   60   CONTINUE
      END IF
*
      DICGAM = V
      RETURN
*
  901 CONTINUE
      DICGAM = 0
      WRITE (6,2001) X
 2001 FORMAT (' (FUNC.DICGAM) invalid argument',
     $        ' X =',D23.16)
      RETURN
*
  902 CONTINUE
      DICGAM = 1.0D75
      WRITE (6,2002) ANU
 2002 FORMAT (' (FUNC.DICGAM) invalid argument',
     $        ' ANU =',D23.16)
      RETURN
*
      END
