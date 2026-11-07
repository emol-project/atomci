c***** one electron integrals non relativistic *****
c
      subroutine h1non(z, l, m, ndim, nterm, del, coef, h,s)
      integer m, l, ndim, nterm(m), p, q 
      real*8 z, del(ndim, m), coef(ndim, m), h(*),s(*)
c     real*8 getop, gets, gett, getv, dummy, getcf, getdel
      real*8 getop, gets, gett, getv
      external gett, getv, gets
c
      call bsset(l, m, ndim, nterm, del, coef, .true.) 
	  ist = 0
      do p = 1, m
         do q = 1, p
	   ist = ist + 1
           h(ist) = getop(gett, l, z, p, q) + getop(getv, l, z, p, q)
	   s(ist) =  getop(gets,l,z,p,q)
         end do
      end do
      return
      end
c***** one electron integrals non relativistic *****
c
      subroutine h1rel(z, l, m, ndim, nterm, del, coef, hh,ss,
     *     ifdk3, ifnucl)
      integer m, l, ndim, nterm(m), p, q 
      real*8 z, del(ndim, m), coef(ndim, m), hh(*),ss(*)
      real*8 getop, gets, gett, getv
      external gett, getv, gets
c
      logical ifdk3, ifnucl
c             ifdk3 ... true for dk3, false for dk2
c             ifnucl ... true for finite nuclei, false for point charge
      call bsset(l, m, ndim, nterm, del, coef, .false.)
      ist = 0
      do p = 1, m
         do q = 1, p
		   ist = ist + 1
           ss(ist) =  getop(gets,l,z,p,q)
         end do
      end do
      call h1rel2(l, m, ndim, nterm, del, coef, hh) 
      return
      end
      
c
      subroutine bsset(lin, m, ndim, ntin, delin, cin, nonrel) 
      parameter (nbmax = 200)
      parameter (ntmax = 50)
      common/bsdata/del(ntmax,nbmax), coef(ntmax,nbmax), norm(nbmax),
     *     lm, nbf, nbfpl, nterm(nbmax)
      real*8 del, coef, norm
      integer lm, nbf, nbfpl, nterm
	  logical nonrel
c
      real*8 delin(ndim,m), cin(ndim,m)
      integer ntin(m)
      real*8 gets, tmp, tmp2, tmps, dummy, getop, getnrm
      external gets
      logical ifuniq
      real*8 getcf, getdel
c
      dummy = 0.d0
      lm = lin
      nbf = m
      do i = 1, nbf
         nterm(i) = ntin(i)
         do k = 1, nterm(i)
            del(k,i) = delin(k,i)
            coef(k,i) = cin(k,i)
     *           / sqrt(gets(lm,del(k,i),del(k,i),dummy))
         end do
         tmp = 0.d0
         do k = 1, nterm(i)
            do l = 1, k
               tmp2 = coef(k,i)*coef(l,i)
     *              * gets(lm,del(k,i),del(l,i),dummy)
               if (k .eq. l) then
                  tmp = tmp + tmp2
               else
                  tmp = tmp + tmp2 * 2
               end if
            end do
         end do
         norm(i) = 1.d0 / sqrt(tmp)
      end do
      return
      end
c
c
      real*8 function getop(op, l, z, a, b)
         integer l, a, b
         real*8 op, z
         real*8 getdel, getcf, getnrm
         integer getnt
         integer p, q
         real*8 tmp
c
         tmp = 0.d0
         do p = 1, getnt(a)
            do q = 1, getnt(b)
               tmp = tmp + getcf(a,p) * getcf(b,q) 
     *              * op(l, getdel(a,p), getdel(b,q), z)
            end do
         end do
         getop = tmp * getnrm(a) * getnrm(b)
         return
      end
c
c
      real*8 function gets(l, a, b, z)
         integer l, idummy
         real*8 a, b, z, gint2
         gets = gint2(l*2 + 2, a+b)
         return
      end
c
      real*8 function gett(l, a, b, z)
         integer l
         real*8 a, b, z, gint2
         gett = gint2(l * 2, a + b) * l * (2 * l + 1) / 2
     *        - gint2(l * 2 + 2, a + b) * l * (a + b)
     *        + gint2(l * 2 + 4, a + b) * 2 * a * b
         return
      end
c
      real*8 function getv(l, a, b, z)
         integer l
         real*8 a, b, z, gint2
         getv = -z * gint2(l*2 + 1, a + b)
         return
      end
      real*8 function gint2(n, del)
c         integer n, m, fact, dfact 
         integer n, m
		 real * 8  fact, dfact 
         real*8 del, c1, pi

         c1 = 1.d0
         if ( mod(n,2) .eq. 0 ) then
            pi = atan(c1)*4
            m = n / 2
            gint2 = sqrt(pi/del)*dfact(2 * m - 1) / 2 / (2 * del)**(m)
         else          
            m = (n - 1) / 2
            gint2 = c1 / 2 / del**(m+1) * fact(m)
         end if
         return
      end
c
c
      integer function getnt(i)
      parameter (nbmax = 200)
      parameter (ntmax = 50)
      common/bsdata/del(ntmax,nbmax), coef(ntmax,nbmax), norm(nbmax),
     *     lm, nbf, nbfpl, nterm(nbmax)
      real*8 del, coef, norm
      integer i
c
      getnt = nterm(i)
      return
      end
c
      real*8 function getdel(i, k)
      parameter (nbmax = 200)
      parameter (ntmax = 50)
      common/bsdata/del(ntmax,nbmax), coef(ntmax,nbmax), norm(nbmax),
     *     lm, nbf, nbfpl, nterm(nbmax)
      real*8 del, coef, norm
      integer i, k
c
      getdel = del(k,i)
      return
      end
c
      real*8 function getcf(i, k)
      parameter (nbmax = 200)
      parameter (ntmax = 50)
      common/bsdata/del(ntmax,nbmax), coef(ntmax,nbmax), norm(nbmax),
     *     lm, nbf, nbfpl, nterm(nbmax)
      real*8 del, coef, norm
      integer i, k
c
      getcf = coef(k,i)
      return
      end
c
      real*8 function getnrm(i)
      parameter (nbmax = 200)
      parameter (ntmax = 50)
      common/bsdata/del(ntmax,nbmax), coef(ntmax,nbmax), norm(nbmax),
     *     lm, nbf, nbfpl, nterm(nbmax)
      real*8 del, coef, norm
      integer i, k
c
      getnrm = norm(i)
      return
      end
c
Cmas      integer function fact(n)
      real * 8  function fact(n)
      parameter(nfmax=81)
      integer n
	  real * 8  fact0(nfmax)
       data fact0/
     1 0.10000000000000D+01,0.20000000000000D+01,0.60000000000000D+01,
     1 0.24000000000000D+02,0.12000000000000D+03,0.72000000000000D+03,
     1 0.50400000000000D+04,0.40320000000000D+05,0.36288000000000D+06,
     1 0.36288000000000D+07,0.39916800000000D+08,0.47900160000000D+09,
     1 0.62270208000000D+10,0.87178291200000D+11,0.13076743680000D+13,
     1 0.20922789888000D+14,0.35568742809600D+15,0.64023737057280D+16,
     1 0.12164510040883D+18,0.24329020081766D+19,0.51090942171709D+20,
     1 0.11240007277776D+22,0.25852016738885D+23,0.62044840173324D+24,
     1 0.15511210043331D+26,0.40329146112661D+27,0.10888869450418D+29,
     1 0.30488834461171D+30,0.88417619937397D+31,0.26525285981219D+33,
     1 0.82228386541779D+34,0.26313083693369D+36,0.86833176188119D+37,
     1 0.29523279903960D+39,0.10333147966386D+41,0.37199332678990D+42,
     1 0.13763753091226D+44,0.52302261746660D+45,0.20397882081197D+47,
     1 0.81591528324790D+48,0.33452526613164D+50,0.14050061177529D+52,
     1 0.60415263063374D+53,0.26582715747884D+55,0.11962222086548D+57,
     1 0.55026221598121D+58,0.25862324151117D+60,0.12413915592536D+62,
     1 0.60828186403427D+63,0.30414093201713D+65,0.15511187532874D+67,
     1 0.80658175170944D+68,0.42748832840600D+70,0.23084369733924D+72,
     1 0.12696403353658D+74,0.71099858780486D+75,0.40526919504877D+77,
     1 0.23505613312829D+79,0.13868311854569D+81,0.83209871127414D+82,
     1 0.50758021387722D+84,0.31469973260388D+86,0.19826083154044D+88,
     1 0.12688693218588D+90,0.82476505920825D+91,0.54434493907744D+93,
     1 0.36471110918189D+95,0.24800355424368D+97,0.17112245242814D+99,
     1 0.11978571669970D+101,0.85047858856786D+102,
     1 0.61234458376886D+104,0.44701154615127D+106,
     1 0.33078854415194D+108,0.24809140811395D+110,
     1 0.18854947016661D+112,0.14518309202829D+114,
     1 0.11324281178206D+116,0.89461821307830D+117,
     1 0.71569457046264D+119,0.57971260207474D+121/
       if ( n .le. 1 ) then
           fact = 1.d0

       else if ( n .le. nfmax ) then
       	   fact = fact0(n)        
       else
           stop 336   
       end if
       return

C           	fact = 1.d0 
C         	do i = n, 1, -1
C            	fact = fact * i
C         	end do 
C         	return
      end
c
* mas      integer function dfact(n)
      real*8 function dfact(n)
      parameter(nfmax=81)
      integer n
	  real * 8  dfact0(nfmax)
          data dfact0/
     1 0.10000000000000D+01,0.20000000000000D+01,0.30000000000000D+01,
     1 0.80000000000000D+01,0.15000000000000D+02,0.48000000000000D+02,
     1 0.10500000000000D+03,0.38400000000000D+03,0.94500000000000D+03,
     1 0.38400000000000D+04,0.10395000000000D+05,0.46080000000000D+05,
     1 0.13513500000000D+06,0.64512000000000D+06,0.20270250000000D+07,
     1 0.10321920000000D+08,0.34459425000000D+08,0.18579456000000D+09,
     1 0.65472907500000D+09,0.37158912000000D+10,0.13749310575000D+11,
     1 0.81749606400000D+11,0.31623414322500D+12,0.19619905536000D+13,
     1 0.79058535806250D+13,0.51011754393600D+14,0.21345804667688D+15,
     1 0.14283291230208D+16,0.61902833536294D+16,0.42849873690624D+17,
     1 0.19189878396251D+18,0.13711959581000D+19,0.63326598707629D+19,
     1 0.46620662575399D+20,0.22164309547670D+21,0.16783438527144D+22,
     1 0.82007945326379D+22,0.63777066403146D+23,0.31983098677288D+24,
     1 0.25510826561258D+25,0.13113070457688D+26,0.10714547155728D+27,
     1 0.56386202968058D+27,0.47144007485205D+28,0.25373791335626D+29,
     1 0.21686243443194D+30,0.11925681927744D+31,0.10409396852733D+32,
     1 0.58435841445947D+32,0.52046984263667D+33,0.29802279137433D+34,
     1 0.27064431817107D+35,0.15795207942840D+36,0.14614793181238D+37,
     1 0.86873643685618D+37,0.81842841814931D+38,0.49517976900802D+39,
     1 0.47468848252660D+40,0.29215606371473D+41,0.28481308951596D+42,
     1 0.17821519886599D+43,0.17658411549989D+44,0.11227557528557D+45,
     1 0.11301383391993D+46,0.72979123935621D+46,0.74589130387155D+47,
     1 0.48896013036866D+48,0.50720608663266D+49,0.33738248995438D+50,
     1 0.35504426064286D+51,0.23954156786761D+52,0.25563186766286D+53,
     1 0.17486534454335D+54,0.18916758207052D+55,0.13114900840752D+56,
     1 0.14376736237359D+57,0.10098473647379D+58,0.11213854265140D+59,
     1 0.79777941814292D+59,0.89710834121121D+60,0.64620132869576D+61/  
       if ( n .le. 1 ) then
           dfact = 1.d0

       else if ( n .le. nfmax ) then
       	   dfact = dfact0(n)        
       else
           stop 337   
       end if
       return

C            dfact = 1.d0
C         	do i = n, 1, -2
C            	dfact = dfact * i
C         	end do 
C        	return
      end
      
