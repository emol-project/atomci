      subroutine ctoi4( char, int )
      character * 4 buff
      character * (*) char
      integer * 4   int
      buff = char
      read ( buff, '(a4)') int
      return
      end
