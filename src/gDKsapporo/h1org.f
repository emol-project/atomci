      implicit real*8 (a-h, o-z)
      logical ifdk3, ifnucl
      dimension nterm(3), del(5,3), coef(5,3), h(10)
      data del/103109.464234, 15281.006720, 3441.539198,
     *     967.094830, 314.035338,
     *     113.442296, 0., 0., 0., 0.,
     *     44.644727, 0., 0., 0., 0./
      data coef/0.001279, 0.010054, 0.053329, 0.223868, 0.781481,
     *     1.0, 0., 0., 0., 0.,
     *     1.0, 0., 0., 0., 0./
      data nterm/5,1,1/
      z = 9.d0
      lmax = 2
      ifdk3 = .true.
      ifnucl = .true.
      call h1init(z, lmax, ifdk3, ifnucl)
      call h1rel2(0, 3, 5, nterm, del, coef, h)
      write(6,*) "**************************"
      write(6,*) (h(i), i = 1, 6)
      stop
      end

