C     ---------------------------------------------------------
      SUBROUTINE INITDK( T, WGL, ZGL, NGL,
     &                   METHOD, NSYM, NCL, KDIM, NBF )
C     ---------------------------------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
      PARAMETER( C = 137.0359895D0, C2 = C*C, C4 = C2*C2 )
C
C
C     METHOD = 2 (SQR) / 3 (DK1) / 4 (DK2) / 5 (DK3)
C
C
      COMMON/DKPOT/
     &       S( 500500 ), H( 500500, 7 ), 
     &       V( 500500, 7 ), V2( 500500, 7 )
Caa    &       S( 500500 ), H( 500500, 6 ), 
Caa    &       V( 500500, 6 ), V2( 500500, 6 )
      COMMON/DKPOT2/
     &     W2( 500500, 7 ), WT( 500500, 7 ), COEF( 1000, 1000, 7 )
Caa    &     W2( 500500, 6 ), WT( 500500, 6 ), COEF( 1000, 1000, 6 )
C*
      DIMENSION EOP( 1000 ), AOP( 1000 ), ROP( 1000 ), R2( 1000 )
      DIMENSION W1( 500500 )
      DIMENSION
     &          U( 500500 ), RNR( 500500 ), RVR( 500500 ), EV1( 500500 )
      DIMENSION TR( 1000, 100 ), WS( 1000, 1000 ), T( 1022 )
      DIMENSION EIG( 1000 ), WORK( 3000 )
C*
      IJT( I, J ) = MAX( I, J )*( MAX( I, J ) - 1 ) / 2 + MIN( I, J )
C*
C     WRITE(6,*) '>>>>  DK START'
C*
      EPS = 1.0D-16
      LSV = NBF * ( NBF + 1 ) / 2
C*
      VEF1 = 0.D0
      VEF2 = 0.D0
      VEF3 = 0.D0
C*
      DO 10 LV = 1, NSYM
C       WRITE(6,'(A,I3)') 'L =', LV
C*
        IJ = 0
        DO 20 I = 1, NBF
          DO 25 J = 1, I
            IJ = IJ + 1
            W1( IJ ) = V( IJ, LV )
            W2( IJ, LV ) = V2( IJ, LV )
            CT = H( IJ, LV ) * 2.D0
            COEF( I, J, LV ) = CT
            COEF( J, I, LV ) = CT
            ST = S( IJ )
            WS( I, J ) = ST
            WS( J, I ) = ST
   25     CONTINUE
   20   CONTINUE
C*
        CALL DSYGV( 1, 'V', 'L', NBF, COEF(1, 1, LV), 1000,
     &              WS, 1000, EIG, WORK, 3000, INFO )
        IF( INFO .NE. 0 ) WRITE(6,*) 'INFO =', INFO
C*
C       WRITE(6,*)
C       WRITE(6,'(5D12.3)') ( EIG( I ), I = 1, NBF )
C       WRITE(6,*)
C*
c       WRITE(6,'(/,A,D18.10)') '* MAX P2 :', EIG( NBF )
c       WRITE(6,'(A,D18.10,/)') '* MIN P2 :', EIG( 1 )
C*
        IF( METHOD .GT. 2 ) CALL TRFM2( W1, COEF(1, 1, LV), NBF, NBF )
        CALL TRFM2( W2(1,LV), COEF(1, 1, LV), NBF, NBF )
C*
        IJ = 0
        DO 30 I = 1, NBF
          P2 = EIG( I )
          EI = DSQRT( P2 * C2 + C4 )
          RI = C / ( EI + C2 )
          AI = DSQRT( ( C2 + EI ) / ( 2.D0 * EI ) )
          R2I = P2 * RI**2
C*
          AOP( I ) = AI
          EOP( I ) = EI
          ROP( I ) = RI
          R2( I ) = R2I
          DO 40 J = 1, I
            AJ = AOP( J )
            EJ = EOP( J )
            RJ = ROP( J )
            R2J = R2( J )
            IJ = IJ + 1
            VI  = W1( IJ )
            VI2 = W2( IJ, LV )
            EIJ = EI + EJ
            U( IJ ) =  VI / EIJ
            RV2R = RI * VI2 * RJ
            RNR( IJ ) = RV2R / EIJ
            RVR( IJ ) = AI * ( RV2R + R2I * VI * R2J ) * AJ
            EV1( IJ ) = AI * ( VI + RV2R ) * AJ
   40     CONTINUE
   30   CONTINUE
C
C
C       FIRST ORDER DK
C
C
        IJ = 0
        DO 50 I = 1, NBF
          EI = EOP( I )
          AI = AOP( I )
          DO 55 J = 1, I
            EJ = EOP( J )
            AJ = AOP( J )
            AIJ = AI * AJ
            EIJ = ( EI + EJ ) * 0.5D0
C*
            IJ = IJ + 1
            WT( IJ, LV ) = 0.D0
            IF( I .EQ. J ) WT( IJ, LV ) = EI - C2
            IF( METHOD .EQ. 2 .AND. I .EQ. J ) WT( IJ, LV ) = EI
C*
            VEF1 = 0.D0
            IF( METHOD .GT. 2 ) VEF1 = EV1( IJ )
            IF( METHOD .LE. 3 ) GOTO 2222
C
C
C       SECOND ORDER DK
C
C
            VEF2 = 0.D0
            DO 60 K = 1, NBF
              IK = IJT( I, K )
              KJ = IJT( K, J )
              VEF2 = VEF2 - AIJ * AOP( K )**2 * ( EIJ + EOP( K ) )
     &             * ( U( IK ) * ( RNR( KJ ) - R2( K ) * U( KJ ) )
     &             + RNR( IK ) * ( U( KJ ) - RNR( KJ ) / R2( K ) ) )
   60       CONTINUE
C*
 2222       IF( METHOD .NE. 5 ) GOTO 3333
C
C
C       THIRD ORDER DK
C
C
            VEF3 = 0.D0
            DO 70 K = 1, NBF
              AK = AOP( K )
              IK = IJT( I, K )
              DO 80 L = 1, NBF
                AL = AOP( L )
                KL = IJT( K, L )
                LJ = IJT( L, J )
C*
                VEF3 = VEF3
     &              - AIJ * AK * AL * RVR( KL )
     &                    * ( RNR( IK ) / R2( K ) - U( IK ) )
     &                    * ( U( LJ ) - RNR( LJ ) / R2( L ) )
     &              + AK * AL**2 * AJ * EV1( IK ) * 0.5D0
     &                    * ( RNR( KL ) - U( KL ) * R2( L ) )
     &                    * ( U( LJ ) - RNR( LJ ) / R2( L ) )
     &              + AI * AK**2 * AL * EV1( LJ ) * 0.5D0
     &                    * ( RNR( IK ) - U( IK ) * R2( K ) )
     &                    * ( U( KL ) - RNR( KL ) / R2( K ) )
   80         CONTINUE
   70       CONTINUE
C*
 3333       CONTINUE
            W2( IJ, LV ) =   VEF1 + VEF2 + VEF3
   55     CONTINUE
   50   CONTINUE
C*
C       WRITE(6,*) '* WT'
C       WRITE(6,'(4D18.8)') ( WT( I, LV ), I = 1, LSV )
C       WRITE(6,*) '* W2'
C       WRITE(6,'(4D18.8)') ( W2( I, LV ), I = 1, LSV )
C       WRITE(6,*)
C
C*
   10 CONTINUE
C*
      RETURN
      END
