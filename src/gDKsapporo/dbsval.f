C     ------------------------------------------                                
      SUBROUTINE DBSVAL ( KDIM, T, X, LEFT, DB )                                
C     ------------------------------------------                                
C*                                                                              
      IMPLICIT REAL*8 (A-H,O-Z)                                                 
C*                                                                              
      DIMENSION T( * ), DB( KDIM ), DELTAL( 20 ), DELTAR( 20 )
C                                                                               
C                             b(i,j)(x)        b(i+1,j)(x)                      
C     Dx b(i,j+1)(x) = j * [ -----------  -  --------------- ]                  
C                            t(i+j)-t(i)     t(i+j+1)-t(i+1)                    
C                                                                               
      J = 1                                                                     
      DB( 1 ) = 1.D0                                                            
C                                                                               
 1000 JP1 = J + 1                                                               
      DELTAR( J ) = T( LEFT + J ) - X                                           
      DELTAL( J ) = X - T( LEFT + 1 - J )                                       
      SAVED = 0.D0                                                              
      DO 10 I = 1, J                                                            
        TERM = DB( I ) / ( DELTAR( I ) + DELTAL( JP1 - I ) )                    
        DB( I ) = SAVED + DELTAR( I ) * TERM                                    
        SAVED = DELTAL( JP1 - I ) * TERM                                        
   10 CONTINUE                                                                  
      DB( JP1 ) = SAVED                                                         
      J = JP1                                                                   
      IF( J .LT. KDIM - 1 ) GO TO 1000                                          
C*                                                                              
      DIM = DBLE( KDIM - 1 )                                                    
      JP1 = J + 1                                                               
      DELTAR( J ) = T( LEFT + J ) - X                                           
      DELTAL( J ) = X - T( LEFT + 1 - J )                                       
      SAVED = 0.D0                                                              
      DO 20 I = 1, J                                                            
        TERM = DIM * DB( I ) / ( DELTAR( I ) + DELTAL( JP1 - I ) )              
        DB( I ) = SAVED - TERM                                                  
        SAVED = TERM                                                            
   20 CONTINUE                                                                  
      DB( JP1 ) = SAVED                                                         
C*                                                                              
      RETURN                                                                    
      END                                                                       
