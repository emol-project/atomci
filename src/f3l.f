C*DECK F3L
      FUNCTION F3L(IA,IB,IC)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT   REAL*8(A-H,O-Z)
C     DIMENSION     RT(57),FASQ(154),DEN(57),FAC(57)
      include 'include/COMWIG'
C
C     GO TO 77777
C     ENTRY QF3L   (RT,FASQ,DEN,FAC)
C     RETURN
C7777 CONTINUE
C
      F3L=DELTA(IA,IB,IC)
      IF (F3L.EQ.0.) RETURN
      IT=(IA+IB+IC+1)/4
      IU=IA+IB+IC+40
      I1=(IA+IB-IC+3)/4
      I2=(IB+IC-IA+3)/4
      I3=(IC+IA-IB+3)/4
      F3L=F3L*FAC(IT)/(FASQ(IU)*FAC(I1)*FAC(I2)*FAC(I3))
      RETURN
      END
