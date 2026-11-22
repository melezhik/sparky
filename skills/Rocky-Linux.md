# What is Sparky test

Sparky tests allows to test Rocky Linux configurations and installation by using Raku as high level scenario
and tasks written on Bash. 

High level Raku scenario is just a list of tasks, keep it simple:

***main.raku***

```raku
task-run "tasks/prepare";
task-run "tasks/install";
task-run "task/check-install";
```

The scenario should be named "main.raku", every task-run function accepts path to directory
where file "task.bash" should be located. The scenario above just calls three separate tasks
executed one by one.

**tasks/prepare/task.bash**

```bash
set -e
echo "prepare install"
```

**tasks/install/task.bash**

```bash
set -e
sudo dnf update -y
dnf install -y nginx
```

**tasks/check-install/task.bash**

```bash
set -e
curl -f  http://127.0.0.1
```

In other words - tasks.bash is regular Bash script where you can do anything a user would to
install or configure Rocky Linux. In this example one installs nginx. For readably and better
code management one can split big scenario into many tasks and call those tasks from "main.raku"
file using task-run function.


Tasks best practices

* Add `set -e` in the beginning of every task to ensure that task fails fast at the very first error

* Sometimes it's reasonable to add tasks checks when having zero exit code is not enough to ensure test success

* Always make it sure run commands in unattended mode by supplying relevant command line parameters, for example
adding `-y` option will force running dnf install without waiting confirmation from a user:


```bash
dnf install -y nginx
```

# Task checks


Task checks are optional they allow to test tasks stdout adding extra testing capabilities when it's
not enough to rely Bash script exit code to ensure that a test succeeds.

To add task check simple create task.check file in the same directory where task.bash resides

***tasks/check-install/task.bash***

```
Welcome to nginx
```

This task check ensures the curl command used in task.bash emits proper message from Nginx web server


# Task check comprehensive guideline

Following is complete guideline for task check language, use it to create task check of arbitrary complexity

---
