# usage:
#   ruby minrubyc.rb <filename> > tmp.s
#   gcc -z noexecstack tmp.s libminruby.c
#   ./a.out

require "minruby"

# tree 内の変数名一覧
def var_names(arr, tree)
  if tree[0] == "var_assign"
    arr + [tree[1]]
  elsif tree[0] == "stmts"
    tree[1..].flat_map do |statement|
      var_names(arr, statement)
    end
  else
    arr
  end
end

# スタックフレーム上の変数のアドレスをベースポインタ（RBP）からのオフセットとして返す
# 例：
#   ひとつ目の変数のアドレス = ベースポインタ(RBP) - 0
#   ふたつ目の変数のアドレス = ベースポインタ(RBP) - 8
#   ふたつ目の変数のアドレス = ベースポインタ(RBP) - 16
#   ...
def var_offset(var, env)
  # 変数1つにつき8バイトの領域が必要
  env.index(var) * -8
end

def gen(tree, env)
  if tree[0] == "lit"
    puts "\tmov rax, #{tree[1]}"
  elsif %w(+ - * / == != < <= > >=).include?(tree[0])
    # R12とR13をスタックへ退避
    puts "\tpush r12"
    puts "\tpush r13"

    # 左辺を計算してR12へ結果を格納
    gen(tree[1], env)
    puts "\tmov r12, rax"

    # 右辺を計算してR13へ結果を格納
    gen(tree[2], env)
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
    when "=="
      puts "\tcmp r12, r13"
      puts "\tsete al"
      puts "\tmovzb rax, al"
    when "!="
      puts "\tcmp r12, r13"
      puts "\tsetne al"
      puts "\tmovzb rax, al"
    when "<"
      puts "\tcmp r12, r13"
      puts "\tsetl al"
      puts "\tmovzb rax, al"
    when "<="
      puts "\tcmp r12, r13"
      puts "\tsetle al"
      puts "\tmovzb rax, al"
    when ">"
      puts "\tcmp r12, r13"
      puts "\tsetg al"
      puts "\tmovzb rax, al"
    when ">="
      puts "\tcmp r12, r13"
      puts "\tsetge al"
      puts "\tmovzb rax, al"
    else
      raise "invalid operator: #{tree[0]}"
    end

    # R12とR13をスタックから復元
    puts "\tpop r13"
    puts "\tpop r12"
  elsif tree[0] == "var_assign"
    puts "\t// var_assign: #{tree[1]}(#{var_offset(tree[1], env)})"
    gen(tree[2], env)
    offset = var_offset(tree[1], env)
    puts "\tmov [rbp+(#{offset})], rax"
  elsif tree[0] == "var_ref"
    puts "\t// var_ref: #{tree[1]}(#{var_offset(tree[1], env)})"
    offset = var_offset(tree[1], env)
    puts "\tmov rax, [rbp+(#{offset})]"
  elsif tree[0] == "func_call" && tree[1] == "p"
    gen(tree[2], env)

    # 評価した結果を画面へ出力
    puts "\tmov rdi, rax"
    puts "\tcall p"
  elsif tree[0] == "stmts"
    tree[1..].each do |statement|
      gen(statement, env)
    end
  else
    raise "invalid AST: #{tree}"
  end
end

tree = minruby_parse(ARGF.read)
env = var_names([], tree)

puts "\t.intel_syntax noprefix"
puts "\t.text"
puts "\t.globl main"
puts "main:"
puts "\tpush rbp"
puts "\tmov rbp, rsp"

# ローカル変数用の領域をスタック上へ確保
puts "\tsub rsp, #{env.size * 8}"

gen(tree, env)

# スタック上に確保したローカル変数用の領域を開放
puts "\tadd rsp, #{env.size * 8}"

puts "\tmov rsp, rbp"
puts "\tpop rbp"
puts "\tret"
