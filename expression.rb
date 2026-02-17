require_relative 'environment'
module Expression
  OP_ADD     = '+'
  OP_SUB     = '-'
  OP_MUL     = '*'
  OP_DIV     = '/'
  OP_GTHAN   = '>'
  OP_GTHANEQ = '>='
  OP_LTHAN   = '<'
  OP_LTHANEQ = '<='
  OP_EQ      = '='
  OP_BIND    = '<-'
  COMPARATOR_PRECEDENCE = 1
  OPERATOR_PRECEDENCES = {
    OP_BIND    => 0,
    OP_EQ      => COMPARATOR_PRECEDENCE,
    OP_GTHAN   => COMPARATOR_PRECEDENCE,
    OP_GTHANEQ => COMPARATOR_PRECEDENCE,
    OP_LTHAN   => COMPARATOR_PRECEDENCE,
    OP_LTHANEQ => COMPARATOR_PRECEDENCE,
    OP_SUB     => 2,
    OP_ADD     => 2,
    OP_DIV     => 3,
    OP_MUL     => 3
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

    def to_s
      @value.to_s
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
          when OP_ADD     then left + right
          when OP_SUB     then left - right
          when OP_MUL     then left * right
          when OP_DIV     then left / right.to_f
          when OP_GTHAN   then left > right
          when OP_GTHANEQ then left >= right
          when OP_LTHAN   then left < right
          when OP_LTHANEQ then left <= right
          when OP_EQ      then left == right
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

  class DotAccess < Expression
    def initialize(target, field)
        @target = target
        @field = field
    end
    def eval(env)
      target = @target.eval(env)
      if target.instance_of? Environment::Environment
        target.interned[@field.name]
      else
        if target.respond_to?(@field.name)
            target.method(@field.name)
        end
      end
    end
  end

  class ForIn < Expression
    def initialize(coll_or_range, args, body)
      @coll_or_range = coll_or_range
      @args          = args
      @body          = body
    end
    def eval(env)
      coll_or_range = @coll_or_range.eval(env)
      result = nil
      scope = Environment::Environment.new(parent: env)
      if coll_or_range.instance_of? Array
        coll_or_range.each do |item|
            scope.intern(@args[0].name, item)
            @body.each do |expr|
              result = expr.eval(scope)
            end
        end
        result
      else
        raise "Not implemented: for in for type #{coll_or_range.class}"
      end
    end
  end

  class Sequence < Expression
    attr_reader :items
    def initialize(items = nil)
      @items = items || []
    end

    def eval(env)
      self.items.map { |expr| if expr.is_a? Expression then expr.eval(env) else expr end }
    end

    def to_s
      "[#{@items.join(', ')}]"
    end
  end

  class Block < Expression
    attr_reader :body
    def initialize(body)
      @body  = body
    end
    def eval(env)
      scope = Environment::Environment.new(parent: env)
      result = nil
      @body.each do |form|
        result = form.eval(scope)
      end
      scope
    end
  end
end
