C*DECK NTRNPP
      SUBROUTINE NTRNPP (NIN,NOUT,NP,MP,A,B,NDD,CP,CPQ)
C                                CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION A(*),B(*),CP(*),CPQ(*)
C
   10 NB=0
      DO 40 M=1,MP
      NAD=NIN-1
      DO 32 I=1,NP
      NA=NAD
      SUM=0.0D0
      DO 16 J=1,I
   16 SUM=SUM+A(NA+J)*CP(NB+J)
      IF (I.EQ.NP) GO TO 30
      NA=NA+I+I
      IA=I+1
      DO 20 J=IA,NP
      SUM=SUM+A(NA)*CP(NB+J)
   20 NA=NA+J
   30 CPQ(NB+I)=SUM
   32 NAD=NAD+I
   40 NB=NB+NP
C
   50 NA=0
      NAD=NOUT
      DO 80 M=1,MP
      NB=0
      DO 70 I=1,M
      SUM=0.0D0
      DO 60 J=1,NP
   60 SUM=SUM+CP(NA+J)*CPQ(NB+J)
      B(NAD)=SUM
      NAD=NAD+NDD
   70 NB=NB+NP
   80 NA=NA+NP
   90 RETURN
C
      END
C*DECK NTRNQP
      SUBROUTINE NTRNQP (NIN,NOUT,NP,MP,NQ,MQ,A,B,NCD,CP,CQ,CPQ)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION A(*),B(*),CP(*),CQ(*),CPQ(*)
C
   10 NB=0
      NC=0
      NAD=NIN-1
      DO 40 M=1,MP
      NA=NAD
      DO 30 J=1,NQ
      SUM=0.0D0
      DO 20 I=1,NP
   20 SUM=SUM+A(NA+I)*CP(NB+I)
      CPQ(NC+J)=SUM
   30 NA=NA+NP
      NB=NB+NP
   40 NC=NC+NQ
C
   50 NA=0
      NC=NOUT
      DO 80 M=1,MQ
      NB=0
      DO 70 J=1,MP
      SUM=0.0D0
      DO 60 I=1,NQ
   60 SUM =SUM+CQ(NA+I)*CPQ(NB+I)
      B(NC)=SUM
      NC=NC+NCD
   70 NB=NB+NQ
   80 NA=NA+NQ
C
   90 RETURN
C
      END
C*DECK NTRNRR
      SUBROUTINE NTRNRR (NIN,NTL,NP,MP,A,B,CP,CPQ)
C                           CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION A(*),B(*),CP(*),CPQ(*)
C
   10 NB=0
      DO 40 M=1,MP
      NAD=NIN-1
      DO 32 I=1,NP
      NA=NAD
      SUM=0.0D0
      DO 16 J=1,I
   16 SUM=SUM+A(NA+J)*CP(NB+J)
      IF (I.EQ.NP) GO TO 30
      NA=NA+I+I
      IA=I+1
      DO 20 J=IA,NP
      SUM=SUM+A(NA)*CP(NB+J)
   20 NA=NA+J
   30 CPQ(NB+I)=SUM
   32 NAD=NAD+I
   40 NB=NB+NP
C
   50 NA=0
      NAD=1
      DO 80 M=1,MP
      NB=0
      DO 70 I=1,M
      SUM=0.0D0
      DO 60 J=1,NP
   60 SUM=SUM+CP(NA+J)*CPQ(NB+J)
      B(NAD)=SUM
      NAD=NAD+1
      IF (NAD.GT.NTL) GO TO 90
   70 NB=NB+NP
   80 NA=NA+NP
   90 RETURN
C
      END
C*DECK NTRNRS
      SUBROUTINE NTRNRS(NIN,NTL,NP,MP,NQ,MQ,A,B,CP,CQ,CPQ)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT REAL*8 (A-H,O-Z)
      DIMENSION A(*),B(*),CP(*),CQ(*),CPQ(*)
C
   10 NB=0
      NC=0
      NAD=NIN-1
      DO 40 M=1,MP
      NA=NAD
      DO 30 J=1,NQ
      SUM=0.0D0
      DO 20 I=1,NP
   20 SUM=SUM+A(NA+I)*CP(NB+I)
      CPQ(NC+J)=SUM
   30 NA=NA+NP
      NB=NB+NP
   40 NC=NC+NQ
C
   50 NA=0
      NC=1
      DO 80 M=1,MQ
      NB=0
      DO 70 J=1,MP
      SUM=0.0D0
      DO 60 I=1,NQ
   60 SUM =SUM+CQ(NA+I)*CPQ(NB+I)
      B(NC)=SUM
      NC=NC+1
      IF (NC.GT.NTL) GO TO 90
   70 NB=NB+NQ
   80 NA=NA+NQ
C
   90 RETURN
C
      END
