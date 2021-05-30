#!/bin/bash

cc="zig cc -Wno-unused-command-line-argument"
asm="nasm -felf64"
link="ld.lld --discard-all --strip-all --pie --entry main"

assert() {
	expected="$1"
	input="$2"

	./out/kleincc "$input" > tmp.asm
	$asm tmp.asm -o tmp.o
	# $cc tmp.o -o tmp
	$link tmp.o -o tmp
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

echo ok