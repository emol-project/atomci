C*DECK DELTA
      FUNCTION DELTA (IA,IB,IC)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT   REAL*8(A-H,O-Z)
C     DIMENSION     RT(57),FASQ(154),DEN(57),FAC(57)
      include 'include/COMWIG'
C     SAVE RT,FASQ,DEN,FAC
C
      I1= IA+IB-IC+40
      I2= IA-IB+IC+40
      I3=-IA+IB+IC+40
      DELTA=FASQ(I1)*FASQ(I2)*FASQ(I3)
      RETURN
      END
