require_relative 'expression'

module Parser
  DIGITS       = '0'..'9'
  LETTERS      = 'a'..'z'
  UPPER        = 'A'..'Z'
  WHITESPACE   = [" ", "\t", "\n", "\r"]
  STRING_START = "'"

  class Parser
    def initialize(buf)
      @buf = buf
      @pos = 0
    end


    def peek
      old_pos = @pos
      token = advance
      @pos = old_pos
      token
    end

    def parse(precedence = -1)
      token = self.advance
      return nil if token.nil?

      lhs = case token
            when 'for' then parse_for_in
            when 'if'  then parse_if_else
            when 'use' then parse_use
            when 'do'  then self.advance; parse_block(:return_result => true) # since regular block expressions return their environment
            when '('  then expr = parse(-1); self.advance; expr
            when '['  then parse_lambda
            when '{'  then parse_block
            when '@[' then parse_seq
            when -> (tok) { tok[0] == "'" } then Expression::String.new(token[1..-2])
            when -> (t) { is_number? t }    then Expression::Number.new(numberify token)
            when LETTERS, UPPER             then Expression::Symbol.new(token)
            else raise "Syntax Error: Unexpected token '#{token}'"
            end

      while (nxt = peek)
        if nxt == '.'
          self.advance
          property = self.advance
          lhs = Expression::DotAccess.new(lhs, Expression::Symbol.new(property))
          next
        end
        if nxt == '('
          self.advance
          lhs = parse_call(lhs)
          next
        end
        next_prec = precedence_of(nxt)
        if next_prec && next_prec > precedence
          operator = self.advance
          rhs = parse(next_prec)
          lhs = Expression::BinaryExpression.new(lhs, operator, rhs)
          next
        end
        break
      end
      lhs
    end

    def parse_use
      env = parse(0)
      if peek == 'in'
        advance
        unless advance == '{'
          raise "Syntax Error: Expected '{' for use body"
        end
        body_node = parse_block(:return_result => true)
        Expression::UseInExpression.new(env, body_node)
      else
        Expression::UseExpression.new(env)
      end
    end


    def parse_seq
      elements = []
      while (nxt = peek) && nxt != ']'
        elements << parse(-1)
        advance if peek == ','
      end
      unless advance == ']'
        raise "Syntax Error: Expected ']' to close sequence"
      end
      Expression::Sequence.new(elements)
    end

    def parse_if_else
      cond = parse

      unless advance == '{'
        raise "Syntax Error: Expected '{' after if condition"
      end
      body_node = parse_block(:return_result => true)

      elt = nil
      if peek == 'else'
        advance
        if peek == 'if'
          advance
          elt = parse_if_else
        elsif peek == '{'
          advance
          elt = parse_block(:return_result => true)
        else
          raise "Syntax Error: Expected '{' or 'if' after else"
        end
      end
      Expression::IfElse.new(cond, body_node, elt)
    end

    def parse_for_in
      var_token = advance
      iterator_var = Expression::Symbol.new(var_token)
      unless advance == 'in'
        raise "Syntax Error: Expected 'in' after for variable"
      end
      collection = parse(0) # this will support ranges later when added
      unless advance == '{'
        raise "Syntax Error: Expected '{' for loop body"
      end
      body_node = parse_block
      Expression::ForIn.new(collection,[iterator_var], body_node.body)
    end

    def parse_lambda
      params = []
      while (nxt = peek) && nxt != ']'
        token = advance
        if token == '*'
          vararg_name_token = advance
          if vararg_name_token.nil? || vararg_name_token == ']'
            raise "Syntax Error: Expected parameter name after '*'"
          end
          params << Expression::Vararg.new(vararg_name_token)
          if peek != ']'
            raise "Syntax Error: Vararg '*#{vararg_name_token}' must be the last parameter"
          end
        else
          params << Expression::Symbol.new(token)
        end
      end
      unless advance == ']'
        raise "Syntax Error: Expected ']' to close lambda parameters"
      end
      unless advance == '{'
        raise "Syntax Error: Expected '{' for lambda body"
      end
      body_expressions = []
      while (nxt = peek) && nxt != '}'
        expr = parse(-1)
        body_expressions << expr if expr
      end
      unless advance == '}'
        raise "Syntax Error: Missing closing '}' for lambda body"
      end
      Expression::Lambda.new(params, body_expressions, nil)
    end


    def parse_call(func)
      args = []
      if peek != ')'
        loop do
          args << parse(0)
          break unless peek == ','
          self.advance
        end
      end
      self.advance
      Expression::Call.new(func, args)
    end

    def parse_block(return_result = false)
      body_expressions = []
      while (nxt = peek) && nxt != '}'
        expr = parse(-1)
        body_expressions << expr if expr
      end
      unless advance == '}'
        raise "Syntax Error: Missing closing '}' for block body"
      end
      Expression::Block.new(body_expressions, return_result)
    end

    def precedence_of(token)
      Expression::OPERATOR_PRECEDENCES[token]
    end

    def advance
      skip_whitespace
      return nil if @pos >= @buf.length
      start = @pos
      char  = @buf[@pos]

      case char
      when STRING_START
        @pos += 1
        @pos += 1 while @pos < @buf.length && @buf[@pos] != "'"
        @pos += 1
        return @buf[start...@pos]
      when DIGITS
        @pos += 1 while @pos < @buf.length && (DIGITS === @buf[@pos] || @buf[@pos] == '.')
      when LETTERS, UPPER, '_', '?', '-'
        @pos += 1 while @pos < @buf.length && (LETTERS === @buf[@pos] || UPPER === @buf[@pos] || DIGITS === @buf[@pos] || @buf[@pos] == '_' || @buf[@pos] == '?' || @buf[@pos] == '-')
      when '(', ')', ',', '[', ']', '{', '}'
        @pos += 1
      when '@'
        if @buf[@pos + 1] == '['
          @pos += 2
          return "@["
        else
          @pos += 1 while @pos < @buf.length &&
                          !(WHITESPACE.include? @buf[@pos]) &&
                          !(LETTERS === @buf[@pos] || UPPER === @buf[@pos] || DIGITS === @buf[@pos]) &&
                          !%w|( ) , [ ] { }|.include?(@buf[@pos])
        end
      else
        @pos += 1 while @pos < @buf.length &&
                        !(WHITESPACE.include? @buf[@pos]) &&
                        !(LETTERS === @buf[@pos] || UPPER === @buf[@pos] || DIGITS === @buf[@pos]) &&
                        !%w|( ) , [ ] { }|.include?(@buf[@pos])
      end
      @buf[start...@pos]
    end


    private
    def skip_whitespace
      @pos += 1 while @pos < @buf.length && WHITESPACE.include?(@buf[@pos])
    end

    def is_number?(token)
      !!Float(token, exception: false)
    end

    def numberify(token)
      result = Float(token)
      result % 1 == 0 ? result.to_i : result
    end
  end
end


def do_file(path, env)
  unless File.exist?(path)
    puts "Error: File not found: #{path}"
    return
  end

  content = File.read(path)
  parser  = Parser::Parser.new(content)

  begin
    while (tree = parser.parse)
      result = if tree.is_a?(Expression::Lambda)
                 tree
               else
                 tree.eval(env)
               end
    end
  rescue Exception => e
    puts "Error in #{path}: #{e.message}"
  end
end

require_relative 'environment'
require 'socket'
context = {
  'print' => -> (*xs) {puts xs.map {|x| x.to_s}.join},
  'image' => -> (obj) {obj.to_s},
  'gets'  => -> ()  {gets},
  'find-class' => ->(name){Object.const_get(name)},
}
env = Environment::Environment.new
env.interned.merge!(context)
while true
  print "> "
  ln = gets.chomp
  if ln.start_with? '#load'
    do_file(ln.split(' ')[1], env)
    next
  end
  next if ln.strip.empty?
  begin
    p = Parser::Parser.new(ln)
    while (tree = p.parse)

      result = if tree.instance_of? Expression::Lambda
                 tree
               else tree.eval(env)

               end
      output = if result.nil? then 'NIL' else result.to_s end
      puts "=> #{output}"
    end
  rescue Exception => e
    puts "Error!: #{e.message}"
  end
end
