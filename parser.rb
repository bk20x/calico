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
            when '('
              expr = parse(-1)
              self.advance
              expr
            when '['                        then parse_lambda
            when -> (tok){tok.length >= 2 && tok[0..1] == '@['} then parse_seq # this is kinda ehhhh, weird, but it's okay :)
            when -> (tok) { tok[0] == "'" } then Expression::String.new(token[1..-2])
            when -> (t) { is_number? t }    then Expression::Number.new(numberify token)
            when LETTERS, UPPER             then Expression::Symbol.new(token)
            else raise "Syntax Error: Unexpected token '#{token}'"
            end

      while (nxt = peek)
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

    def parse_seq
      items = []
      if peek != ']'
        loop do
          items << parse(0)
          break unless peek == ','
          self.advance
        end
      end
      self.advance
      Expression::Sequence.new(items)
    end

    def parse_lambda
      params = []
      while (nxt = peek) && nxt != ']'
        param_token = advance
        params << Expression::Symbol.new(param_token)
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
      when LETTERS, UPPER, '_'
        @pos += 1 while @pos < @buf.length && (LETTERS === @buf[@pos] || UPPER === @buf[@pos] || DIGITS === @buf[@pos] || @buf[@pos] == '_')
      when '(', ')', ',', '[', ']', '{', '}'
        @pos += 1
      else # this is for operators, variable length
        @pos += 1 while @pos < @buf.length &&
                        !(WHITESPACE.include? @buf[@pos]) &&
                        !(LETTERS === @buf[@pos] || UPPER === @buf[@pos] || DIGITS === @buf[@pos]) &&
                        !%w[( ) , $].include?(@buf[@pos])
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
context = {
  'print' => -> (*xs) {puts xs.map {|x| x.to_s}.join},
}
env = Environment::Environment.new
env.interned.merge!(context)

while true
  print "> "
  ln = gets.chomp
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
