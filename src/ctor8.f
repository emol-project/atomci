      subroutine ctor8( char, r8 )
      character * 8 buff
      character * (*) char
      real * 8 r8
      buff = char
      read ( buff, '(a8)') r8
      return
      end
