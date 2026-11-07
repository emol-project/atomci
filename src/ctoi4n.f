      subroutine ctoi4n( char, int, n )
      character * 80 buff
      character * (*) char
      integer * 4   int(n)
      buff = char
      read ( buff, '(20a4)') (int(i), i=1,n)
      return
      end
