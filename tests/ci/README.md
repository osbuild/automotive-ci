# Tests

This directory contains the configuration, scripts, and files for building an
image using the "RHEL for Edge" tools, and to test the result.

For running this part of the CI pipeline, we use [tmt](https://tmt.readthedocs.io/en/stable/overview.html#overview),
which allow us to integrate easily with Testing Farm and define "_portable_"
CI pipelines.

It also allows us to run the pipeline locally, in a virtual machine or remote
server, which makes the developing and debugging much easier.

## Structure

The tests and provisioning scripts are located under the `tests/ci/` directory:


```shell
tests/
└── ci
    ├── clean_up.sh
    ├── create-commit.sh
    ├── files
    │   ├── blueprint.toml
    │   ├── centos-stream-8.json
    │   ├── copr_neptune_tmpl.toml
    │   ├── integration-net.xml
    │   ├── ks_tmpl.cfg
    │   ├── rhel-8-4-0-os-release
    │   └── rhel-8-4-0-rh-release
    ├── image-build.fmf
    ├── install-vm.sh
    ├── README.md
    ├── setup.sh
    └── test-vm.sh
```

The file that describes the CI pipeline is `image-build.fmf`. There is the
definition of the steps, the order, how to prepare the environment, how to
clean up after it finishes and some environment variables defined.

All the templates and files to be copied at the directory `tests/ci/files`.

## How to run locally the CI pipelines

**IMPORTANT**: The tests will install and change some things in the host,
so it's not recommended to run it in your own machine or production host.

To run the tests locally you need to have `tmt` installed. The command `tmt`
can run the provisioning and the tests in the same machine, in another
(via `ssh`) or in a virtual machine. This last option is the default option.

### In a fresh virtual machine

You can run the tests inside a virtual machine (VM), by running the following:

```shell
tmt run -a -vvv \
    tests --filter 'tag:-aws' \
    provision --how virtual \
    --image http://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-20210603.0.x86_64.qcow2 \
    --memory 8192 \
    --disk 60
```

The `provision --how virtual` makes sure it runs in a VM. But the default
option is a Fedora VM. To force it to use **CentOS Stream 8** you'll need
to indicate a Centos Stream 8 image.

To be able to run some of the steps, you'll need at least 8 GB of RAM and
around 60 Gb of disk. The previous command takes care of all those limits.

Notice the filter used: `tests --filter 'tag:-aws'`
You'll need to use this if you want to run this locally and without uploading
any artifact to AWS (S3).
In case you'd like to upload the artifact(s) and you have valid credentials, you
can do it passing them as the section "_Passing ENV variables_" indicates.

**NOTE**: For using the `virtual` provisioner you should install the `tmt-all`
package.

### In a CentOS 8 or CentOS Stream 8 machine

It also can run in the same machine, but it needs to be CentOS 8 or CentOS
Stream 8. It doesn't matter if the machine is virtual (like with Vagrant or
libvirt), or if it's a bare-metal, but it needs to be able to run virtual
machines inside.

The steps to run the tests are:

1. Connect to the machine you want to use.
1. Make sure you have `tmt` and `git` installed (`dnf install -y tmt git`)
1. Clone this repo: `git clone https://github.com/osbuild/automotive-ci.git`
1. Run `tmt` locally with the following command:

```shell
tmt run -a -vvv tests --filter 'tag:-aws' provision --how local
```

### In a remote machine

In order to run it on a remote machine you just need to have `tmt` installed
locally and `ssh` access to the remote machine. And that remote machine needs
to run on CentOS 8 or CentOS Stream 8.

To run the scripts remotely you need to run the following:

```shell
tmt run -a -vvv tests --filter 'tag:-aws' provision --how connect --guest $REMOTE_SERVER --key ~/.ssh/id_rsa
```

That command will run the scripts on the `$REMOTE_SERVER` using the user `root`
and the ssh key `~/.ssh/id_rsa`, but you can also use user and password:

```shell
tmt run -a -vvv tests --filter 'tag:-aws' provision --how connect --guest $REMOTE_SERVER --user myuser --password secret
```

### Debug when something fails

All the previous examples have the flag `-v` (verbose) but with 3 `v`, which
means more verbose. That is very useful to see what is happening.

But sometimes, you'll need to debug what went wrong. `tmt` will call the
`clean_up` script when something fails and you want to be able to explore.
To be able to explore and debug you have the command `login` and you can
use it as follows to debug in case something fails.

```shell
tmt run -a -vvv tests --filter 'tag:-aws' provision --how local login --step execute --when fail
```

### Passing ENV variables

Sometimes you'll need to pass an ENV variable to the scripts, you can do it
with the option `-e` or `--environment`. It can be used multiple times,
but it's important to put it before the command `provision`:

```shell
tmt run -a -vvv -e AWS_ACCESS_KEY_ID=secret_key_id -e AWS_SECRET_ACCESS_KEY=secret_key provision --how local
```

## Learning more about tmt

This document just shows the minimal information needed to run this tests,
but `tmt` allows you much more options.

To know more about it, check the official documentation:
https://tmt.readthedocs.io/en/latest/

