# Calico
### A little scripting language with first class environments and the ability to call ruby methods directly
#### Very WIP, funnily enough I made this after telling myself I was going to make a bc clone in with operator precedence to learn the language 

```
Time <- find-class('Time')

now <- use Time in { now().inspect().reverse() * 3 }

print(now)

List <- [*init] {
  {
    items <- init
    add <- [x]{
      items.push(x)
    }
    at <- [idx] {
      items.at(idx)
    }
    map <- [f] {
      result <- @[]
      for x in items {
	    result.push(f(x))
      }
    }
    filter <- [f] {
      result <- @[]
      for x in items {
        if f(x) {
          result.push(x)
        }
      }
    }
  }
}

ys <- List(2, 4, 6, 8)

use ys in {
  add(5)
  add(10)
  add(15)
  items := map([x]{ x * x })
}

print(ys.items.inspect())
```
