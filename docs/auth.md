# Auth

Sparky authentication protocols

# Synopsis

Sparky comes with two authentication protocols:

* Default 

* Oauth2

## Default protocol

Default protocol is a simplest one, when you don't need anything fancy,
but authentication, just add these section to your `~/.sparky.yaml` file:

```yaml
auth:
  default: true
  users:
    -
      login: admin
      password: 80ffc4a1fb71d117b0d74337c5943bf2
    -
      login: operator
      password: 223e2baafd4e70dcffe70420cfcca615
```

Here we have 2 logins - admin and operator, with md5summed passwords
admin_password and operator_password, that is it, plain and simple.

Now we can even setup ACL polices for those account using [ACL](https://github.com/melezhik/sparky/blob/master/docs/acl.md)

```yaml
global:
  allow:
    users:
      - admin

projects:
  maintain:
    allow:
      users:
        - operator
```

## OAUTH 2.0 protocol

For more secure scenario use  [oauth2](https://oauth.net/2/) authentication 
protocol.

To enable oauth2, add following section to `~/sparky.yaml` configuration file (
example for Gitlab provider):

```yaml
auth:
  provider: gitlab
  provider_url: https://gitlab.host/oauth # URL for authentication
  redirect_url: http://sparky.host:4000/oauth2 # should be something your_sparky_host/oauth2
  user_api: https://gitlab.host/api/v4/user # API to fetch user data, example for gitlab
  scope: "openid email read_user" # scopes enabled for oauth token
  # generate client_id, client_secret when create sparky application in gitlab 
  client_id: aaabbbcccdddeeefffggghhhiiijjjkkklllmmmnnnooopppqqqrrrssstttuuuvvvww
  client_secret: 01020102aa01020102bb01020102cc01020102dddd00ee00ff0010101ff0101f
  state: hellosparky # this is optional
```

For now only GitLab oauth2 provider is supported

# See also

## ACL

Sparky ACL allows to create access control lists to manage role based access to Sparky resources, see [docs/acl.md](https://github.com/melezhik/sparky/blob/master/docs/acl.md)
