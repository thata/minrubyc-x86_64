# minrubyc for x86_64

Rubyで書かれたminrubyコンパイラ。AArch64向けに書いたminrubyコンパイラ（ https://github.com/thata/minrubyc ）をx86_64へ移植したもの。

# minrubyとは？

「RubyでつくるRuby」で作成するRubyのサブセット言語。

https://www.lambdanote.com/products/ruby-ruby

## オリジナルのminrubyとの違い

- 整数しか扱えない
- 配列はまだ未実装
- ハッシュもまだ未実装
- 関数の引数は6つまで
- セルフホストは目指さない
- その他いろいろ

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

# Run test

![image](https://github.com/thata/minrubyc-x86_64/assets/15457/b4f83c3e-dbae-4e68-8bc2-536fedf36789)

