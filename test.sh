#!/bin/bash

assert() {
	expected="$1"
	input="$2"

	./out/kleincc "$input" > tmp.s
	clang -o tmp tmp.s
	./tmp
	actual="$?"

	if [ "$actual" = "$expected" ]; then
		echo "$input => $actual"
	else
		echo "$input => $expected expected, but got $actual"
		exit 1
	fi
}

assert 7 7
assert 45 45

echo ok