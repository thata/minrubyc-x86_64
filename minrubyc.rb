# usage:
#   ruby minrubyc.rb <filename> > tmp.s
#   gcc -z noexecstack tmp.s libminruby.c
#   ./a.out

require "minruby"

def gen(tree)
  if tree[0] == "lit"
    puts "\tmov rax, #{tree[1]}"
  elsif %w(+ - * /).include?(tree[0])
    # R12とR13をスタックへ退避
    puts "\tpush r12"
    puts "\tpush r13"

    # 左辺を計算してR12へ結果を格納
    gen(tree[1])
    puts "\tmov r12, rax"

    # 右辺を計算してR13へ結果を格納
    gen(tree[2])
    puts "\tmov r13, rax"

    # 演算結果をRAXへ格納
    case tree[0]
    when "+"
      puts "\tadd r12, r13"
      puts "\tmov rax, r12"
    when "-"
      puts "\tsub r12, r13"
      puts "\tmov rax, r12"
    when "*"
      puts "\timul r12, r13"
      puts "\tmov rax, r12"
    when "/"
      puts "\tmov rax, r12"
      puts "\tcqo"
      puts "\tidiv r13"
    else
      raise "invalid operator: #{tree[0]}"
    end

    # R12とR13をスタックから復元
    puts "\tpop r13"
    puts "\tpop r12"
  elsif tree[0] == "func_call" && tree[1] == "p"
    gen(tree[2])

    # 評価した結果を画面へ出力
    puts "\tmov rdi, rax"
    puts "\tcall p"
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

puts "\tmov rsp, rbp"
puts "\tpop rbp"
puts "\tret"
