C*DECK DSPCFP
      SUBROUTINE DSPCFP (NFTF)
C                                 CHECKED TASHI 10/25/89 HUCC
      IMPLICIT  REAL*8(A-H,O-Z)
      include 'include/COMCFP'
      character * 1 ishell, lcoda
      external  lcoda
C     DIMENSION IFNUM (100)
C
C     NFTF = 10
C     READ (NFTF) INAME,IBEL,ICNN,ILFN,ICMTN,ICDX,IMMINT,ILSTAD
C     READ (NFTF) ((ICONNT(I,J),I=1,9),J=1,ICNN)
C     READ (NFTF)
C     READ (NFTF)  (ILFUNC(I),I=1,ILFN)
C     REWIND NFTF
      WRITE(6,100) INAME
 100  FORMAT (/' TABLE OF FRACTIONAL PARENTAGE COEFFICIENTS.'/
     * ' NAME: ',18A4/)
      DO 240 J = 1, ICNN
      ILFO = ICONNT (1,J)
      IQ   = ICONNT (2,J)
      ISP  = ICONNT (3,J)
      IF (ILFO .EQ. ILFP) GO TO 200
      ISHELL = LCODa (ILFO)
      L = (ILFO - 1) / 2
      ILFP = ILFO
      IF (J .NE. 1) WRITE (6, 222)
      WRITE (6, 210) ISHELL, L
 210  FORMAT (//'  ', a1,' type orbital.   l =', I3,
     * //'  digit ! spin   elec. # !            digit 4'
     * / '   1-3  ! mult.  min max !  0  1  2  3  4  5  6  7  8  9',
     *                             '  a  b  c  d  e  f',
     * / ' -------+----------------+-',16('---') )
 221  FORMAt ( 3x,z3,'  !     cont.      !', 16(2X,A1) )
 220  FORMAT ( 3X,Z3,'  !',I4,I6,I4,'  !  -', 15(2X,A1))
 222  FORMAT ( ' -------+----------------+-',16('---'))
 200  IELI = ILFO - IQ + 1
      IELF = ILFO + IQ - 1
      LI = ICONNT (5,J)
      LF = LI + ICONNT (4,J) - 1
      LFT = MIN0 (LI + 14, LF)
      ISEQ = J * 16
C     IF  ( LF-LI .GE. 100) go to 9000
C     DO 230 I = LI,LF
C230  IFNUM (I-LI+1) = LCODa (ILFUNC (I) )
      WRITE (6, 220) 
     *    ISEQ, ISP, IELI, IELF, ( LCODa(ILFUNC (I)), I = LI, LFT )
 250  IF (LFT .EQ. LF) GO TO 240
      LI = LFT + 1
      LFT = MIN0 (LI + 15, LF)
      ISEQ = ISEQ + 1
      WRITE (6, 221) ISEQ, ( LCODa(ILFUNC (I)), I = LI, LFT )
      GO TO 250
 240  CONTINUE
      WRITE (6,222)
C     STOP
      RETURN
      END
