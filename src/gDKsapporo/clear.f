C     -------------------------
      SUBROUTINE DCLEAR( N, A )
C     -------------------------
C*
      REAL*8 A( N )
C*
      DO 10 I = 1, N
        A( I ) = 0.D0
   10 CONTINUE
C*
      RETURN
      END
C     -------------------------
      SUBROUTINE ICLEAR( N, A )
C     -------------------------
C*
      INTEGER A( N )
C*
      DO 10 I = 1, N
        A( I ) = 0
   10 CONTINUE
C*
      RETURN
      END
