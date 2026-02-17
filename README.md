# Calico
### Very early WIP. funnily enough i made this after telling myself i was going to make a simple math language / calculator to learn Ruby! but Ruby is pretty flexible and it's something new so i would like to mess around with this some more. I would say its most unique feature is the idea of first class computed environments



```
hello <- [name] {
    print('Hello ' + name + '!')
}

hello('bobby')

square <- [x] {x * x}

print(square(6502))


add <- [a] {[b] {a + b}}

add5 <- add(5)

print(add5(50))


obj <- {
  square <- [x] {x * x}
}

print(obj.square(25))

```
