C*DECK BIT
C   *****  FUNCTION BIT ***********
C     FUNCTION FOR BIT ON OR OFF
C     A(25) * 32 BIT = 800 BIT
C     NBIT   : BIT #
C     KBIT   : BIT # IN A(KA)
C     KA     : ARRAY # FOR A
C                                 CHECKED TASHI 10/25/89 HUCC
C   Changed by msekiya 01/04/2010 
      FUNCTION BIT(A,NBIT)
      INTEGER*4 A(25),NBIT,KBIT,KA,BIT
C      INTEGER * 4 cbit(0:31)
C      data cbit /
C     * z'   1',z'   2',z'   4',z'   8',z'  10',z'  20',z'  40',z'  80',
C     * z' 100',z' 200',z' 400',z' 800',z'1000',z'2000',z'4000',z'8000',
C     * z'       10000',z'       20000',z'       40000',z'       80000',
C     * z'      100000',z'      200000',z'      400000',z'      800000',
C     * z'     1000000',z'     2000000',z'     4000000',z'     8000000',
C     * z'    10000000',z'    20000000',z'    40000000',z'    80000000'/
      SETBIT = 0
      KBIT   = MOD( NBIT- 1,32)
      KA     = ( NBIT - 1 ) / 32 + 1
      BIT = 0
C      IF  ( and( A(KA), cbit(KBIT) ) .ne. 0 ) BIT = 1
      if ( btest(a(ka), kbit) ) bit = 1
C     write(6,999)' bit: BIT,NBIT,A(KA)=',bit,nbit,a(ka)
C 999 format(a,i2,i5,z10,a,z10)
      RETURN
      END
C*DECK SETBIT
C   ***** SUBROUTINE SETBIT ***********
C     SETBIT FOR ONE DIMENSIONAL 800 BIT ARRAY
C     A(25) * 32 BIT = 800 BIT
C     NBIT   : BIT #
C     KBIT   : BIT # IN A(KA)
C     KA     : ARRAY # FOR A
C                                  CHECKED TASHI 10/25/89
      SUBROUTINE SETBIT(A,NBIT)
      INTEGER*4 A(25),NBIT,KBIT,KA
C      INTEGER *4 cbit(0:31)
C      data cbit /
C     * z'   1',z'   2',z'   4',z'   8',z'  10',z'  20',z'  40',z'  80',
C     * z' 100',z' 200',z' 400',z' 800',z'1000',z'2000',z'4000',z'8000',
C     * z'       10000',z'       20000',z'       40000',z'       80000',
C     * z'      100000',z'      200000',z'      400000',z'      800000',
C     * z'     1000000',z'     2000000',z'     4000000',z'     8000000',
C     * z'    10000000',z'    20000000',z'    40000000',z'    80000000'/
      KBIT   = MOD( NBIT- 1,32)
      KA     = ( NBIT - 1 ) / 32 + 1
C      a(ka)  = or( A(KA), cbit(KBIT) )
      a(ka) = ibset(a(ka),kbit)
C     write(6,999)' setbit: NBIT,A(KA)=',nbit,a(ka)
C 999 format(a,i5,z10)
      RETURN
      END

