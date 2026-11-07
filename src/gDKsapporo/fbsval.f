C     ------------------------------------------                                
      SUBROUTINE FBSVAL ( KDIM, T, X, LEFT, BS )
C     ------------------------------------------                                
C*                                                                              
      IMPLICIT REAL*8 (A-H,O-Z)                                                 
C*                                                                              
      DIMENSION T( * ), BS( KDIM ), DELTAL( 20 ), DELTAR( 20 )
C                                                                               
C                       x - t(i)              t(i+j+1) - x                      
C     b(i,j+1)(x)  =  -----------b(i,j)(x) + ---------------b(i+1,j)(x)         
C                     t(i+j)-t(i)            t(i+j+1)-t(i+1)                    
C                                                                               
      J = 1                                                                     
      BS( 1 ) = 1.D0                                                            
C                                                                               
 1000 JP1 = J + 1                                                               
      DELTAR( J ) = T( LEFT + J ) - X                                           
      DELTAL( J ) = X - T( LEFT + 1 - J )                                       
      SAVED = 0.D0                                                              
      DO 10 I = 1, J                                                            
        TERM = BS( I ) / ( DELTAR( I ) + DELTAL( JP1 - I ) )                    
        BS( I ) = SAVED + DELTAR( I ) * TERM                                    
        SAVED = DELTAL( JP1 - I ) * TERM                                        
   10 CONTINUE                                                                  
      BS( JP1 ) = SAVED                                                         
      J = JP1                                                                   
      IF( J .LT. KDIM ) GO TO 1000                                              
C*                                                                              
      RETURN                                                                    
      END                                                                       
