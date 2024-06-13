# Sparky triggering protocol (STP)

Sparky Triggering Protocol allows to trigger jobs automatically by creating files in special format.

Consider an example.

```bash
$ nano $project/.triggers/$key
```

File has to be located in project `.trigger` directory. 

And `$key` should be a unique string identifying a build _within_ directory ( on per project basis ).

A content of the file should be a Raku code returning a Raku Hash:

```raku
{
  description => "web app build",
  cwd => "/path/to/working/directory",
  sparrowdo => %(
    localhost => True,
    no_sudo   => True,
    conf      => "/path/to/file.conf"
  )
}
```

Sparky daemon parses files in `.triggers` and launch build per every file, removing file afterwards,
this process is called file triggering.

To separate different builds just create trigger files with unique names inside `$project/.trigger` directory.

STP allows to create _supplemental_ APIs to implement more complex and custom build logic, while keeping Sparky itself simple.

## Trigger attributes

Those keys could be used in trigger Hash. All they are optional.

* `cwd`
Directory where sparrowfile is located, when a build gets run, the process will change to this directory.

* `description`
Arbitrary text description of build

* `sparrowdo`

Options for sparrowdo cli run, for example:

```raku
sparrowdo => {
  %(
    host  => "foo.bar",
    ssh_user  => "admin",
    tags => "prod,backend"
  )
}
```

Follow [sparrowdo cli](https://github.com/melezhik/sparrowdo#sparrowdo-cli) documentation for `sparrowdo` parameters explanation.
