C     -----------------------------------------------------
      SUBROUTINE INIT( R1, RMAX, T, KDIM, NBS, NBF, IKNOT )
C     -----------------------------------------------------
C*
      IMPLICIT REAL*8 (A-H,O-Z)
C*
      DIMENSION T( 1022 )
C*                                                                              
      N = NBF + 2                                                               
      NBS = N - 1                                                               
      M = N - KDIM
C                                                                               
C                                                                               
C     SETUP KNOT SEQUENCE                                                       
C                                                                               
C                                                                               
      DO 10 I = 1, KDIM                                                         
        T( I ) = 0.D0                                                           
        T( N + I ) = RMAX                                                       
   10 CONTINUE                                                                  
C*                                                                              
      IF( IKNOT .EQ. 1 ) THEN                                                   
C                                                                               
C ====================================================================          
C                                                                               
C --  ORIGINAL METHOD --  ( IKNOT = 1 )                                         
C                                                                               
C                                                                               
      X = 1.D0                                                                  
      A = 1.D0 - RMAX / R1                                                      
C*                                                                              
 1000 XOLD = X                                                                  
      F = A                                                                     
      DO 11 I = 1, M                                                            
        F = F + X ** I                                                          
   11 CONTINUE                                                                  
      G = 1.D0                                                                  
      DO 21 I = 2, M                                                            
        G = G + DBLE( I ) * X**( I - 1 )                                        
   21 CONTINUE                                                                  
      X = X - F / G                                                             
      IF( DABS( X - XOLD ) .GT. 1.D-12 ) GOTO 1000
C*                                                                              
C     WRITE(6,'(2X,A,F9.5,/)') 'DISTRIBUTION RATE =', X                         
C*                                                                              
      SUM = 0.D0                                                                
      DO 20 I = 1, M                                                            
        SUM = SUM + R1 * X ** ( I - 1 )                                         
        T( I + KDIM ) = SUM                                                     
   20 CONTINUE                                                                  
C*                                                                              
C ====================================================================          
C                                                                               
      ELSE IF( IKNOT .EQ. 2 ) THEN                                              
C                                                                               
C ====================================================================          
C                                                                               
C --  EXPONENTIAL METHOD --  ( IKNOT = 2 )                                      
C                                                                               
C                                                                               
      DM = DBLE( M )                                                            
      RATE = RMAX / R1                                                          
      DI1 = -1.D0                                                               
      DO 30 I = 1, M                                                            
        DI1 = DI1 + 1.D0                                                        
        T( I + KDIM ) = R1 * RATE ** ( DI1 / DM )                               
   30 CONTINUE                                                                  
C                                                                               
C ====================================================================          
C                                                                               
      ELSE IF( IKNOT .EQ. 3 ) THEN                                              
C                                                                               
C ====================================================================          
C                                                                               
C --  UNIFORM METHOD --  ( IKNOT = 3 )                                          
C                                                                               
      RATE = RMAX / DBLE( M + 1 )                                               
      DI = 0.D0                                                                 
      DO 40 I = 1, M                                                            
        DI = DI + 1.D0                                                          
        T( I + KDIM ) = RATE * DI                                               
   40 CONTINUE                                                                  
C                                                                               
C ====================================================================          
C                                                                               
      ELSE IF( IKNOT .EQ. 4 ) THEN
C
C ====================================================================
C
C --  SIN-LIKE METHOD --  ( IKNOT = 4 )
C
      PI2 = 3.1415926535897D0 * 0.5D0
      RATE = 1.D0 / DBLE( M + 1 )
      DI = 0.D0
      DO 50 I = 1, M
        DI = DI + 1.D0
        T( I + KDIM ) = RMAX * DSIN( PI2 * ( DI * RATE )**R1 )
   50 CONTINUE
C
C ====================================================================
C

      ELSE                                                                      
        WRITE(6,*) 'XXX   IKNOT ERROR   XXX'                                    
        STOP                                                                    
      END IF                                                                    
C*                                                                              
C     WRITE(6,'(A,/)') 'KNOT POINTS:'                                           
C     WRITE(6,'(5F12.6)') ( T( I ), I = 1, N + KDIM )                           
C     WRITE(6,*) ' '                                                            
C*
CCC   write(6,*) '>>>>  INIT END'                                               
C*                                                                              
      RETURN                                                                    
      END                                                                       
