      REAL*8 FUNCTION DGAMM(X)
*****************************************************
*                   gamma function                  *
*                in double precision                *
*      COPYRIGHT : M.Mori  JUNE 30 1989  V.1        *
*****************************************************
      IMPLICIT REAL*8 (A-H,O-Z)
*
      DIMENSION C(0:19)
      DATA IN / 19 /
*
*     ---- for single precision ----
*     DATA IN / 10 /
*
      DATA C /  1.0                   D0,
     1         -0.42278 43350 98467 1 D0,
     2         -0.23309 37364 21786 7 D0,
     3          0.19109 11013 87691 5 D0,
     4         -0.24552 49000 54000 2 D-1,
     5         -0.17645 24455 01443 2 D-1,
     6          0.80232 73022 26734 7 D-2,
     7         -0.80432 97756 04247 0 D-3,
     8         -0.36083 78162 548     D-3,
     9          0.14559 61421 399     D-3,
     1         -0.17545 85975 17      D-4,
     1         -0.25889 95022 4       D-5,
     2          0.13385 01546 6       D-5,
     3         -0.20547 43152         D-6,
     4         -0.15952 68            D-9,
     5          0.62756 218           D-8,
     6         -0.12736 143           D-8,
     7          0.92339 7             D-10,
     8          0.12002 8             D-10,
     9         -0.42202               D-11 /
*
      IF (X .GT. 57.0D0) GO TO 901
*
      XX = X
      IF (XX .LE. 1.5D0) THEN
        IF (XX .GE. 0.5D0) THEN
          A = XX - 1.0D0
          FCTR = 1.0D0
        ELSE
          M = INT(XX)
          A = XX - M
          IF (A .EQ. 0.0D0) THEN
            GO TO 902
          ELSE IF (A .GE. -0.5D0) THEN
            MG = IABS(M) + 1
          ELSE
            MG = IABS(M) + 2
            A = A + 1.0D0
          END IF
          Z = 1.0D0
          DO 20 I = 1, MG
            Z = Z * XX
            XX = XX + 1.0D0
   20     CONTINUE
          FCTR = 1.0D0 / Z
        END IF
*
      ELSE
        M = INT (XX)
        A = XX - M
        IF (A .LE. 0.5D0) THEN
          MG = M - 1
        ELSE
          MG = M
          A = A - 1.0D0
        END IF
        Z = 1.0D0
        DO 30 I = 1, MG
          Z = Z * (XX - 1.0D0)
          XX = XX - 1.0D0
   30   CONTINUE
        FCTR = Z
      END IF
*
      Y = C(IN)
      DO 10 I = IN - 1, 0, -1
        Y = C(I) + A * Y
   10 CONTINUE
*
      DGAMM = FCTR / ((1.0D0 + A) * Y)
      RETURN
*
  901 CONTINUE
      WRITE (6,2001) X
 2001 FORMAT (' (FUNC.DGAMM) X(=',D23.16,')',
     $        ' must be smaller than 57.0')
      DGAMM = 1.0D75
      RETURN
*
  902 CONTINUE
      WRITE (6,2002) X
 2002 FORMAT (' (FUNC.DGAMM) invalid argument',
     $        ' X =',D23.16)
      DGAMM = 1.0D75
      RETURN
*
      END
