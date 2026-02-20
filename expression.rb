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
  OP_SET     = ':='
  OP_RANGE   = '..'
  OP_PIPE    = '->'
  COMPARATOR_PRECEDENCE = 1
  OPERATOR_PRECEDENCES = {
    OP_BIND    => 0,
    OP_SET     => 0,
    OP_EQ      => COMPARATOR_PRECEDENCE,
    OP_GTHAN   => COMPARATOR_PRECEDENCE,
    OP_GTHANEQ => COMPARATOR_PRECEDENCE,
    OP_LTHAN   => COMPARATOR_PRECEDENCE,
    OP_LTHANEQ => COMPARATOR_PRECEDENCE,
    OP_PIPE    => 2,
    OP_RANGE   => 2,
    OP_SUB     => 3,
    OP_ADD     => 3,
    OP_DIV     => 4,
    OP_MUL     => 4
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
      elsif @op == OP_SET
        if @lexpr.instance_of? Symbol
          binding_name = @lexpr.name
          val          = @rexpr.eval(env)
          place = env.location_of(binding_name)
          place.intern(binding_name, val)
        elsif @lexpr.instance_of? DotAccess
          root  = @lexpr.target.eval(env)
          field = @lexpr.field
          val   = @rexpr.eval(env)
          if root.respond_to?("#{field}=")
            root.public_send("#{field}=", val)
          else
            raise "Attempt to set read only value in #{@lexpr.target.name}.#{field} := #{val}"
          end
        end
      elsif @op == OP_PIPE
        if @rexpr.instance_of? Call
          Call.new(@rexpr.func, @rexpr.args.prepend(@lexpr)).eval(env)
        else
          Call.new(@rexpr, [@lexpr]).eval(env)
        end
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
          when OP_RANGE   then left .. right
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
      case @name
      when 'true'
        return true
      when 'false'
        return false
      else
        env.lookup(@name)
      end
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
    attr_accessor :params, :body, :closure

    def initialize(params, body, env = nil)
      @params  = params
      @body    = body
      @closure = env # This is nil until eval is called, so pretty much never because a lambda is evaluated on binding
    end
    def eval(env)
      Lambda.new(@params, @body, env)
    end
  end

  class Splat < Expression
    def initialize(items)
      @items = items
    end
    def eval(env)
      self
    end

    def items
      @items
    end
  end
  class Call < Expression
    attr_reader :func, :args
    def initialize(name, args)
      @func = name
      @args = args
    end

    def eval(env)
      func = @func.eval(env)
      if func.instance_of? Lambda
        instance_env = Environment::Environment.new(parent: func.closure || env)
        evaled_args = @args.map { |a| a.eval(env) }
        func.params.each_with_index do |param, i|
          if evaled_args[i].instance_of? Splat
            xs = evaled_args[i].items.eval(env)
            if xs.length <= func.params.length
              idx = i
              xs.each do |x|
                instance_env.intern(func.params[idx].name, x)
                idx += 1
              end
              break
            end
          end
          if param.instance_of? Vararg
            rest = evaled_args[i..-1] || []
            instance_env.intern(param.name, rest)
            break
          else
            instance_env.intern(param.name, evaled_args[i])
          end
        end
        result = nil
        func.body.each { |expr| result = expr.eval(instance_env) }
        result
      elsif func.respond_to?(:call)
        func.call(*@args.map { |a| a.eval(env) })
      end
    end
  end

  class SpawnExpression < Expression
    def initialize(call)
      @call = call
    end
    def eval(env)
      Thread.new do
        @call.eval(env)
      end
    end
  end

  class Vararg < Expression
    attr_accessor :name
    def initialize(name)
      @name = name
    end
    def eval(env)
      raise 'This should be unreachable, Expression::Vararg.eval. Varargs are never directly evaluated'
    end
  end
  class DotAccess < Expression
    attr_reader :target, :field
    def initialize(target, field)
        @target = target
        @field  = field.name
    end
    def eval(env)
      target = @target.eval(env)
      if target.instance_of? Environment::Environment and target.interned.has_key? @field
        target.interned[@field]
      else
        if target.respond_to?(@field)
            target.method(@field)
        end
      end
    end
  end

  class UseExpression < Expression
    def initialize(some_env)
      @env = some_env
    end
    def eval(env)
      opened_env = @env.eval(env)
      env.interned.merge!(opened_env.interned)
      opened_env.interned
    end
  end

  class UseInExpression < UseExpression
    def initialize(some_env, body)
      @env  = some_env
      @body = body
    end
    def eval(env)
      object = @env.eval(env)
      if object.instance_of? Environment::Environment
        @body.eval(object)
      else
        object_scope = Environment::Environment.new(parent: env)
        object.methods.each do |method|
          object_scope.intern(method.to_s, object.method(method))
        end
        @body.eval(object_scope)
      end
    end
  end
  class IfElse < Expression
    def initialize(cond, body, elt)
      @cond = cond
      @body = body
      @elt  = elt
    end

    def eval(env)
      cond = @cond.eval(env)
      if cond
        @body.eval(env)
      elsif @elt
        @elt.eval(env)
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
      coll_or_range.each do |item|
        scope.intern(@args[0].name, item)
        @body.each do |expr|
          result = expr.eval(scope)
        end
      end
      result
    end
  end

  class While
    def initialize(cond, body)
      @cond = cond
      @body = body
    end
    def eval(env)
      result = nil
      while @cond.eval(env) do
        result = @body.eval(env)
      end
      result
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
    def initialize(body, return_result = false)
      @body  = body
      @return_result = return_result
    end
    def eval(env)
      scope = Environment::Environment.new(parent: env)
      result = nil
      @body.each do |form|
        result = form.eval(scope)
      end
      if @return_result
        result
      else
      scope
      end
    end
  end
end
