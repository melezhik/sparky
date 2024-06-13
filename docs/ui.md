# UI DSL

Sparky  UI DSL allows to grammatically describe UI for Sparky jobs
and pass user input into scenario as variables.

## Simple example

For job with following input parameters:
 
 - Name
 - CV
 - Color 

Add `vars` section in sparky.yaml file:

```yaml
vars:
  -
      name: Name
      default: Alexey
      type: input
  -
      name: CV
      default: I am a programmer
      type: textarea

  -
      name: Language
      values: [ Raku, Rust, Golang ]
      type: select
      default: Rust
      multiple: true

  -
      name: Color
      values: [ Red, Blue, Green ]
      type: select
      default: Blue

  -
      name: Debug
      type: checkbox
      default: true
```

Sparky job now gets html controls for input parameters:

![build parameters](https://raw.githubusercontent.com/melezhik/sparky/master/images/sparky-web-ui-build-with-params.jpeg)
 
Whinin scenario those parameters are available through `tags()` function:

```raku
say "Name param passed: ", tags()<Name>;
say "CV param passed: ", tags()<CV>;
say "Language param passed: ", tags()<Language>;
say "Debug param passed: ", tags()<Debug>;
```

When a same job get runs bypassing user input ( via HTTP API )
default values could be set via `sparrowdo.tags` section:

```yaml
sparrowdo:
  no_sudo: true
  no_index_update: true
  bootstrap: false
  format: default
  tags: >
    Language=Rakudo,
    Name=Alex,
    Occupation=devops
```

## HTML UI controls supported

Currently following UI controls are supported:

* text input

* password

* text area

* select list (including multiple)

* checkbox 

## UI sub tasks

UI sub tasks allow to split complex UI into smaller parts, by specifying `group` term.
Consider this example:

```
vars:
  -
    name: Flavor
    default: "black" 
    type: select 
    values: [black, green]
    group: [ tea ]

  -
    name: Topic
    default: "milk"
    type: select
    values: [milk, cream]
    group: [ tea ]

  -
    name: Flavor
    default: "latte"
    type: select 
    values: [espresso, amerikano, latte]
    group: [ coffee ]

  -
    name: Topic  
    default: "milk"
    type: select
    values: [milk, cream, cinnamon]
    group: [ coffee ]
    multiple: true
  -
    name: Step3
    default: "boiled water"
    type: input
    group: [ tea, coffee ]

group_vars:
  - tea
  - coffee
```

When a user clicks a job page, they'll get a choice of two separate pages, one for
coffee (group coffee) and another one for tea (group tea) UI with respected UI elements.


## Templating UI variables

One can template variables used in UI, by creating a global template file
`SPARKY_ROOT/templates/vars.yaml` with variables:


```yaml
vars:
  name: Alexey
  surname: Melezhik
```

Shared variables are inserted into job `sparky.yaml` file
by using `%name%` syntax:

```yaml
vars:
  -
      name: Name
      default: %name%
      type: input
  -
      name: LastName
      default: %surname%
      type: input
```

This approach allows to reduce code duplication when developing Sparky job UIs.

To specify host (*) specific file, use template file located at 
`SPARKY_ROOT/templates/hosts/$hostname/` directory

For example:

`SPARKY_ROOT/templates/hosts/foo.bar`

```yaml
vars:
  role: db_server
```

`*` Where `$hostame` is output of `hostame` command executed on the server that hosts Sparky,
this variable could be overridden by `HOSTNAME` environment variable 

Host specific variables always override variable specified at `SPARKY_ROOT/templates/vars.yaml`

---

To create nested variables use dot notation:

`vars.yaml`

```
vars:
  user:
    name: Piter Pen
```

`sparky.yaml`

```yaml
vars:
  -
    name: Name
    default: "%user.name%"
    type: input
```

## Templating tag variables

Tag variables in `sparky.yaml` could use template variables:

`vars.yaml`:

```
  user:
    name: Alex
    surname: Melezhik
```

```
sparrowdo:
  tags: |
    Name=%user.name%,
    LastName=%user.surname%
```
