# minrubyc-x86_64
minruby compiler for x86_64

AArch64で書いたminrubyコンパイラ（ https://github.com/thata/minrubyc ）をx86_64へ移植した。

# Usage

事前に `minruby` gem をインストールしておく

```sh
gem install minruby
```

minrubyコンパイラで `sample/fib.rb` をコンパイルしてx86_64アセンブリファイルを出力、

```sh
ruby minrubyc.rb sample/fib.rb > tmp.s
```

出力したx86_64アセンブリをDocker環境上でビルド&実行する。`fib(10)`の結果である`55`が返ればOK

```sh
$ docker run --platform linux/amd64 -it -v `pwd`:/root -w /root ruby:latest bash
（Docker環境に入って）
# gcc -z noexecstack tmp.s libminruby.c -o fib
# ./fib
55
```

## sample/fib.rb

```ruby
def fib(n)
  if n < 2
    n
  else
    fib(n - 1) + fib(n - 2)
  end
end
p fib(10)
```
