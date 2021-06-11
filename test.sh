#!/bin/bash

cc="zig cc -Wno-unused-command-line-argument"
asm="nasm -felf64"
link="ld.lld --discard-all --strip-all --pie --entry main"

# cat <<EOF |
clang -xc -c -o tmp2.o - << EOF
int ret3() { return 3; }
int ret5() { return 5; }
int ret19() { return 19; }
int add(int x, int y) { return x+y; }
int sub(int x, int y) { return x-y; }
int mul(int x, int y) { return x*y; }

int add6(int a, int b, int c, int d, int e, int f) {
  return a+b+c+d+e+f;
}
EOF

assert() {
	expected="$1"
	input="$2"

	./out/kleincc "$input" > tmp.asm
	$asm tmp.asm -o tmp.o
	# $cc tmp.o -o tmp
	$link tmp.o tmp2.o -o tmp
	./tmp
	actual="$?"

	if [ "$actual" = "$expected" ]; then
		echo "$input => $actual"
	else
		echo "$input => $expected expected, but got $actual"
		exit 1
	fi
}

assert 7 'return 7;'
assert 45 'return 45;'
assert 5 'return 3-4+7-1;'
assert 41 ' return  12 + 34 - 5 ;'
assert 11 ' return 34 - 7-16; '
assert 35  'return  19 + 8 *2;'
assert 220 'return 20 * (5 + 6);'
assert 4   'return (3  +5)/2;'
assert 92 'return 2 *(5+ 6 * 8 - 7);'
assert 10 'return - - +10;'
assert 14 'return 10 -- +4;'

assert 0 '  return   0==1;'
assert 1 'return 42==42;'
assert 1 'return 0!=1;'
assert 0 'return 42!=42;'

assert 1 '  return 0<1;'
assert 0 'return 1<1;'
assert 0 ' return 2<1;'
assert 1 ' return 0<=1;'
assert 1 'return 1<=1;'
assert 0 'return 2<=1;'

assert 1 'return 1>0;'
assert 0 'return 1>1;'
assert 0 'return 1>2;'
assert 1 'return 1>=0;'
assert 1 'return 1>=1;'
assert 0 'return 1>=2;'

assert 1 'return 30 < (24 + 9);'
assert 1 'return 37 == (18 + 20 - 1);'
assert 0 'return 90 <= (+73 - 22 - 50);'
assert 0 'return 42 == (-33 + 51 - 4) ;'
assert 0 'return (19 + 27) > (+28 --18); '
assert 0 'return (33- 44 +++55) > (70-90+130); '
assert 1 'return ((1+2+3+4) - (4+3+2+1)) == 0;'
assert 1 'return ++3- 4 + 5 > 1 + 1 -+2 ;'
assert 1 'return 29- (4 + 2) + (5 -- 3) > 1 + 1 -+2;'
assert 1 'return 29++- (2 - 7 + 9) -   (12 -- 3) > 1 + 1 -+2  ;'

assert 1 'return 1; 2; 3;'
assert 2 'return 11 - 9; 25; +6-7; 1+3+8-5;'

assert 20 'return 20; 3; 9 + 12;'
assert 7 '12 -+5; return 3 + 4;'

assert 3 ' a= 3; return a;'
assert 22 ' a = 31; b = 9; return a- b;'

assert 17 ' foo =  4 + 13; return foo;'
assert 20 'bar33 = 4; bar = 16; return bar+bar33;'
assert 11 'foo = 24; bar = 13; return foo- bar;'

assert 3 'if (0) return 2; return 3;'
assert 3 'if (1-1) return 2; return 3;'
assert 2 'if (1) return 2; return 3;'
assert 2 'if (2-1) return 2; return 3;'
assert 11 ' if (3+4 *9) return 5+6; else return 32;'
assert 12 ' 22+ -11; if (5-5) return 6; else return 7+9-4;'

assert 10 'i=0; while(i<10) i=i+1; return i;'
assert 19 'i = 1; while (i + 1 < 10+9) i = 1 + i; return i+1;'

assert 3 'for (;;) return 3; return 5;'
assert 55 'i=0; j=0; for (i=0; i<=10; i=i+1) j=i+j; return j;'
assert 82 'i = 11; j = i-9; for(; j < 10; j=j+9) i = i + 71; return i ;'

assert 3 '{1; {2;} return 3;}'
assert 55 'i=0; j=0; while(i<=10) {j=i+j; i=i+1;} return j;'
assert 0 'a=0; b=1; while (a+b > 0) {a = a - 1;} return 0;'

assert 3 'return ret3();'
assert 5 'return ret5();'
assert 90 'i = 089; i = i + 1; return i; return ret19();'
assert 8 'return add(3, 5);'
assert 2 'return sub(5, 3);'
assert 27 'return mul(3+4+5-1-2, 2+1);'
assert 21 'return add6(1,2,3,4,5,6);'

echo ok
