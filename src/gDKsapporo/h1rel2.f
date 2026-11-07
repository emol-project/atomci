      subroutine h1init(z, lmax, ifdk3, ifnucl)
      implicit real*8 (a-h, o-z)
      logical ifdk3, ifnucl
c
      common/bfinf/
     *       NBF, NKUMI, KUMI( 2, 19810 ), KNOT( 2, 19810 ) 
      COMMON/RPNT/
     *       RINV( 15728 ), R( 15728 )
      COMMON/CDVAL/
     *       CDV( 3302240 ), CDD( 3302240 ), CD2( 3302240 ),
     *       IRCDV( 3302240 )
      COMMON/DKPOT/
     &       S( 500500 ), H( 500500, 7 ),
     &       V( 500500, 7 ), V2( 500500, 7 )
Caa    &       S( 500500 ), H( 500500, 6 ),
Caa    &       V( 500500, 6 ), V2( 500500, 6 )
      common/glinf/t( 1022 ), wgl( 16 ), zgl( 16 ), 
     *       ngl, method, nsym, ncl, kdim
C*
      CHARACTER KSCHM( 4 ) *17, MTHD *3
      DATA KSCHM/'SAITO''S SCHEME  ',
     &           'EXPONETIAL SCHEME',
     &           'UNIFORM SCHEME   ',
     &           'SIN-LIKE SCHEME  '/
C*
      nsym = lmax
      if (ifdk3) then 
         method = 5
         mthd = 'DK3'
      else
         method = 4
         mthd = 'DK2'
      endif
c*
      if (ifnucl) then 
         ncl = 2
      else
         ncl = 0
      endif
c*
      kdim = 9
c      nbf = 40
      nbf = 100
      rmax = 40
c      r1 = 1.d-2
      r1 = 1.d-4
      ngl = 12
c     iknot = 1
      iknot = 2
C
C
C     DATA PRINT
C
C
      WRITE(6,'(2X,A,3X,A)') 'METHOD                            =', MTHD
      WRITE(6,'(2X,A,F6.1)') 'Z   :  NUCLEAR CHARGE             =', Z
C*
      WRITE(6,'(2X,A,I6)') 'NBF :  NUMBER OF B-SPLINES        =', NBF
      WRITE(6,'(2X,A,I6)') 'KDIM:  ORDER OF B-SPLINES         =', KDIM
      WRITE(6,'(2X,A,F6.1,/)')
     &                     'RMAX:  CAVITY RADIUS (au)         =', RMAX
C*
      WRITE(6,'(2X,A,A)')    'KNOT SEQUENCE : ', KSCHM( IKNOT )
      IF( IKNOT .LE. 3 ) WRITE(6,'(2X,A,D8.1)')
     &                     'R1  :  INITIAL INTERVAL (au)      =', R1
      WRITE(6,'(2X,A,I6,/)') 'NGL :  POINTS FOR GAUSS-LEGENDRE  =', NGL
C*
      CALL INIT( R1, RMAX, T, KDIM, NBS, NBF, IKNOT )
      CALL CHDNS( T, WGL, ZGL, NGL, KDIM, NBS )
      CALL FNCSET( Z, XI, RG, NCL )
      CALL OEI( XI, RG, Z, NSYM, NCL, NGL )
      CALL INITDK( T, WGL, ZGL, NGL,
     &         METHOD, NSYM, NCL, KDIM, NBF )
      return
      end
c
      subroutine h1rel2(lv, m, ndim, nterm, del, coef, h)
      implicit real*8 (a-h, o-z)
      common/bfinf/
     *       NBF, NKUMI, KUMI( 2, 19810 ), KNOT( 2, 19810 ) 
      common/glinf/t( 1022 ), wgl( 16 ), zgl( 16 ), 
     *       ngl, method, nsym, ncl, kdim
      dimension nterm(m), del(ndim, m), coef(ndim, m), h(*)
c
      dimension agf(100,100), cgf(100,100), ncgf(100)
c
      ntgf = m
      do i = 1, m
         ncgf(i) = nterm(i)
         do j = 1, ncgf(i)
            agf(j, i) = del(j, i)
            cgf(j, i) = coef(j, i) 
     *                / dsqrt(gint(del(j,i)*2, lv*2+2))
         end do
      end do
      call gdk( h, agf, cgf, t, wgl, zgl, ngl,
     *         method, nsym, kdim, nbf, ncgf, ntgf, lv+1 )
c
      return
      end
