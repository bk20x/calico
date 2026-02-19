module Environment
  class Environment
    attr_accessor :parent, :interned
    def initialize(parent: nil)
      @parent   = parent
      @interned = {}
    end

    def intern(name, val)
      @interned[name] = val
    end

    def lookup(symbol)
      env = self
      while env != nil do
        return env.interned[symbol] if env.interned.has_key?(symbol)
        env = env.parent
      end
      raise "Unbound symbol: #{symbol}"
    end
    def location_of(symbol)
      env = self
      while env != nil do
        if env.interned.has_key?(symbol)
          return env
        end
        env = env.parent
      end
      raise "Unbound symbol: #{symbol}"
    end
  end
end