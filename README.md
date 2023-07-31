# minrubyc-x86_64
minruby compiler for x86_64

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
