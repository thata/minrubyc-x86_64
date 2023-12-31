# usage:
#   ruby minrubyc.rb <filename> > tmp.s
#   gcc -z noexecstack tmp.s libminruby.c
#   ./a.out

require "minruby"

# 関数の引数で利用するレジスタ
# see: https://zenn.dev/ri5255/scraps/66a32c17cc515d
PARAM_REGISTERS = %w(rdi rsi rdx rcx r8 r9)

# tree 内の変数名一覧
def var_names(arr, tree)
  if tree[0] == "var_assign"
    arr.include?(tree[1]) ? arr : arr + [tree[1]]
  elsif tree[0] == "stmts"
    tmp_arr = arr
    tree[1..].each do |statement|
      tmp_arr = tmp_arr + var_names(tmp_arr, statement)
    end
    tmp_arr
  else
    arr
  end
end

def func_defs(hash, tree)
  if tree[0] == "func_def"
    hash.merge({
      # 関数名をキーにして [関数名, 引数, 関数本体] を格納
      tree[1] => tree[1..]
    })
  elsif tree[0] == "stmts"
    tree[1..].reduce(hash) do |acc, statement|
      func_defs(acc, statement)
    end
  else
    hash
  end
end

# スタックフレーム上の変数のアドレスをベースポインタ（RBP）からのオフセットとして返す
# 例：
#   ひとつ目の変数のアドレス = ベースポインタ(RBP) - 8
#   ふたつ目の変数のアドレス = ベースポインタ(RBP) - 16
#   ふたつ目の変数のアドレス = ベースポインタ(RBP) - 24
#   ...
def var_offset(var, env)
  # 変数1つにつき8バイトの領域が必要
  (env.index(var) + 1) * -8
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
    gen(tree[2], env)
    offset = var_offset(tree[1], env)
    puts "\tmov [rbp+(#{offset})], rax"
  elsif tree[0] == "var_ref"
    offset = var_offset(tree[1], env)
    puts "\tmov rax, [rbp+(#{offset})]"
  elsif tree[0] == "func_call"
    args = tree[2..]

    # 引数が6個以上の場合はエラー
    raise "too many arguments (given #{args.size}, expected 6)" if args.size > 6

    # 引数を評価した結果をスタックへ退避
    args.reverse.each do |arg|
      gen(arg, env)
      puts "\tpush rax"
    end

    # 退避した引数の評価値を引数レジスタへ格納
    args.each_with_index do |_, i|
      puts "\tpop #{PARAM_REGISTERS[i]}"
    end

    # 関数を呼び出す
    puts "\tcall #{tree[1]}"
  elsif tree[0] == "func_def"
    # ここでは何もしない
  elsif tree[0] == "stmts"
    tree[1..].each do |statement|
      gen(statement, env)
    end
  elsif tree[0] == "if"
    # 条件式を評価
    gen(tree[1], env)
    # 真の場合は tree[2] を評価
    puts "\tcmp rax, 0"
    puts "\tje .Lelse#{tree.object_id}"
    gen(tree[2], env)
    puts "\tjmp .Lend#{tree.object_id}"
    puts ".Lelse#{tree.object_id}:"
    # 偽の場合は tree[3] を評価
    gen(tree[3], env) if tree[3]
    puts ".Lend#{tree.object_id}:"
  elsif tree[0] == "while"
    puts ".L_while_begin#{tree.object_id}:"
    # 条件式を評価
    gen(tree[1], env)
    # 真でなければループを抜ける
    puts "\tcmp rax, 0"
    puts "\tje .L_while_end#{tree.object_id}"
    # ループ本体を評価
    gen(tree[2], env)
    # ループの先頭へジャンプ
    puts "\tjmp .L_while_begin#{tree.object_id}"
    puts ".L_while_end#{tree.object_id}:"
  else
    raise "invalid AST: #{tree}"
  end
end

tree = minruby_parse(ARGF.read)
env = var_names([], tree)
func_defs = func_defs({}, tree)

puts "\t.intel_syntax noprefix"
puts "\t.text"

# ユーザー定義関数
func_defs.values.each do |func_def|
  name, args, body = func_def
  env = var_names(args, body)

  puts "\t.globl #{name}"
  puts "#{name}:"
  puts "\tpush rbp"
  puts "\tmov rbp, rsp"

  # ローカル変数用の領域をスタック上へ確保
  puts "\tsub rsp, #{env.size * 8}"

  # 引数をスタックへ退避
  args.each_with_index do |arg, i|
    offset = var_offset(arg, env)
    puts "\tmov [rbp+(#{offset})], #{PARAM_REGISTERS[i]}"
  end

  puts "\t# body start: #{body}"
  gen(body, env)
  puts "\t# body end"

  # スタック上に確保したローカル変数用の領域を開放
  puts "\tadd rsp, #{env.size * 8}"

  puts "\tmov rsp, rbp"
  puts "\tpop rbp"
  puts "\tret"
end

# メイン関数
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
