# usage:
#   ruby minrubyc.rb <filename> > tmp.s
#   gcc -z noexecstack tmp.s libminruby.c
#   ./a.out

require "minruby"

def gen(tree)
  if tree[0] == "lit"
    puts "\tmov rax, #{tree[1]}"
  elsif tree[0] == "+"
    # R12を退避
    puts "\tpush r12"
    puts "\tpush r13"

    # 左辺を計算してR12に結果を入れる
    gen(tree[1])
    puts "\tmov r12, rax"

    # 右辺を計算してR13に結果を入れる
    gen(tree[2])
    puts "\tmov r13, rax"

    # R12 + R13の結果をRAXに入れる
    puts "\tadd rax, r12"
  else
    raise "invalid AST: #{tree}"
  end
end

tree = minruby_parse(ARGF.read)

puts "\t.intel_syntax noprefix"
puts "\t.text"
puts "\t.globl main"
puts "main:"
puts "\tpush rbp"
puts "\tmov rbp, rsp"

gen(tree)

# 評価した結果を画面へ出力
puts "\tmov rdi, rax"
puts "\tcall p"

puts "\tmov rsp, rbp"
puts "\tpop rbp"
puts "\tret"
