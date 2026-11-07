C     -------------------------------------
      SUBROUTINE TRFM2( W, COEF, NBF, NGF )
C     -------------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
C*
      DIMENSION COEF( 1000, 1000 ), W( 500500 ), A( 1000, 1000 )
C*
      IJT( I, J ) = MAX( I, J )*( MAX( I, J ) - 1 )/2 + MIN( I, J )
C*
      DO 10 I = 1, NBF
        DO 20 J = 1, NGF
          SUM = 0.D0
          DO 30 K = 1, NBF
            IK = IJT( I, K )
            SUM = SUM + W( IK ) * COEF( K, J )
   30     CONTINUE
          A( I, J ) = SUM
   20   CONTINUE
   10 CONTINUE
C*
      IJ = 0
      DO 40 I = 1, NGF
        DO 50 J = 1, I
          SUM = 0.D0
          DO 60 K = 1, NBF
            SUM = SUM + A( K, J ) * COEF( K, I )
   60     CONTINUE
          IJ = IJ + 1
          W( IJ ) = SUM
   50   CONTINUE
   40 CONTINUE
C*
      RETURN
      END
