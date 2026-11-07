C*DECK SHMS
      SUBROUTINE SHMS(NHLF,NHST,NHWN,NHWQ,NHWCSL,NHVN,NHVQ,NHVCSL,
     *  Idummy, NL2,NL1,LSI,LRI,NL3,NL4,LSF,LRF,LST,LRT,NHT,   W)
C                                 CHECKED TASHI 10/25/89 AT HUCC
      implicit real*8 (A-H,O-Z)
      DIMENSION NHWN(12),NHWQ(12),NHWCSL(12)
      DIMENSION NHVN(12),NHVQ(12),NHVCSL(12)
      DIMENSION NHST(12),NHLF(12)
      INTEGER * 4 NL2,NL1,LSI,LRI,NL3,NL4,LSF,LRF,LST,LRT,NHT
      REAL    * 8 W,WX
      logical mshmsd
      save wmul, itest, mshmsd
**    DEBUG BY MAS
*      corrected        94-01-14   Mas & Sas
      IF(mshmsd) THEN
         CALL SHMSD (NHLF,NHST,NHWN,NHWQ,NHWCSL,NHVN,NHVQ,NHVCSL,
     *     ITEST, NL2,NL1,LSI,LRI,NL3,NL4,LSF,LRF,LST,LRT,NHT,WX)
      w = wx * wmul
      ELSE
         IF((LST*LRT.EQ.1).OR.((NL3.GT.NHT).AND.(NL4.GT.NHT))) THEN
            CALL SHMSRC(NHLF,NHST,NHWN,NHWQ,NHWCSL,NHVN,NHVQ,NHVCSL,
     *        ITEST, NL2,NL1,LSI,LRI,NL3,NL4,LSF,LRF,LST,LRT,NHT,WX)
      w = wx
         ELSE
            CALL SHMSD (NHLF,NHST,NHWN,NHWQ,NHWCSL,NHVN,NHVQ,NHVCSL,
     *        ITEST, NL2,NL1,LSI,LRI,NL3,NL4,LSF,LRF,LST,LRT,NHT,WX)
      w = wx * wmul
         END IF
      END IF
      if ( itest .ne. 0 .or. idummy .ne. 0 )
     *    write (6,*) ' shms: w,wmul=', w,wmul
      RETURN
      entry QSHMSB( WMULX )
      wmul = wmulx
      return
*
      ENTRY TSHMS( ITT )
      if ( itt .lt. 0) then
         mshmsd = .true. 
         itest = -1 - itt
      else
         mshmsd = .false.
         itest = itt
      end if
      return
*
      ENTRY TSHMSB( ITEX )
      if ( itex .gt. 0) then
         mshmsd = .true. 
      else
         mshmsd = .false.
      end if
      return
      END
