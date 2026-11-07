C*DECK SETIAD
      SUBROUTINE SETIAD(NWTX,NWTHX,ISSHX,IDPRNT,NWSQX,  LMAXX)
C     formally FUNCTION ISQTQ(NWT,NWTH,IGCD,ISCD,LISL,ISSH,IDPRNT,NWSQ)
C*KGN CHANGE BASIS SET SIZE
      PARAMETER (KBASIS=150)
C
      DIMENSION NWTHX(*),ISSHX(*),NWSQX(*),NWLFX(*)
C     copy generated
C
      DIMENSION ISSH(20),NWSQ(KBASIS)
C
C     locally generated  SAS 94-01-16
      DIMENSION ITAD(20),IOEAD(20),NWLF(KBASIS)
      logical iaddr
      include 'include/COMSTR'
C
      save nwt, lmax, iprnt, issh, nwsq, itad, ioead, nwlf
C
      DATA IPRNT/0/
C
      iaddr = .true.
      go to 7777
C                    addressing method is iad-type for ciex
C                    kad-type is for mcscf
C
      entry  SETKAD(NWTX,NWLFX,ISSHX,IDPRNT,NWSQX,  LMAXX)
C     
      iaddr=.false.
 7777 continue
C
      
C     LISL = 2048
      nwt = nwtx
      if (nwt .gt. KBASIS) then
         write (6,*) ' nwt is larger than the reserved size KBASIS:',nwt
         write (6,*) ' subroutine SETIAD should be recompiled'
         stop
         end if
      if (lmax .gt. 20) then
         write (6,*) ' lmax is larger than the reserved size 20:',nwt
         write (6,*) ' subroutine SETIAD should be recompiled'
         stop
         end if
      do 1231 i=1,nwt
         if (iaddr) then
            nwlf(i)=ilfo(nwthx(i))/2+1
         else
            nwlf(i)=nwlfx(i)
         end if
         nwsq(i)=nwsqx(i)
 1231    continue
      DO 123 I=1,20
  123 ISSH(I)=0
      LMAX=0
      NSQFG=NWSQ(1)
      DO 124 I=1,NWT
      K=NWLF(I)
      LMAX=MAX0(K,LMAX)
      ISSH(K)=ISSH(K)+1
      IF(NSQFG.EQ.0) NWSQ(I)=ISSH(K)
  124 CONTINUE
C     WRITE(6,9008)
C     WRITE(6,9009) (I,NWTH(I),NWSQ(I),I=1,NWT)
C9008 FORMAT(/' SHELL NUMBERS',/)
C9009 FORMAT(5X,5(I4,1X,Z4,I3,2X))
C
      ITAD(1)=0
      IOEAD(1)=0
      IF(LMAX.EQ.1) GO TO 132
      DO 122 I=2,LMAX
      IOEAD(I)=IOEAD(I-1)+(ISSH(I-1)*(ISSH(I-1)+1))/2
  122 ITAD(I)=(LMAX-I+2)*(  I-1)+ITAD(I-1)
  132 KMAX=2*LMAX-1
      if (iaddr) then
         IGTAD=IOEAD(LMAX)+(ISSH(LMAX)*(ISSH(LMAX)+1))/2
      else
         IGTAD = 0
      end if
*debug
*     write(6,*) nwlf(1),nwlf(nwt) 
      IF(IDPRNT.GT.0) WRITE(6,9998)
 9998 FORMAT('0     KM     LN1  LN2  LN3  LN4    IDIMA    IDIMB'
     1   ,'    IGTAD'/)
      LISLU=0
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
      LISLU=MAX0(IAD,LISLU)
      IF(IAD.GT.LISL) IAD=LISL
      ISCD(IAD)=ISAD
      IDIMA=ISSH(LN1)*ISSH(LN2)
      IF(IDA.EQ.1) IDIMA=(ISSH(LN1)*(ISSH(LN1)+1))/2
      ISAD=ISAD+IDIMA
      IGCD(IAD)=IGTAD
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
      IGTAD=IGTAD+IDIM
      IF(IDPRNT.NE.0) WRITE(6,9999) KM,LN1,LN2,LN3,LN4,IDIMA,IDIMB,IGTAD
 9999 FORMAT(2I8,3I5,3I9)
  195 CONTINUE
  194 CONTINUE
  193 CONTINUE
  192 CONTINUE
  191 CONTINUE
C      WRITE(6,9004)  LISL,LISLU
 9004 FORMAT(/'  RESERVED:  LISL =',I7,'      ACTUALLY USED:',I7)
      LMAXX=lmax
      do 200 i=1,lmax
  200    isshx(i)=issh(i)
      if (LISLU .gt. LISL) then
         write (6,*) ' LISLU is larger than the reserved size LISL:',
     *             iadmax
         write (6,*) ' subroutine SETIAD should be recompiled'
         stop
         end if
      iprnt=0
      RETURN
C
      ENTRY tintad(ITT)
C     ENTRY ISQTP(ITT)
      IPRNT=itt
      RETURN
C
      ENTRY int1ad(M1,M2, intadr)
      L=NWLF(M1)
      I1=NWSQ(M1)
      I2=NWSQ(M2)
      IA=MIN0(I1,I2)
      IB=MAX0(I1,I2)
      intadr=IOEAD(L)+(IB*(IB-1))/2+IA
      IF(IPRNT.GT.0) WRITE(6,9003) M1,M2 ,intadr
 9003 FORMAT('  ISQIJ    ',2I5,I10)
      RETURN
C
      ENTRY int2ad(KXX,M1,M2,M3,M4,  intadr)
      K=KXX/2+1
      I1=M1
      I2=M2
      I3=M3
      I4=M4
   4  L1=NWLF(I1)
      L2=NWLF(I2)
      L3=NWLF(I3)
      L4=NWLF(I4)
      IDA=IABS(L1-L2)+1
      IDB=IABS(L3-L4)+1
      ITA=L1+L2-1
      ITB=L3+L4-1
      IF(IDA.GT.IDB.OR.(IDA.EQ.IDB.AND.ITA.GE.ITB)) GO TO 1
      IT=I3
      I3=I1
      I1=IT
      IT=I2
      I2=I4
      I4=IT
      GO TO 4
    1 IDIMA=ISSH(L2)*ISSH(L1)
      IF(L1-L2) 11,12,13
   11 IDIA=ISSH(L2)*(NWSQ(I1)-1)+NWSQ(I2)
      L12L=L1
      GO TO 2
   12 KT=MAX0(NWSQ(I1),NWSQ(I2))
      L12L=L1
      IDIA=(KT*(KT-1))/2+MIN0(NWSQ(I1),NWSQ(I2))
      IDIMA=(ISSH(L1)*(ISSH(L1)+1))/2
      GO TO 2
   13 IDIA=ISSH(L1)*(NWSQ(I2)-1)+NWSQ(I1)
      L12L=L2
    2 CONTINUE
      IDIMB= ISSH(L3)* ISSH(L4)
      IF(L3-L4) 21,22,23
   21 IDIB=ISSH(L4)*(NWSQ(I3)-1)+NWSQ(I4)
      L34L=L3
      GO TO 3
   22 KT=MAX0(NWSQ(I3),NWSQ(I4))
      L34L=L3
      IDIB=(KT*(KT-1))/2+MIN0(NWSQ(I3),NWSQ(I4))
      IDIMB=(ISSH(L3)*(ISSH(L3)+1))/2
      GO TO 3
   23 IDIB=ISSH(L3)*(NWSQ(I4)-1)+NWSQ(I3)
      L34L=L4
    3 CONTINUE
      IF(IDA.EQ.IDB.AND.ITA.EQ.ITB) GO TO 31
      IDTA=(IDIA-1)*IDIMB+IDIB
      GO TO 32
   31 KT=MAX0(IDIA,IDIB)
      IDTA=(KT*(KT-1))/2+MIN0(IDIA,IDIB)
   32 KT=(ITA-K)/2
      IADA=ITAD(L12L)+KT*(LMAX-L12L+1)+IDA
      KT=(ITB-K)/2
      IADB=ITAD(L34L)+KT*(LMAX-L34L+1)+IDB
      intadr=IGCD(IADA)+ISCD(IADB)*IDIMA+IDTA
      IF(IPRNT.GT.1) WRITE(6,9002) K,M1,M2,M3,M4,intadr
 9002 FORMAT(' ISQTE    ',I5,4X,I5,3I5,I10)
      RETURN
      END
