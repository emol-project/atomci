* myfunc
* calc one el addr
        subroutine aichk0(lmax, ifst, inext, nwlf, issh)
		Dimension ifst(20), inext(150), nwlf(150), issh(lmax)
* s for 1	
		k = 1	
		do l = 1, lmax
			ls = ifst(l)
			do j = 1, issh(lmax) 
			    k = k + 1
				next = inext(ls)
				if ( next .eq. 0 ) then
				else if ( k .eq. next ) then
				else 
					write(6,*) ' we assume sss, ppp, ddd, etc '
					write(6,*) ' we do not accept ss pp ss dd pp etc'
					stop 10082
				end if
				ls = next
			end do
		end do
		return 
		end
	  subroutine aiw1op( NFTD, Loei, ityp, l, ist, buff)
	  real * 8 buff(ist)
*	  write(6,'(A,5i8)') ' NFTD ', nftd, loei, ityp, l, ist
      M=L-1
*      ITYP=1 for overlap  2 for T + V
      IMIN=1
 1551 IMAX=MIN0(IMIN+LOEI-1,IST)
      LCL=IMAX-IMIN+1
      WRITE(NFTD) ITYP,L,LCL,(BUFF(I),I=IMIN,IMAX)
*      WRITE(6,8000) ITYP,L,LCL,(BUFF(I),I=IMIN,IMAX)
      IMIN=IMAX+1
      IF(IMIN.LE.IST) GO TO 1551
	  return 	
 8000 FORMAT(3I8,6E17.7/(24X,6E17.7))
      end 	
	  subroutine chkgam() 
	  include       'include/COMWIG'
	  real*8 fact, dfact
	  do i = 1, 57
	     write (6,'(i4, 2e15.7, i30)') i, fac(i), fact(i)
	     write (6,'(i4, 3e15.7, i30)') i, gamma(i*2), gamma((i-1)*2+1), dfact(i)
	  end do
	  end
