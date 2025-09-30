# Sparky as a simple orchestrator for self hosted clusters

Kubernetes seems to overkill and too complex when all you have is few pods scattered across 3 virtual machines.

People use selfhosted or homelabs systems a lot, and every time I see those posts on [fosstdon](https://fosstodon.org/tags/homelab) I think how great solution [Sparky](https://github.com/melezhik/sparky) would be:

- Simple installation

- Included control plane with clear and easy to use UI

- Rakulang + Sparrow all battery included framework for automation


# Design

So the design would be:


```
           Sparky
         /    |   \
        [   manage  ] 
      /       |       \
   VM1        |        \                 
              |        VM3
              |
              VM2
```

# Bootstrap cluster

* Install Sparky on control plane machine

* Set up ssh connection between Sparky and all VMs

* Create hosts file

* Provision VMs

    * Install podman ( or any other preferable container engine on all VMs ) on all VMs

    * Install other software depending on VM role

* Deliver live updates to all VMs

# Ssh connection

Basically we need to make it sure there is ssh passwordless connection from control plane to
any of VMs. Also the ssh account we use need to have root privileges to do a further
provisioning:

```
$ ssh VM1 sudo echo # should succeed
```

# Install Sparky

Any Linux box is enough, recommended system resources - 6 GB RAM ( maybe less ). Sparky
is is written on Raku, so we need to install Raku first 

```bash
curl https://rakubrew.org/install-on-perl.sh | sh
eval "$(~/.rakubrew/bin/rakubrew init Bash)"
echo 'eval "$(~/.rakubrew/bin/rakubrew init Bash)"' >> ~/.bashrc
rakubrew add moar-2025.08
```

And then install Sparky and run Sparky services required for control plane operation:

```bash
git clone https://github.com/melezhik/sparky.git
cd sparky
raku db-init.raku # initialize Sparky sqlite database
zef install --/test .
```

Run sparky services:

```bash
sparman  --base=$PWD worker_ui  conf
sparman  worker_ui start # start Sparky UI dashboard
sparman  worker start # start Sparky job runner 
```

Once everything is set up you will be able to go to http://127.0.0.1:4000 and see Sparky dashboard
with no projects ( will be created later )

# Hosts file

Hosts file ala Ansible inventory file describes all our cluster VMs and their roles.

Image a simple setup with two virtual machines with backend and one virtual machine
with frontend:

`nano hosts.raku`

```raku
[
   %( 
    :host<192.168.0.1>, 
    tags => %(
      :frontend,
    ),
   ),
   %( 
    :host<192.168.0.2>, 
    tags => %(
      :backend,
    ),
   ),
   %( 
    :host<192.168.0.3>, 
    tags => %(
      :backend,
    ),
   ),
]
```

# Create provision scenario

Sparky is really cool as it has all you need to provision VMs, let's say for all VMs
we need to install podman and for frontend VMs we want to install nginx server:


`nano sparrowfile`

```raku
package-install ("podman");

if tags()<frontend> {
    package-install "nginx";
}
```

In general provision scenario could be complex, but I'd like to keep things simple for 
demo only purposes. However may plugins and useful function are already available,
please refer documentation:

- Sparrow DSL - https://github.com/melezhik/Sparrow6/blob/master/documentation/dsl.md

- Sparrow plugins - https://sparrowhub.io/search?q=all


# Provision VMs

To provision VMs all we need to is to kick Sparky scenario via sparrowdo cli:

```
sparrowdo --host=hosts.raku --bootstrap
```

What will happen under the hood Sparky jobs will be fired to run across your cluster VMs and
provision them accordingly. To track changes and see what's going on in Sparky cluster
just visit UI and find proper report page.

Boostrap flag is only required once, when VMs are provisioned for the first time, as this
will make sure that Sparky client is installed on those VMs first. Sparky client will
then parse Sparky scenario and execute it.


# Live updates 

Say, we are going to use podman to run application containers, Sparky has a decent support of
podman and quadlet, let's create a separate scenario to deliver update to the cluster:

`nano quadlet-setup.raku`

```raku
# create quadlet network
my $s = task-run "podman network", "quadlet-resource", %(
  :type<network>, 
  :description<podman network>,
  :name<my-app>,
  :subnet<10.10.0.0/24>,
  :gateway<10.10.0.1>,
  :dns<9.9.9.9>,
);

bash "systemctl daemon-reload" if $s<changed>;

# create quadlet container template
# so other containers
# will base on it

$s = task-run "container template quadlet", "quadlet-resource", %(
  :type<container>, 
  :description<app server>,
  :name<my-app>,
  :containername<my-app-%i>,
  :hostname<my-app-%i>,
  :expose<4000>,
  :image<local.registry:%i>,
  :network<my-app.network>,
  :label<app=my-app>,
);

bash "systemctl daemon-reload" if $s<changed>;
```

This scenario will go across all cluster VMs and install podman network and podman container template on them,
to run scenario just repeat previous command, pointing different scenario file (pay attention we don't need to provide boostrap this time):

```
sparrowdo --host hosts.raku --sparrowfile quadlet-setup.raku
```

Again to track changes in real time we need to go to Sparky UI and wait till all jobs are finished

Once podman basic resources are setup, let create a very simple scenario to deploy podman 
containers on our cluster:

`nano update.raku`

```raku

my $version = tags()<version>;

$s = task-run "app deploy", "quadlet-container-deploy", %(
  :name<my-app>,
  :$version,
);

bash "systemctl daemon-reload";

service-start "my-app\@$version$";

```

Now we are ready to deploy the very first version of our application on cluster. 

Let's not describe here how we prepare podman images, as this is beyond the topic.

Deploy frontend:

```
sparrowdo --host hosts.raku --tags version=frontend-0.0.1,frontend --sparrowfile update.raku
```

Deploy backends:

```
sparrowdo --host hosts.raku --tags version=backend-0.0.1,backend --sparrowfile update.raku
```

Again to track changes in real time we should go to Sparky dashboard page

# More things to tell

This short introduction has not covered other cool Sparky features:

* Create complex update scenarios to carry out blue/green, canary releases

* Create custom HTML forms to run jobs from Sparky UI directly instead of cli

* Collect and download jobs artifacts from VMs across cluster

* Create custom Sparky plugins using all popular programming languages

Please let me know what you think and I will probably create the second part of tutorial