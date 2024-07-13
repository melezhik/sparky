## Sparky plugins

Sparky plugins are extensions points to add extra functionality to Sparky builds.

These are Raku modules get run _after_ a Sparky project finishes or in other words when a build is completed.

To use Sparky plugins you should:

* Install plugins as Raku modules

* Configure plugins in project's `sparky.yaml` file

## Install Sparky plugins

You should install a module on the same server where you run Sparky at. For instance:

```bash
$ zef install Sparky::Plugin::Email # Sparky plugin to send email notifications
```

## Configuring Sparky plugins

In project's `sparky.yaml` file define plugins section, it should be list of Plugins and its configurations.

For instance:

```bash
$ cat sparky.yaml
```

That contains:

```yaml
plugins:
  Sparky::Plugin::Email:
    parameters:
      subject: "I finished"
      to: "happy@user.email"
      text: "here will be log"
  Sparky::Plugin::Hello:
    parameters:
      name: Sparrow
```

## Developing Sparky plugins

Technically speaking  Sparky plugins should be just Raku modules.

For instance, for mentioned module Sparky::Plugin::Email we might have this header lines:

```raku
use v6;

unit module Sparky::Plugin::Hello;
```

That is it.

The module should have `run` routine which is invoked when Sparky processes a plugin:

```raku
our sub run ( %config, %parameters ) {

}
```

As we can see the `run` routine consumes its parameters as Raku Hash, these parameters are defined at mentioned `sparky.yaml` file,
at plugin `parameters:` section, so this is how you might handle them:

```raku
sub run ( %config, %parameters ) {

  say "Hello " ~ %parameters<name>;

}
```

You can use `%config` Hash to access Sparky guts:

* `%config<project>`      - the project name
* `%config<build-id>`     - the build number of current project build
* `%cofig<build-state>`   - the state of the current build

For example:

```raku
sub run ( %config, %parameters ) {

  say "build id is: " ~ %parameters<build-id>;

}
```

Alternatively you may pass _some_ predefined parameters plugins:

* %PROJECT% - equivalent of `%config<project>`
* %BUILD-STATE% - equivalent of `%config<build-state>`
* %BUILD-ID% - equivalent of `%config<build-id>`

For example:

```bash
$ cat sparky.yaml
```

That contains:

```yaml
plugins:
  - Sparky::Plugin::Hello:
    parameters:
      name: Sparrow from project %PROJECT%
```

## Limit plugin run scope

You can defined _when_ to run plugin, here are 3 run scopes:

* `anytime` - run plugin irrespective of a build state. This is default value
* `success` - run plugin only if build has succeeded
* `fail`    - run plugin only if build has  failed

Scopes are defined at `run_scope:` parameter:

```yaml
- Sparky::Plugin::Hello:
  run_scope: fail
  parameters:
    name: Sparrow
```

## Examples of Sparky plugins


* [Sparky::Plugin::Hello](https://github.com/melezhik/sparky-plugin-hello)
* [Sparky::Plugin::Notify::Email](https://github.com/melezhik/sparky-plugin-notify-email)
