C     ------------------------------------------------
      SUBROUTINE TRMT( AGF, CGF, TR, T, W, Z,
     &                 NGL, NBF, KDIM, NGF, NCGF, LV )
C     ------------------------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
C*
      DIMENSION T( 1022 ), W( 16 ), Z( 16 ), BS( 20 )
      DIMENSION AGF( 100, 100 ), CGF( 100, 100 ), NCGF( 100 )
      DIMENSION TR( 1000, 100 )
C*
      NBS = NBF + 1
C*
      DO 10 I = 1, NGF
        NPG = NCGF( I )
        DO 20 J = 2, NBS
          NS = MAX( J, KDIM )
          NE = MIN( J + KDIM - 1, NBS + 1 )
C*
          SUM = 0.D0
          DO 30 K = 1, NPG
            ALP = AGF( K, I )
            V = 0.D0
            DO 40 IB = NS, NE
              T1 = T( IB + 1 )
              T0 = T( IB )
              TP = ( T1 + T0 ) * 0.5D0
              TM = ( T1 - T0 ) * 0.5D0
              II = KDIM - IB + J
              DO 50 L = 1, NGL
                R = TP + TM * Z( L )
                CALL FBSVAL( KDIM, T, R, IB, BS )
                V = V + TM * W( L ) * BS( II )
     &                * DEXP( - ALP * R**2 ) * R**LV
   50         CONTINUE
   40       CONTINUE
            SUM = SUM + V * CGF( K, I )
   30     CONTINUE
          TR( J - 1, I ) = SUM
C*
   20   CONTINUE
   10 CONTINUE
C*
      RETURN
      END
