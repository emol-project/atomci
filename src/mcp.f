C-----------------------------------------------------------------------
      SUBROUTINE STUB(LA,IS,JS,NQN,NB,ZETA,COEF,RT1,RT2,RT3,RT4)
C-----------------------------------------------------------------------
      IMPLICIT REAL*8(A-H,O-Z),INTEGER(I-N)
      COMMON /MPOT1/ SSVM(150,15),ZETAC(40,15),COEFC(40,15),
     1               PA(6),SA(6),PC(6),SB(6),PB(15),
     &               NQNC(15),NBC(15),IFMCP,NFMCP,
     2               NA,NSTYP,NCBC,NSIM0xd,IWIT,IFLV,
     3               IV(40),IPxd1,IPxd2,IPxd3
      DIMENSION NQN(150),NB(150), ZETA(40,150),COEF(40,150)
C
      WF(L,N,X)=2.0D0*DFLOAT(N-L)/X
C
c     write(6,*) 'Zeta=',(Zeta(i,1),i=1,3)
c     write(6,*) 'Coef=',(Coef(i,1),i=1,3)
      NP=NQN(IS)
      NQ=NQN(JS)
      NBP=NB(IS)
      NBQ=NB(JS)
      SUMS=0.0D0
      SUMT=0.0D0
      SUMU=0.0D0
      DO 10 IP=1,NBP
      ZP=ZETA(IP,IS)
      CP=COEF(IP,IS)
      DO 10 IQ=1,NBQ
      ZQ=ZETA(IQ,JS)
      CQ=COEF(IQ,JS)
      ZAV=0.5D0*(ZP+ZQ)
      IT1=2*NP
      IT2=2*NQ
      RT1=1.0D0/(VF(IT1,ZP)*VF(IT2,ZQ))
      RT1=CP*CQ*DSQRT(RT1)
      IT1=NP+NQ
      RT2=VF(IT1,ZAV)
      RT3=(DFLOAT(IT1+1)*RT2)/ZAV
      IT1=IT1-1
      RT4=(ZAV*RT2)/DFLOAT(IT1)
      RT5=VF(IT1,ZAV)
      SUMA=0.0D0
      IF(NA.EQ.0) GO TO 25
      DO 20 IA=1,NA
      ZAVPA=ZAV+0.5D0*SA(IA)
      SUMA=SUMA+PA(IA)*VF(IT1,ZAVPA)
   20 CONTINUE
   25 CONTINUE
      RT6=WF(LA,NP,ZP)
      RT7=WF(LA,NQ,ZQ)
      RT8=RT6+RT7
      RT9=RT6*RT7
      SUMS=SUMS+RT1*RT2
      SUMT=SUMT+ZP*ZQ*RT1*(RT3-RT8*RT2+RT9*RT4)
      SUMU=SUMU+RT1*(RT5+SUMA)
      IF(NSTYP.EQ.0) GO TO 10
      IT11=IT1+1
      DO 300 IA=1,NSTYP
      ZSBI=ZAV+0.5D0*SB(IA)
  300 SUMU=SUMU+RT1*0.626657069D0*VF(IT11,ZSBI)*PC(IA)
   10 CONTINUE
      SUMB=0.0D0
      IF(NCBC.EQ.0) GO TO 35
      DO 30 IB=1,NCBC
      SUMB=SUMB+PB(IB)*SSVM(IS,IB)*SSVM(JS,IB)
   30 CONTINUE
   35 CONTINUE
      RT1=SUMS
      RT2=0.5D0*SUMT
      RT3=1.59576912D0*SUMU
      RT4=SUMB
      RETURN
      END
C-----------------------------------------------------------------------
      REAL*8 FUNCTION VF(N,X)
C-----------------------------------------------------------------------
      IMPLICIT REAL*8(A-H,O-Z),INTEGER(I-N)
      DIMENSION DFAC(16)
      DATA DFAC/ 1.0D0, 1.0D0, 2.0D0, 3.0D0, 8.0D0, 15.0D0,
     1          48.0D0, 105.0D0, 384.0D0, 945.0D0, 3840.0D0,
     2          10395.0D0, 46080.0D0, 135135.0D0, 645120.0D0,
     3          2027025.0D0/
      VF=DFAC(N)/(DSQRT(X)**(N+1))
      RETURN
      END
C-----------------------------------------------------------------------
      SUBROUTINE SHIFT(NTCB,NQN,NB,ZETA,COEF)
C-----------------------------------------------------------------------
      IMPLICIT REAL*8(A-H,O-Z),INTEGER(I-N)
      COMMON /MPOT1/ SSVM(150,15),ZETAC(40,15),COEFC(40,15),
     1               PA(6),SA(6),PC(6),SB(6),PB(15),
     &               NQNC(15),NBC(15),IFMCP,NFMCP,
     2               NA,NSTYP,NCBC,NSIM0xd,IWIT,IFLV,
     3               IV(40),IPxd1,IPxd2,IPxd3
      DIMENSION NQN(150),NB(150), ZETA(40,150),COEF(40,150)
C   Reading MCP DATA from Library
      CALL READMP
C**** PREPARATION OF SMALL S VECTOR (MATRIX) *****
c     write(6,*) 'NCBC=',NCBC
      IF(NCBC.EQ.0) GO TO 530
c     write(6,*) 'NTCB=',NTCB
      DO 500 I=1,NTCB
      NP=NQN(I)
      NBP=NB(I)
      LAMI=NQN(I)
C            LOOP ONLY OVER  PROJECTOR PART.
*      DO 500 J=NVP1,NVPC
      DO 500 JC=1,NCBC
      IF(LAMI.EQ.NQNC(JC)) GO TO 510
C            JC=1,...,NO.OF (CONTRACTED) PROJECTOR FUNCTIONS.
*      JC=J-NTCB
      SSVM(I,JC)=0.0D0
      GO TO 500
  510 NQ=NQNC(JC)
      NBQ=NBC(JC)
      SUMS=0.0D0
      DO 520 IP=1,NBP
      ZP=ZETA(IP,I)
      CP=COEF(IP,I)
      DO 520 IQ=1,NBQ
      ZQ=ZETAC(IQ,JC)
      CQ=COEFC(IQ,JC)
      ZAV=0.5D0*(ZP+ZQ)
      IT1=2*NP
      IT2=2*NQ
      RT1=1.0D0/(VF(IT1,ZP)*VF(IT2,ZQ))
      RT1=CP*CQ*DSQRT(RT1)
      IT1=NP+NQ
      RT2=VF(IT1,ZAV)
      SUMS=SUMS+RT1*RT2
  520 CONTINUE
*      JC=J-NTCB
      SSVM(I,JC)=SUMS
c     write(6,*) '>>>> IV,JC, SSVMij=',I,jc,sums
  500 CONTINUE
      RETURN
  530 CONTINUE
      STOP 'There is NO core orbitals in DATA'
      END
C-----------------------------------------------------------------------
      SUBROUTINE READMP
C-----------------------------------------------------------------------
      IMPLICIT REAL*8(A-H,O-Z),INTEGER(I-N)
      COMMON /MPOT1/ SSVM(150,15),ZETAC(40,15),COEFC(40,15),
     1               PA(6),SA(6),PC(6),SB(6),PB(15),
     &               NQNC(15),NBC(15),IFMCP,NFMCP,
     2               NA,NSTYP,NCBC,NSIM0xd,IWIT,IFLV,
     3               IV(40),IPxd1,IPxd2,IPxd3
      dimension SS(12),PP(12),NM(12)
      character*4 header,natom,ncore
      character*1 ll(5)
      data (ll(i),i=1,4),lmax /'S','P','D','F',4/
c
c     open(nfmcp,file=namef,form='formatted')
c
    1 read(nfmcp,'(a3)') header
c     write(6,'(a3)') header
c
      if (header(1:3) .eq. 'POT') then
c       read(nfmcp,'(5F14.7)') (SA(i),i=1,3),(SB(i),i=1,3)
c       read(nfmcp,'(5F14.7)') (PA(i),i=1,3),(PC(i),i=1,3)
c       write(6,   '(5F14.7)') (SA(i),i=1,3),(SB(i),i=1,3)
c       write(6,   '(5F14.7)') (PA(i),i=1,3),(PC(i),i=1,3)
        backspace(nfmcp)
        read(nfmcp,'(a3,3x,a2,i2)') header,natom,nt
        read(nfmcp,'(5F14.7)') (SS(i),i=1,nt)
        read(nfmcp,'(5F14.7)') (PP(i),i=1,nt)
        read(nfmcp,'(20I5)') (NM(i),i=1,nt)
        ia=0
        ib=0
        do i=1,nt
          if (nm(i).eq.0) then
            ia=ia+1
            SA(ia)=SS(i)
            PA(ia)=PP(i)
          else
            ib=ib+1
            SB(ib)=SS(i)
            PC(ib)=PP(i)
            endif
          enddo
c
        NA=ia
        NSTYP=ib
c
        read(nfmcp,'(a3)') header
c     write(6,'(a3)') header
c
        ic=0
   10   ic=ic+1
        read(nfmcp,'(3a4,2x,i2,2x,f13.7)',end=300) header,natom,
     &            ncore, NBC(ic),PB(ic)
c     write(6,*) 'header=, natom=, ncore=, nbc=, pb=',
c    &header,natom,ncore,nbc(ic),pb(ic)
        NQNC(ic)=0
        do l=1,lmax
        if( ncore(4:4) .eq. ll(l)) then
          NQNC(ic)=l
          endif
          enddo
        ncbc=ic
        if(NQNC(ic).eq.0) goto 900
        read(nfmcp,'(5F14.7)') (ZETAC(it,ic),it=1,NBC(ic))
        read(nfmcp,'(5F14.7)') (COEFC(it,ic),it=1,NBC(ic))
c       write(6,   '(5F14.7)') (ZETAC(it,ic),it=1,NBC(ic))
c       write(6,   '(5F14.7)') (COEFC(it,ic),it=1,NBC(ic))
        goto 10
        endif
      goto 1
  300 return
  900 stop 'CORE ORBITAL ERROR'
      end
