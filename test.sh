#!/bin/bash

assert() {
    expected="$1"
    input="$2"

    echo "$input" > tmp.rb
    ruby minrubyc.rb tmp.rb > tmp.s
    docker run --platform linux/amd64 --rm -v ${PWD}:/root -w /root gcc:latest gcc -z noexecstack tmp.s libminruby.c -o tmp
    actual=`docker run --platform linux/amd64 --rm -v ${PWD}:/root -w /root gcc:latest ./tmp`

    if [ $actual = $expected ]; then
        echo "$input => $actual"
    else
        echo "$input => $expected expected, but got $actual"
        exit 1
    fi
}

# # func_def
# assert 4649 'def hello() 4649; end; p hello()'
# assert 30 'def hello() a = 10; b = 20; a + b; end; p hello()'
# assert 120 'def hello(a) b = 20; a + b; end; p hello(100)'

# # func_call
# assert 30 'p add(10, 20)'
# assert 30 'print_int(add(10, 20))'

# # case
# assert 2 'case 42; when 0; p(0); when 1; p(1); else p(2); end'
# assert 1 'case 42; when 0; p(0); when 42; p(1); else p(2); end'

# # while
# assert 55 'i = 1; sum = 0; while i <= 10; sum = sum + i; i = i + 1; end; p(sum)'

# # if
# assert 42 'if (0 == 0); p(42); else p(43); end'
# assert 43 'if (0 == 1); p(42); else p(43); end'
# assert 41 'if (0 == 0); p(41); end'
# assert '' 'if (0 == 1); p(41); end'

# assert 4649 'p 4649'
# assert 40 'p 30 + 20 - 10'
# assert 200 'p 10 * 20'
# assert 33 'p 99 / 3'
# assert 30 'a = 10; b = 20; p a + b'

# # 真の場合は1、偽の場合は0を返す
# assert 1 'p(1 == 1)'
# assert 0 'p(1 == 2)'
# assert 0 'p(1 != 1)'
# assert 1 'p(1 != 2)'
# assert 1 'p(1 < 2)'
# assert 0 'p(1 < 1)'
# assert 1 'p(1 <= 2)'
# assert 1 'p(1 <= 1)'
# assert 0 'p(1 <= 0)'
# assert 1 'p(2 > 1)'
# assert 0 'p(1 > 1)'
# assert 1 'p(2 >= 1)'
# assert 1 'p(1 >= 1)'
# assert 0 'p(0 >= 1)'

assert 33 'p 99 / 3'
assert 200 'p 10 * 20'
assert 40 'p 30 + 20 - 10'
assert 60 'p 10 + 20 + 30'
assert 4649 'p 4649'

echo OK
