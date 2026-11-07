C     --------------------------------------------
      SUBROUTINE CHDNS( T, W, ZP, NGL, KDIM, NBS )
C     --------------------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
C*
      COMMON/BFINF/
     &       NBF, NKUMI, KUMI( 2, 19810 ), KNOT( 2, 19810 )
      COMMON/RPNT/
     &       RINV( 15728 ), R( 15728 )
      COMMON/CDVAL/
     &       CDV( 3302240 ), CDD( 3302240 ), CD2( 3302240 ),
     &       IRCDV( 3302240 )
C*
      DIMENSION BS( 20 ), DB( 20 ), T( 1022 ), IAR( 1003 )
      DIMENSION W( 16 ), ZP( 16 )
C
C
C     SETUP GAUSS-LEGENDRE PARAMETERS
C
C
      CALL GLSET( W, ZP, NGL )
C
C
C     SETUP POINTS
C
C
      IR1 = 0
      DO 10 I = KDIM, NBS + 1
        T1 = T( I + 1 )
        T0 = T( I )
        TP1 = ( T1 + T0 ) * 0.5D0
        TM1 = ( T1 - T0 ) * 0.5D0
        IAR( I ) = IR1
        DO 20 J = 1, NGL
          IR1 = IR1 + 1
          X = TP1 + TM1 * ZP( J )
          R( IR1 ) = X
          IF( X .LE. 1.D-15 ) THEN
            RINV( IR1 ) = 0.D0
          ELSE
            RINV( IR1 ) = 1.D0 / X
          END IF
   20   CONTINUE
   10 CONTINUE
      IAR( NBS + 2 ) = IR1
C
C
C     STORE WEIGHTED CHRGE DENSITIES
C
C
      IJ = 0
      IR1 = 0
      DO 40 I = 2, NBS
        JS = MAX( I - KDIM + 1, 2 )
        NS = MAX( I, KDIM )
        DO 50 J = JS, I
          NE = MIN( J + KDIM - 1, NBS + 1 )
          IJ = IJ + 1
          KUMI( 1, IJ ) = I - 1
          KUMI( 2, IJ ) = J - 1
          KNOT( 1, IJ ) = NS
          KNOT( 2, IJ ) = NE
          DO 60 IB = NS, NE
            T1 = T( IB + 1 )
            T0 = T( IB )
            TM = ( T1 - T0 ) * 0.5D0
            IK = KDIM - IB + I
            JK = KDIM - IB + J
            KS = IAR( IB )
            IC = 0
            DO 70 K = 1, NGL
              X = R( K + KS )
              IR1 = IR1 + 1
              CALL FBSVAL( KDIM, T, X, IB, BS )
              CDV( IR1 ) = TM * W( K ) * BS( IK ) * BS( JK )
              CALL DBSVAL( KDIM, T, X, IB, DB )
              CDD( IR1 ) = TM * W( K ) * DB( IK ) * DB( JK )
              CD2( IR1 ) = TM * W( K ) * ( DB( IK ) * BS( JK )
     &                                   + BS( IK ) * DB( JK ) )
              IRCDV( IR1 ) = K + KS
   70       CONTINUE
   60     CONTINUE
   50   CONTINUE
   40 CONTINUE
      NKUMI = IJ
C*
      RETURN
      END
