# Vagrant Templates

The point of this repository is to hold `Vagrantfile` templates that I personally use as starting points for self-contained development/testing environments.

These are not minimal templates. They include configuration tweaks, **workarounds** for common issues that I bumped into, and provisioning scripts that install a few extra packages and customize the shell environment a bit. Check the appropriate `Vagrantfile` and the `vagrant/provision.sh` script, they should be fairly easy to modify. Some usage examples:

  * Use them _as is_ to spin up readily usable VMs where you can log into and test random stuff.
  * Add the necessary steps to provision your application inside the VM, maybe removing some redundant things.
  * Just use them as a reference to write your own minimal environments with tweaked settings.

Most of these templates default to [bento](http://chef.github.io/bento/)-based boxes for convenience (i.e. pre-installed guest additions).

## Dependencies

You'll need [VirtualBox](https://www.virtualbox.org/) and [Vagrant](https://www.vagrantup.com/). Some templates may ask to install the `vagrant-vbguest` plugin (to share folders with the host) on `vagrant up` if they need it.

### Host-Only Networking

Starting with version 6.1.28, VirtualBox restricts the address ranges usable in [host-only networks](https://www.virtualbox.org/manual/ch06.html#network_hostonly) which causes `vagrant up` to fail as it tries to create an host-only network using a disallowed address range. This requires manual intervention in VirtualBox before the first ever `vagrant up` on the host:

On **unix-like hosts**, go to `File -> Host Network Manager` and create the `vboxnet0` network if it doesn't already exist, also making sure it has the DHCP server enabled (default).

On **Windows hosts** go to `File -> Tools -> Network Manager`, select the `Host-only Networks` tab and remove the existing "VirtualBox Host-Only Ethernet Adapter" entry. It will be automatically recreated with the necessary settings on `vagrant up`.

### Local Customization

The default VM size is defined in the `Vagrantfile` but, sometimes, it's useful to locally override these settings without affecting other users of the same repo. Do this by creating a `.vagrant_size.json` next to the `Vagrantfile` with the following (example) contents:

```json
{
    "cpus": 2,
    "memory": 4096
}
```

### Guest Additions

By default, the `vagrant-vbguest` plugin tries to install/update the VirtualBox Guest Additions on every `vagrant up`. I find this annoying and recommend you to disable this behavior by adding something like the following to your `~/.vagrant.d/Vagrantfile`:

```ruby
Vagrant.configure(2) do |config|
    ...

    if Vagrant.has_plugin?("vagrant-vbguest")
        config.vbguest.auto_update = false
        config.vbguest.allow_downgrade = false
    end

    ...
end
```

The templates that need to install/update the VirtualBox Guest Additions already (re)enable `auto_update` explicitly.

### Clock Drift

On older machines, the (VM) clocks may drift quite significantly with paravirtualization enabled. This is unlikely to happen nowadays but, if it does, add the following to your `~/.vagrant.d/Vagrantfile`:

```ruby
Vagrant.configure(2) do |config|
    ...

    config.vm.provider "virtualbox" do |v, override|
        v.customize ["modifyvm", :id, "--paravirtprovider", "legacy"]
    end

    ...
end
```
