`{.:}`

# nest_

`nest_` is an object language and library for constructing user interface structures in lua for monome devices. 

it is a collection of common interface components (affordances) and nested object-oriented heuristics that allow for quick assemblage of user interfaces on monome grids, norns, and arcs, which arbitrary functionalities bound by the artist programmer.

```
nest_ {
    _affordance {
        property = 5,
        value = 1,
        action = function(self, value)
            dosomething(value)
        end
    }
}
```

currently in beta ! current documentation covers existing features, will continue to grow w/ progress over the next few months

# Studies

1. [nests of affordances](./study/study1.md)

2. [the grid module](./study/study2.md)

3. the txt module

4. affordances controlling affordances

5. customization

# Docs

## Modules

the various types and interface buidling blocks of nestworld are split up into a growing collection files or `modules`. at the very least, the `core` and `norns` modules are required for use with norns. click the links to read on !


- [`nest_/core`](./doc/core.md)
- `nest_/norns`
- [`nest_/grid`](./doc/grid.md)
- `nest_/arc`
- `nest_/txt`


## Including

typically, it will make the most sense to include nest_ by [downloading the .zip](https://github.com/andr-ew/nest_/archive/master.zip) and dropping the required module files into your script's `/lib/nest_` folder, including them like so:

```
include 'lib/nest_/core'
include 'lib/nest_/norns'
include 'lib/nest_/grid'
include 'lib/nest_/txt'
```

alternatively, if this repo lives in your code folder, you can incude modules externally: `include 'nest_/lib/nest_/core'`

# Examples

- [grid demo (functional)](https://github.com/andr-ew/nest_/blob/master/examples/grid.lua)
- [ndls (full app, not yet functional)](https://github.com/andr-ew/ndls/blob/master/ndls.lua)
- [brds (full app, not yet functional)](https://github.com/andr-ew/brds/blob/main/brds.lua)
- [various](https://github.com/andr-ew/nest_/tree/master/examples)
