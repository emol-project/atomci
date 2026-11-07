C*DECK AIIGTF
      SUBROUTINE AIIGTF (NRDFG,NMODFG,NFTD,LOEI,NWT,NAME,Z,IDPRNT,
     1  IIPRNT,NWLF,DEL,NPQN,LMAX,INXT,ISSH,IFST,IERCD)
      parameter (nbufmx = 12000)	 
*
*         GAUSSIAN  INTEGRAL  DRIVER
*
*         BASIC FUNCTION ... R**(L-1) * EXP( -D * R**2 ) Y(L,M)
*              ( NOTE : INPUT PRINCIPAL QUANTUM NUMBER IS REPLACED
*                       BY L-1. )
*
*                         CODED BY TASHI & MASA ON NOV.'84 AT HUCC
*                       REVISED BY MASAHIRO S.  ON MAY.'88 AT IMS
*                       REVISED BY TASHI        ON OCT.'89 AT HUCC
*
*
      IMPLICIT REAL*8(A-H,O-Z)
      DIMENSION NWLF(150),DEL(150),NPQN(150),DOP(150),INXT(150),
*    1 ISSH(20),IFST(20),ICRNT(20),FAC(57),NAME(33),BUFF(1600),ITAD(20)
     1 ISSH(20),IFST(20),ICRNT(20),NAME(33),BUFF(1600),ITAD(20)
      DIMENSION MPOB(150),MOB(150)
*------------------------------------------------------- STO -----> GTO
C     DIMENSION GAMMA(114)
      include 'include/COMWIG'
C     DIMENSION NTERM(150), OE(20,150), CE(20,150)
C------ 1998 JAN -----
      DIMENSION NTERM(150), OE(40,150), CE(40,150)
*------------------------------------------------------- STO -----> GTO
*mas
      DIMENSION OES(40,150)
      dimension istart(20+1)
*mas erronous
	  real*8  h000(nbufmx), S000(nbufmx)
*mas
      DATA IBUFF/1600/
      CALL CLOCKM(ITIN)
      CALL MODORB(NMODFG,DEL)
      IF(NMODFG.EQ.0) GO TO 1
      GO TO 1233
*------------------------------------------------------- STO -----> GTO
    1 CALL GINPUT(NWT,IDPRNT,
     1            NPQN,NWLF,DEL,NTERM,OE,CE,
     2            INXT,ISSH,IFST,ICRNT,LMAX,Z,NAME,NFTD,LOEI)
*------------------------------------------------------- STO -----> GTO
 1233 CONTINUE
*     FAC(1)=1.0D0
*     A=0.0D0
*     DO 1231 I=1,56
*     A=A+1.0D0
*1231 FAC(I+1)=FAC(I)*A
*------------------------------------------------------- STO -----> GTO
*
*     EVALUATE GAMMA FUNCTION FOR HALF INTEGER AND INTEGER
*
*     DO 12319 I = 1, 114
*        GAMMA(I) = DGAMMA( DFLOAT(I)/2.D0 )
*12319    CONTINUE
*                  
*     GAMMA is moved to common/comwig/
*
C     AT = PFGF3G(GAMMA)
*
*------------------------------------------------------- STO -----> GTO
*
*     MODIFY SCALING FACTOR AND EXPANSION COEFFICIENTS
*mas move
*      DO 12329 I = 1, NWT
*         DEL(I) = DEL(I) * DEL(I)
*         DO 12339 J = 1, NTERM(I)
*            CE(J,I) = CE(J,I) * OE(J,I) ** (DFLOAT(2*NPQN(I)+1)/4.D0)
*12339       CONTINUE
*12329    CONTINUE
*
*------------------------------------------------------- STO -----> GTO
*count and check
* assume s , p , d, f
* 
*	  istart starts from 0 
      K=0
      DO 131 I=1,LMAX
*mas istart  
	  istart(i) = k
      JMAX=ISSH(I)
      IF(JMAX.EQ.0) GO TO 131

      DO 132 J=1,JMAX
      K=K+1
      MPOB(K)=J
      MOB(K)=I-1
  132 CONTINUE
  131 CONTINUE
*mas istart
      istart(lmax+1) = k  
      I1=1
      Z0=0.0D0
      WRITE(6,1224) (MPOB(I),I=1,NWT)
      WRITE(6,1225)  (MOB(I),I=1,NWT)
 1225 FORMAT('0MOB   =',20I6/(8X,20I6))
 1224 FORMAT('0MPOB  =',20I6/(8X,20I6))
      WRITE(NFTD) NAME,LMAX,NWT,I1,I1,LOEI,(ISSH(I),I=1,LMAX),
     1  (MPOB(I),I=1,NWT),(MOB(I),I=1,NWT),Z,Z0,
     2  (NPQN(I),I=1,NWT),(DEL(I),I=1,NWT),
     3  (IFST(I),I=1,LMAX),(INXT(I),I=1,NWT),
     4  (NTERM(I),I=1,NWT),CE,OE
C        REVISED BY MAS ADDING NPQN & DEL  AT IMS ON 1988-03-01
C        REVISED BY MAS ADDING NTERM, CE, OE  AT HUCC ON 1989-10-26
*start all
* mas 
* check 
*     1. buff size
*     2. shuld be checked :  inext 
*
*     SCALE DEL AND BUILD THE DEL**2*OE EXPONENT H1NON NEEDS, BEFORE
*     H1NON IS CALLED BELOW.  OE ITSELF IS LEFT UNTOUCHED -- THE CE
*     RESCALE BELOW STILL NEEDS THE RAW OE, NOT DEL**2*OE.
*
      DO 12328 I = 1, NWT
         DEL(I) = DEL(I) * DEL(I)
         DO 12338 J = 1, NTERM(I)
            OES(J,I) = DEL(I) * OE(J,I)
12338       CONTINUE
12328    CONTINUE
      ihad = 1
      do 144 i = 1, lmax
	     iad = istart(i)+1
		 mmm = istart(i+1) - istart(i)
		 if ( issh(i) .ne. mmm ) stop 18000
		 if ( ihad > nbufmx ) stop 18001
	     call h1non(z,i-1,mmm,40,nterm(iad),oes(1,iad),ce(1,iad),
     1		        h000(ihad),S000(ihad))
		 ihad = ihad + mmm*(mmm+1)/2
  144 continue
*2334567890123345678901233456789012334567890123345678901233456789012334567890
*
*     MODIFY EXPANSION COEFFICIENTS (DEL ALREADY SCALED ABOVE)
*
      DO 12329 I = 1, NWT
         DO 12339 J = 1, NTERM(I)
            CE(J,I) = CE(J,I) * OE(J,I) ** (DFLOAT(2*NPQN(I)+1)/4.D0)
12339       CONTINUE
12329    CONTINUE
*------------------------------------------------------- STO -----> GTO
* start all 
      DO 143 I=1,NWT
      IQ=NPQN(I)
      DI=DEL(I)
*------------------------------------------------------- STO -----> GTO
* 143 DOP(I)=DSQRT((DI+DI)**(1+2*IQ)/FAC(1+2*IQ))
*
*     CALCULATE NORMALIZATION CONSTANT
*
      GNORM = 0.D0
      IPW = IQ + IQ + 1
      DO 1431 ITERM = 1, NTERM(I)
         DO 1432 JTERM = 1, NTERM(I)
            FACTOR = 1.D0 / DSQRT( DI * ( OE(ITERM,I)+OE(JTERM,I) ) )
            GNORM = GNORM + CE(ITERM,I) * CE(JTERM,I)
     1                    * FACTOR ** IPW
 1432       CONTINUE
 1431    CONTINUE
      DOP(I) = 1.D0 / DSQRT ( 0.5D0 * GAMMA(IPW) * GNORM )
  143 CONTINUE
*------------------------------------------------------- STO -----> GTO
*------------------------------------------------------- GTO rel -----
* write overlap matrix on nftd
      ITYP = 1
	  ihad = 1
	  do L = 1, lmax
	     nint = (issh(L)*(issh(L)+1))/2
	     call aiw1op(NFTD, LOEI, ITYP, L, nint, S000(ihad))
		 ihad = ihad + nint
	  end do
      ITYP = 2
	  ihad = 1
	  do L = 1, lmax
	     nint = (issh(L)*(issh(L)+1))/2
	     call aiw1op(NFTD, LOEI, ITYP, L, nint, h000(ihad))
		 ihad = ihad + nint
	  end do
* mas calculate igtad, itad(l)
      igtad = (issh(1)*(issh(1)+1))/2
	  itad(1) = 0
      do L = 2, lmax
          igtad = igtad + (issh(L)*(issh(L)+1))/2
	      ITAD(L)=(LMAX-L+2)*(  L-1)+ITAD(L-1)
*	  write(6,*) 'debug ', l,'  itad=',itad(l),'  igtad=',igtad,'  ist=',ist
	  end do
*        call chkgam()
*------------------------------------------------------- GTO rel -----
  171  continue
      KMAX=2*LMAX-1
      IF(IDPRNT.NE.0) WRITE(6,9998)
 9998 FORMAT('0     KM     LN1  LN2  LN3  LN4    IDIMA    IDIMB'
     1   ,'    IGTAD'/)
      IADMAX=0
      DO 191 KM=1,KMAX
      KPT=MOD(KM+1,2)+1
      ISAD=0
      DO 192 IDA=KPT,LMAX,2
      IF(IDA.GT.KM) GO TO 191
      DO 193 ITA=IDA,KMAX,2
      IF(ITA.LT.KM) GO TO 193
      LN1=(IDA+ITA)/2
      IF(LN1.GT.LMAX) GO TO 192
      LN2=(ITA-IDA)/2+1
      KT=(ITA-KM)/2
      IAD=ITAD(LN2)+KT*(LMAX-LN2+1)+IDA
      IADMAX=MAX0(IAD,IADMAX)
      IDIMA=ISSH(LN1)*ISSH(LN2)
      IF(IDA.EQ.1) IDIMA=(ISSH(LN1)*(ISSH(LN1)+1))/2
      ISAD=ISAD+IDIMA
      DO 194 IDB=KPT,IDA,2
      ITBG=KMAX
      IF(IDB.EQ.IDA) ITBG=ITA
      DO 195 ITB=IDB,ITBG,2
      IF(ITB.LT.KM) GO TO 195
      LN3=(IDB+ITB)/2
      IF(LN3.GT.LMAX) GO TO 194
      LN4=(ITB-IDB)/2+1
      IDIMB=ISSH(LN3)*ISSH(LN4)
      IF(IDB.EQ.1) IDIMB=(ISSH(LN3)*(ISSH(LN3)+1))/2
      IDIM= IDIMA*IDIMB
      IF(IDA.EQ.IDB.AND.ITA.EQ.ITB) IDIM=(IDIMA*(IDIMA+1))/2
      IF(IDPRNT.NE.0) WRITE(6,9999) KM,LN1,LN2,LN3,LN4,IDIMA,IDIMB,IGTAD
 9999 FORMAT(2I8,3I5,3I9)
      IF(IDIM.EQ.0) GO TO 195
      NCODA=1
      NCODB=1
      NCODI=0
      IF(LN1.EQ.LN2) NCODA=3
      IF(LN3.EQ.LN4) NCODB=3
      IF(IDA.EQ.IDB.AND.ITA.EQ.ITB) NCODI=1
      KMM1=KM-1
      LK1=LN1-1
      LK2=LN2-1
      LK3=LN3-1
      LK4=LN4-1
      WRITE(NFTD) KMM1,LK1,LK2,LK3,LK4,ISSH(LN1),ISSH(LN2),ISSH(LN3),
     1  ISSH(LN4),IDIMA,IDIMB,NCODI,NCODA,NCODB
      KRD=IFST(LN4)
  214 IQR=NPQN(KRD)
      DQR=DEL(KRD)
      KSD=IFST(LN3)
  213 IQS=NPQN(KSD)
      DQS=DEL(KSD)
      AO=DOP(KRD)*DOP(KSD)
      IST=0
      KPD=IFST(LN2)
  212 IQP=NPQN(KPD)
      DQP=DEL(KPD)
      KQD=IFST(LN1)
  211 IQQ=NPQN(KQD)
      DQQ=DEL(KQD)
      IST=IST+1
      IF(IST.GT.IBUFF) GO TO 9005
*------------------------------------------------------- STO -----> GTO
*     BUFF(IST)=FGF3(IQP+IQQ,IQR+IQS,  KM-1,DQP+DQQ,DQR+DQS)*
*
*     CALCULATE TWO ELECTRON INTEGRALS
*
      GINT1 = 0.D0
      IPQSUM = IQP + IQQ
      IRSSUM = IQR + IQS
      DO 21111 KTERM = 1, NTERM(KRD)
         DO 21112 LTERM = 1, NTERM(KSD)
            CPRODA = CE(KTERM,KRD) * CE(LTERM,KSD)
            DO 21113 ITERM = 1, NTERM(KPD)
               DO 21114 JTERM = 1, NTERM(KQD)
                  GINT1 = GINT1 + CPRODA
     1                          * CE(ITERM,KPD) * CE(JTERM,KQD)
     2                          * FGF3G(IPQSUM,IRSSUM,KM-1,
     3                            DQP*OE(ITERM,KPD)+DQQ*OE(JTERM,KQD),
     4                            DQR*OE(KTERM,KRD)+DQS*OE(LTERM,KSD) )
21114             CONTINUE
21113          CONTINUE
21112       CONTINUE
21111    CONTINUE
      BUFF(IST) = AO * DOP(KPD) * DOP(KQD) * GINT1
*     WRITE(6,*) 'DEBUG ON TEL'
*     WRITE(6,*) KRD,KSD,KPD,KQD,KM
*     WRITE(6,*) IST,BUFF(IST)
*------------------------------------------------------- STO -----> GTO
      KQD=INXT(KQD)
      IF(KQD.EQ.0) GO TO 201
      IF(NCODI.EQ.1.AND.KPD.EQ.KRD.AND.KQD.GT.KSD) GO TO 201
      IF(LN1.EQ.LN2.AND.KQD.GT.KPD) GO TO 201
      GO TO 211
  201 KPD=INXT(KPD)
      IF(KPD.EQ.0) GO TO 202
      IF(NCODI.EQ.1.AND.KPD.GT.KRD) GO TO 202
      GO TO 212
  202 WRITE(NFTD) (BUFF(I),I=1,IST)
      IF(IIPRNT.GT.4) WRITE(6,8001) (BUFF(I),I=1,IST)
 8001 FORMAT(8E16.7)
      IGTAD=IGTAD+IST
      KSD=INXT(KSD)
      IF(KSD.EQ.0) GO TO 203
      IF(LN3.EQ.LN4.AND.KSD.GT.KRD) GO TO 203
      GO TO 213
  203 KRD=INXT(KRD)
      IF(KRD.NE.0) GO TO 214
  195 CONTINUE
  194 CONTINUE
  193 CONTINUE
  192 CONTINUE
  191 CONTINUE
C     WRITE(6,9004) IADMAX,IGTAD
C9004 FORMAT('0IADMAX=',I7,7X,'IGTAD =',I7)
      WRITE(6,9004) IGTAD
 9004 FORMAT('0GENERATED INTEGRAL =',I10)
  300 CALL CLOCKM(ITOUT)
      TT=DFLOAT(ITOUT-ITIN)/1000.0D0
      WRITE(6,500) TT
  500 FORMAT('0PROGRAM  INTEGRAL LIST      USED TIME =', F7.2,' SEC')
      RETURN
 9005 WRITE(6,9006) IBUFF
 9006 FORMAT('0IBUFF TOO SMALL     IBUFF =',I7,7X,'ERROR  *********')
      GO TO 300
      END
