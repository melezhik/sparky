# Job API

Job API allows to orchestrate multiple Sparky jobs.

For example:

```raku
if tags()<stage> eq "main" {

    use Sparky::JobApi;

    my $j = Sparky::JobApi.new;

    $j.queue({
      description => "spawned job", 
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
    });

    say "job info: ", $j.info.perl;

} elsif tags()<stage> eq "child" {

  say "I am a child scenario";
  say "config: ", config().perl;
  say "tags: ", tags().perl;

}
```

In this example the same scenario runs for a main and child job, but
code is conditionally branched off based on a `tags()<stage>` value:

```bash
sparrowdo --localhost --no_sudo --with_sparky --tags=stage=main
``` 

## Job attributes

A child job inherits all the main job attributes, including sparrowfile, tags, configuration file
and sparrowdo configuration.

To override some job configuration attributes, use `sparrowdo` and `tags` parameters:

```raku
my $j = Sparky::JobApi.new;
$j.queue({
   tags => %(
     stage => "child",
     foo => 1,
     bar => 2,
   ),
   sparrowdo => %(
      no_index_update => True,
      no_sudo => True,
      docker => "debian_bullseye"
  )
});
```

Follow [sparrowdo cli](https://github.com/melezhik/sparrowdo#sparrowdo-cli) documentation for `sparrowdo` parameters explanation.

## Set a project for spawned job

One can choose to set a job project either explicitly:

```raku
  my $j = Sparky::JobApi.new: project<spawned_job>;
  $j.queue({
    description => "spawned job", 
  });
```

The code will spawn a new job for a project called "spawned_job"

Or implicitly, with _auto generated_ project name:

```raku
  my $j = Sparky::JobApi.new;
  $j.queue({
    description => "spawned job", 
  });
```

This code will spawn a new job on project named `$currect_project.spawned_$random_number`

Where `$random_number` is random integer number taken from a default range - `1..4`.

To increase a level of parallelism, use `workers` parameter:

```raku
for 1 .. 10 {
  my $j = Sparky::JobApi.new: :workers<10>;
  $j.queue({
    description => "spawned job"
  });
}
```

For this case a random number will be taken from a range `1..10`.

## Asynchronous (none blocking) wait of child jobs

Main scenario could asynchronously wait a child job
using Raku `supply|tap` method:

```raku
  if tags()<stage> eq "main" {

    # spawns a child job

    use Sparky::JobApi;
    my $j = Sparky::JobApi.new: :project<spawned_jobs>;
    $j.queue({
      description => "my spawned job",
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
    });

    say "queue spawned job, ",$j.info.perl;

    my $supply = supply {

        while True {

          my $status = $j.status;

          emit %( job-id => $j.info<job-id>, status => $status );

          done if $status eq "FAIL" or $status eq "OK";

        }
    }

    $supply.tap( -> $v {
        say $v;
    });
  } elsif tags()<stage> eq "child" {

    # child job here

    say "config: ", config().perl;
    say "tags: ", tags().perl;

  }
```

## Recursive jobs

Recursive jobs are when a child job spawns another job and so on. 

Be careful not to end up in endless recursion:

```raku
  use Sparky::JobApi;

  if tags()<stage> eq "main" {

    my $j = Sparky::JobApi.new: :project<spawned_01>;

    $j.queue({
      description => "spawned job", 
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
      sparrowdo => %(
        no_index_update => True
      )
    });

    say "queue spawned job ", $j.info.perl;

  } elsif tags()<stage> eq "child" {

    say "I am a child scenario";

    my $j = Sparky::JobApi.new: :project<spawned_02>;

    $j.queue({
      description => "spawned job2. 02",
      tags => %(
        stage => "off",
        foo => 1,
        bar => 2,
      ),
    });

    say "queue spawned job ",$j.info.perl;

  } elsif tags()<stage> eq "off" {

    say "I am off now, good buy!";
    say "config: ", config().perl;
    say "tags: ", tags().perl;

  }
```

## Predefined job IDs

Explicitly passing `job-id` allow to wait
to jobs that have not yet started. 

Consider this scenario with recursive jobs:


```raku
use Sparky::JobApi;

sub wait-jobs(@q) {

    my @jobs;

    for @q -> $j {

      my $supply = supply {

        while True {

          my %info = $j.info;

          my $status = $j.status;

          %info<status> = $status;

          emit %info;

          done if $status eq "FAIL" or $status eq "OK";

          sleep(1);

        }

      }

      $supply.tap( -> $v {
        push @jobs, $v if $v<status> eq "FAIL" or $v<status> eq "OK";
        say $v;
      });

    }

    say @jobs.grep({$_<status> eq "OK"}).elems, " jobs finished successfully";
    say @jobs.grep({$_<status> eq "FAIL"}).elems, " jobs failed";
    say @jobs.grep({$_<status> eq "TIMEOUT"}).elems, " jobs timeouted";

}

if tags()<stage> eq "main" {

    my $rand = ('a' .. 'z').pick(20).join('');

    my $job-id = "{$rand}_1";

    Sparky::JobApi.new(:project<worker_1>,:$job-id).queue({
      description => "spawned job. 03.1",
      tags => %(
        seed => $rand,
        stage => "child",
        i => 1,
      ),
    });

    my @jobs;

    # wait all 10 recursively launched jobs
    # that are not yet launched by that point
    # but will be launched recursively
    # in "child" jobs 

    for 1 .. 10 -> $i {

      my $project = "worker_{$i}";

      my $job-id = "{$rand}_{$i}";

      my $j = Sparky::JobApi.new: :$project, :$job-id;
        
     @jobs.push: $j;

    }

    wait-jobs @jobs;

  } elsif tags()<stage> eq "child" {

    say "I am a child job!";

    say tags().perl;

    if tags()<i> < 10 {

      my $i = tags()<i>.Int + 1;

      # do some useful stuff here
      # and launch another recursive job
      # with predefined project and job ID
      # $i variable gets incremented
      # and all recursively launched jobs
      # get waited in a "main" scenario, 
      # function  wait-jobs

      my $project = "worker_{$i}"; 
      my $job-id = "{tags()<seed>}_{$i}";

      Sparky::JobApi.new(:$project,:$job-id).queue({
        description => "spawned job. 03.{$i}",
        tags => %(
          seed => tags()<seed>,
          stage => "child",
          i => $i,
        ),
      });
   }
}
```

So in this scenario job IDs get generated ahead of time while jobs get launched recursively in
subsequent jobs. 

Main scenario waits till all recursive jobs finishes in none blocking Raku `supply|tap` fashion.

## Job stash

Stash is a piece of data a job could write or read. There are two ways to use stashes.

When a child job writes a data and the a parent job reads it:

```raku
  use Sparky::JobApi;

  if tags()<stage> eq "main" {

    # spawns a child job

    my $j = Sparky::JobApi.new(:project<spawned_jobs>);
    $j.queue({
      description => "my spawned job",
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
    });

    say "queue spawned job, ",$j.info.perl;

    my $supply = supply {

        while True {

          my $status = $j.status;

          emit %( job-id => $j.info<job-id>, status => $status );

          done if $status eq "FAIL" or $status eq "OK";

          sleep(5);

        }
    }

    $supply.tap( -> $v {
        say $v;
    });

    # read a data from child job
    say $j.get-stash().perl;


  } elsif tags()<stage> eq "child" {

    # child job here

    say "config: ", config().perl;
    say "tags: ", tags().perl;

    my $j = Sparky::JobApi.new( mine => True );

    # puts a data so that other jobs could read it
    $j.put-stash({ hello => "Sparky" });

  }
``` 

When a parent job writes a data to a child job ( before it's spawned ) and
then a child job reads it:

```raku
  use Sparky::JobApi;

  if tags()<stage> eq "main" {

    # spawns a child job

    my $j = Sparky::JobApi.new(:project<spawned_jobs>);

    # prepare a data for a child job
    # so that when it starts
    # it could read it

    $j.put-stash({ hello => "world" });

    $j.queue({
      description => "my spawned job",
      tags => %(
        stage => "child",
        foo => 1,
        bar => 2,
      ),
    });

    say "queue spawned job, ",$j.info.perl;

    wait-jobs(($j,)) # wait till a job has finished

  } elsif tags()<stage> eq "child" {

    # child job here

    say "config: ", config().perl;
    say "tags: ", tags().perl;

    # read a data prepared by a parent job

    my $j = Sparky::JobApi.new( mine => True );

    say $j.get-stash().perl;

  }
```

In general form a job write a data to stash by using `put-stash` method:

```raku
my $j = Sparky::JobApi.new();
$j.put-stash({ hello => "world", list => [ 1, 2, 3] });
$j.queue; # job will be queued and get an access to a data via `get-stash` method
```

A data written has to a be any Raku data structure that could be
converted into JSON format.

To read a data from a  _current_ job, use `mine => True` parameter of
Sparky::JobApi constructor.

```raku
# read a data in this job stash
my $j = Sparky::JobApi.new( mine => True );
$j.get-stash();
```

To read a data from a  _specific_ job, specify `project` and `job-id` in
Sparky::JobApi constructor:

```raku
# read a data from a specific job stash
my $j = Sparky::JobApi.new( :$project, :$job-id );
$j.get-stash();
```

## Job meta

Job meta strings is a lightweight alternative to job stash, child job may send some feedback
to a parent job by just adding meta information to report:

Code in child job:

```raku

say "meta: name=alexey age=48";
say "meta: reboot=need";
```

Meta handled in parent job:

```
# spawn a child job
my $j = Sparky::JobApi.new();

my $st = self.wait-job($j);

die unless $st<OK>;

# collect any meta information
# from child job
# meta comes as Arraty of Hashes

my @meta = $j.meta;

say @meta[0]<name>; # alexey;
say @meta[0]<age>; # 48;
say @meta[1]<reboot>; # need;
```

## Job files

Job files are similar to job stash, but used to transfer files between jobs, not
structured Raku hashes.

Here is an example how one can share file between child and parent job:


```raku

use Sparky::JobApi;

class Pipeline

  does Sparky::JobApi::Role

  {

    method stage-main {

      say "hello from main ...";

      my $j = self.new-job;
  
      $j.queue: %(
        tags => %(
          stage => "child"
        )
      );

      my $st = self.wait-job($j);
      
      die unless $st<OK>;

      say $j.get-file("README",:text);
  
    }

    method stage-child {

      say "hello from child";

      my $j = Sparky::JobApi.new: mine => True;

      task-run "http/GET 1.png", "curl", %(
        args => [
          %( 
            'output' => "{$*CWD}/README.md"
          ),
        [
          'silent',
          '-f',
          'location'
        ],
        #'https://raw.githubusercontent.com/melezhik/images/master/1.png'
        'https://raw.githubusercontent.com/melezhik/images/master/README.md'
        ]
      );

      $j.put-file("{$*CWD}/README.md","README");

    }

  }

Pipeline.new.run;
```

In this example child job copy file back to a parent job using `put-file` method:

* `put-file($file-path,$file-name)`

Where `$file-path` is a physical file path within file system and `$file-name` - just a name
how file will be accessible by other jobs. 

So when a file gets copied, a parent job will access it as:

* `get-file($file-name)` method which return a content (*) of a file.

```raku
my $data = $job->get-file("data.tar.gz");
```

`*` - content will be returned as a binary string by default

---

To force text mode, use `:text` modifier:

```raku
my $text = $job->get-file: "README.md", :text;
```


## Class API

For OOP lovers there is a Sparky::JobApi::Role that implements some Sparky::JobApi-ish methods,
so one can write scenarios in OOP style:


```raku
use Sparky::JobApi;

class Pipeline

  does Sparky::JobApi::Role

  {

    method stage-main {

      my $j = self.new-job: :project<spawned_011>;

      $j.queue({
        description => "spawned job. 01", 
        tags => %(
          stage => "child",
        ),
      });

      say "job info: ", $j.info.perl;

      my $st = self.wait-job($j);
  
      say $st.perl;

      die if $st<FAIL>;

    }

    method stage-child {

      say "I am a child scenario";
      say "config: ", config().perl;
      say "tags: ", tags().perl;

    }

  }

Pipeline.new.run;
```

To run pipeline:

```bash
sparrowdo --localhost --no_sudo --with_sparky --tags=stage=main
```

Sparky::JobApi::Role methods:

* `new-job(params)`

Wrapper around Sparky::JobApi.new, takes the same parameters and return an instance of Sparky::JobApi class

* `wait-jobs(@jobs,%args?)`

Wait jobs and return state as Raku hash:

```raku
%(
  OK => $number-of-successfully-finished jobs,
  FAIL => $number-of-failed jobs,
)
```

To set timeout for making http request to get job statues, use `%args`:

```raku
  self.wait-jobs(@jobs, %( timeout => 10));
```

To enable debug mode:

```raku
  self.wait-jobs(@jobs, %( debug => True));
```

* `wait-job($job,%args?)`

The same as `wait-jobs(@jobs,%args?)`, but for a single job

## Cluster jobs

One can have more then one Sparky instances and run jobs across them.

This feature is called cluster jobs:

```raku
use Sparky::JobApi;

if tags()<stage> eq "main" {
  my $j = Sparky::JobApi.new(:api<http://sparrowhub.io:4000>);
  $j.queue({
    description => "child job"
    tags => %(
      stage => "child"
    )
  });
}
```

The code above will run job on sparky instance located at `http://sparrowhub.io:4000` address.

All what has been said before applies to cluster jobs, they are no different from your
local Sparky jobs.

For example one can run cluster on docker instance `alpine-with-raku` running on remote Sparky server:

```raku
  my $j = Sparky::JobApi.new(:api<http://sparrowhub.io:4000>);
  $j.queue({
    description => "child job"
    tags => %(
      stage => "child"
    ),
    sparrowdo => %(
      docker => "alpine-with-raku",
      no_sudo => True
    ),
  });
```

For security reason Sparky server calling jobs on another Sparky server need to have the same
security token. 

Set up `~/sparky.yaml` file on both local and remote Sparky servers:

```yaml
SPARKY_API_TOKEN: secret123456
```

`SPARKY_API_TOKEN` should be any random string. 

Apparently one can have many Sparky servers logically combined into a cluster, and
all servers within a group can run remote jobs on each other, the only requirement
is they all have to share the same `SPARKY_API_TOKEN`

For now `http/https` protocol are supported for cluster jobs URLs. 

See also "SSL support" section.
