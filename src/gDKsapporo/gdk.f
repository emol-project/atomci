C     ---------------------------------------------------------
      SUBROUTINE GDK( H, AGF, CGF, T, WGL, ZGL, NGL, 
     &               METHOD, NSYM, KDIM, NBF, NCGF, NGF, LV )
C     ---------------------------------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
      COMMON/DKPOT2/
     &     W2( 500500, 7 ), WT( 500500, 7 ), COEF( 1000, 1000, 7 )
Caa    &     W2( 500500, 6 ), WT( 500500, 6 ), COEF( 1000, 1000, 6 )
      DIMENSION TR( 1000, 100 ), T( 1022 ), H( * )
      DIMENSION WGL( 16 ), ZGL( 16 ), GNORM( 100 )
C
C     NTGF( L )      : # OF CGTF WITH (L-1) ANGULAR MOMENTUM. 
C     NCGF( I, L )   : # OF PRIMITIVE FUNCTIONS OF I-TH CGTF.
C     AGF( J, I, L ) : EXPO. OF J-TH PRIMITIVE FUNCTIONS.
C     CGF( J, I, L ) : COEF. OF J-TH PRIMITIVE FUNCTIONS.
C
C
      DIMENSION AGF( 100, 100 ), CGF( 100, 100 ),
     &          NCGF( 100 )
C
C
C     SG( I ) : OVERLAP INTEGRAL OVER GTF.
C     TG( I ) : KINETIC INTEGRAL OVER GTF.
C     VG( I ) : NUCLEAR ATTRACTION INTEGRAL OVER GTF.
C
C
      DIMENSION SG( 5050 ), TG( 5050 ), VG( 5050 )
C*
      DIMENSION TW2( 500500 ), TWT( 500500 ), TCOEF( 1000, 1000 )
C*
C
C      COPY COEF, W2, WT  -> TCOEF, TW2, TWT
C
C
      DO I = 1, NBF
        DO J = 1, NBF
          TCOEF( I, J ) = COEF( I, J, LV ) 
        END DO
      END DO
      NNBF = NBF * (NBF + 1) / 2
      DO I = 1, NNBF
        TW2( I ) = W2( I, LV )
        TWT( I ) = WT( I, LV )
      END DO
C*
C
C      TRANSFORMATION  P2-SPACE -> R-SPACE
C
C
      CALL TRMT( AGF, CGF, TR, T, WGL, ZGL, 
     &             NGL, NBF, KDIM, NGF, NCGF, LV )
C*
      CALL TRFM1( TR, TCOEF, NBF, NGF )
      IF( METHOD .GT. 2 ) CALL TRFM2( TW2, TCOEF, NBF, NGF )
      CALL TRFM2( TWT, TCOEF, NBF, NGF )
C
C =============================================================
C
C
C     OVERLAP AND NUCLEAR ATTRACTION INTEGRALS OVER CGTF
C
C
      IJ = 0
      DO 90 I = 1, NGF
        NPGI = NCGF( I )
        DO 91 J = 1, I
          NPGJ = NCGF( J )
C*
          SUM1 = 0.D0
          SUM2 = 0.D0
          DO 92 I1 = 1, NPGI
            AI = AGF( I1, I )
            CI = CGF( I1, I )
            DO 93 J1 = 1, NPGJ
              AJ = AGF( J1, J )
              CJ = CGF( J1, J )
              SUM1 = SUM1 + GINT( AI + AJ, LV*2 ) * CI * CJ
              SUM2 = SUM2 + GINT( AI + AJ, LV*2 - 1 ) * CI * CJ
   93       CONTINUE
   92     CONTINUE
          IJ = IJ + 1
          SG( IJ ) = SUM1
          VG( IJ ) = SUM2
C*
          SUM = 0.D0
          DO 94 K = 1, NBF
            SUM = SUM + TCOEF( K, I ) * TCOEF( K, J )
   94     CONTINUE
C         write(6,'(2I5,2D18.8)') I, J, SG( IJ ), SUM
   91   CONTINUE
   90 CONTINUE
C            NORMALIZATION CONSTANTS
      DO I = 1, NGF
        II = I * (I + 1) / 2
        GNORM( I ) = 1.D0 / DSQRT(SG( II ))
      END DO 
C
C==============================================================
C*
      IJ = 0
      DO 51 I = 1, NGF
        DO 52 J = 1, I
          IJ = IJ + 1
          IF( METHOD .EQ. 2 ) THEN
            TG( IJ ) = TWT( IJ ) - C2 * SG( IJ )
          ELSE
            TG( IJ ) = TWT( IJ )
            VG( IJ ) = TW2( IJ )
C           write(6,'(2D18.8)') TG( IJ ), VG( IJ )
          END IF
          H( IJ ) = (TG( IJ ) + VG( IJ )) 
     *            * GNORM( I ) * GNORM( J )
   52   CONTINUE
   51 CONTINUE
C*
   10 CONTINUE
C*
C     WRITE(6,*) '>>>>  DK ENDED'
C*
      RETURN
      END
C     ----------------------------
      REAL*8 FUNCTION GINT( A, M )
C     ----------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
      PARAMETER( PI = 3.1415926535897D0 )
C*
      DIMENSION FAC( 0:8 ),  GFAC( 0:8 )
C*
      DATA  FAC/ 1.D0,  1.D0,  2.D0,  6.D0, 24.D0,
     &         120.D0,  720.D0, 5040.D0, 40320.D0/
C*
      DATA GFAC/ 1.D0,  1.D0,  3.D0,  15.D0,  105.D0,
     &           945.D0, 10395.D0, 135135.D0, 2027025.D0/
C*
      IF( MOD( M, 2 ) .EQ. 0 ) THEN
        N = M / 2
        IF( N .GT. 8 ) STOP 1111
        GINT = GFAC( N ) * 0.5D0**( N + 1 )
     &       * DSQRT( PI / A**( M + 1 ) )
      ELSE
        N = ( M - 1 ) / 2
        IF( N .GT. 8 ) STOP 2222
        GINT = 0.5D0 * FAC( N ) / A**( N + 1 )
      END IF
C*
      RETURN
      END

