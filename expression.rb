require_relative 'environment'
module Expression
  OP_ADD    = '+'
  OP_SUB    = '-'
  OP_MUL    = '*'
  OP_DIV    = '/'
  OP_GTHAN  = '>'
  OP_LTHAN  = '<'
  OP_EQ     = '='
  OP_BIND   = '<-'

  OPERATOR_PRECEDENCES = {
    OP_BIND  => 0,
    OP_EQ    => 1,
    OP_GTHAN => 1,
    OP_LTHAN => 1,
    OP_SUB   => 2,
    OP_ADD   => 2,
    OP_DIV   => 3,
    OP_MUL   => 3
  }

  class Expression
    def eval(env)
    end
  end

  class Number < Expression
    def initialize(value)
      @value = value
    end

    def eval(env)
      @value
    end
  end

  class BinaryExpression < Expression
    attr_reader :lexpr, :op, :rexpr

    def initialize(lexpr, op, rexpr)
      @lexpr = lexpr
      @op    = op
      @rexpr = rexpr
    end

    def eval(env)
      if @op == OP_BIND
        unless @lexpr.instance_of? Symbol
          raise "Left hand side of bind, `<-` must be a symbol"
        end
        binding_name = @lexpr.name
        val          = @rexpr.eval(env)
        env.intern(binding_name, val)
      else
        left  = @lexpr.eval(env)
        right = @rexpr.eval(env)
        case @op
          when OP_ADD   then left + right
          when OP_SUB   then left - right
          when OP_MUL   then left * right
          when OP_DIV   then left / right.to_f
          when OP_GTHAN then left > right
          when OP_LTHAN then left < right
          when OP_EQ    then left == right
          else raise "Invalid operator in binary expression: #{@op}"
        end
      end
    end
  end

  class Symbol < Expression
    attr_reader :name
    def initialize(name)
      @name = name
    end

    def eval(env)
      env.lookup(@name)
    end
  end

  class String < Expression
    def initialize(val)
      @str_val = val
    end

    def eval(env)
      @str_val
    end
  end


  class Lambda < Expression
    attr_reader :params, :body, :closure

    def initialize(params, body, env = nil)
      @params  = params
      @body    = body
      @closure = env # This is nil until eval is called, so pretty much never because a lambda is evaluated on binding
    end
    def eval(env)
      Lambda.new(@params, @body, env)
    end
  end



  class Call < Expression
    def initialize(name, args)
      @func = name
      @args = args
    end
    def eval(env)
      func = @func.eval(env)
      if func.instance_of? Lambda
        instance_env = Environment::Environment.new(parent: func.closure || env)
        func.params.each_with_index do |param, i|
          instance_env.intern(param.name, @args[i].eval(env))
        end
        result = nil
        func.body.each { |expr| result = expr.eval(instance_env) }
        result
      elsif func.respond_to?(:call)
        func.call(*@args.map { |a| a.eval(env) })
      end
    end
  end


  class Block < Expression
    def initialize(body)
      @body = body
    end
    def eval(env)
      result = nil
      @body.each do |form|
        result = form.eval(env)
      end
      result
    end
  end
end
