# Sparky ACL

Sparky ACL allows to create access control lists to manage role based access to Sparky resources

# Creation of ACL

Create list.yml file located at `SPARKY_ROOT/acl/list.yaml` path, for example:

```yaml
global:
  allow:
    users:
      - alexey.melezhik
      - john.brown

projects:
  hello-world:
    allow:
      users:
        - "*"
  service-logs:
          allow:
              users:
                  - "*"
```

In this example we allow users alexey.melezhik and john.brown to run run any jobs,
and allow _all_ users run jobs hello-world and service-logs.

# ACL flow

ACL flow is strict, if an action is not allowed explicitly it's implicitly denied, 
for example in this case:

```yaml
global:
  allow:
    users:
      - alexey.melezhik
      - john.brown
```

All users besides alexey.melezhik and john.brown are denied to run any project

# User IDs

User IDs are supplied by oauth provider during authentication phase,
usually those are user accounts in oauth external server.

For example, in case of GitLab oauth provider user IDs are gitlab accounts

# Host specific ACLs

To _override_ default ACL (located at `SPARKY_ROOT/acl/list.yaml`) one has
to specify list.yaml file located at `SPARKY_ROOT/acl/hosts/$host/list.yaml`,
where $host is a hostname (output of `hostname` command) of host where Sparky
runs, this allows to maintain multiple ACL configurations for many Sparky instances:

```
acl/hosts/host-foo/list.yaml
acl/hosts/host-bar/list.yaml
acl/hosts/host-baz/list.yaml
```

Host specific ACL override default ACL and has the same DSL to describe access rules.

# Explicit deny

To explicitly deny a user from a job execution, use deny directive:

```
projects:
  hello-world:
    allow:
      users:
        - "*"
    deny:
      users:
        - bad_guy
```

This code code allows all users to execute hello-world sparky project, besides a user with login bad_guy

## Access to everyone

To allow any user to run run any resources just remove any list.yaml files from Sparky configuration



