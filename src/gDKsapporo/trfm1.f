C     -------------------------------------
      SUBROUTINE TRFM1( S, COEF, NBF, NGF )
C     -------------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
C*
      DIMENSION S( 1000, 100 ), COEF( 1000, 1000 ), X( 1000, 100 )
C*
      IJT( I, J ) = MAX( I, J ) * ( MAX( I, J ) - 1 ) / 2 + MIN( I, J )
C*
      DO 10 I = 1, NBF
        DO 20 J = 1, NGF
          SUM = 0.D0
          DO 30 K = 1, NBF
            SUM = SUM + S( K, J ) * COEF( K, I )
   30     CONTINUE
          X( I, J ) = SUM
   20   CONTINUE
   10 CONTINUE
C*
      DO 40 I = 1, NBF
        DO 50 J = 1, NGF
          COEF( I, J ) = X( I, J )
   50   CONTINUE
   40 CONTINUE
C*
      RETURN
      END
