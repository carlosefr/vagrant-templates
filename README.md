# Vagrant Templates

The point of this repository is to hold `Vagrantfile` templates that I personally use as starting points for self-contained development/testing environments.

These are not minimal templates. They include configuration tweaks, **workarounds** for common issues that I bumped into, and provisioning scripts that install a few extra packages and customize the shell environment a bit. Check the appropriate `Vagrantfile` and the `vagrant/provision.sh` script, they should be fairly easy to modify. Some usage examples:

  * Use them _as is_ to spin up readily usable VMs where you can log into and test random stuff.
  * Add the necessary steps to provision your application inside the VM, maybe removing some redundant things.
  * Just use them as a reference to write your own minimal environments with tweaked settings.

## Dependencies

You'll need [VirtualBox](https://www.virtualbox.org/) and [Vagrant](https://www.vagrantup.com/). Most templates require the `vagrant-vbguest` plugin installed (to share folders with the host) and som also require the `vagrant-reload` plugin (to allow the VM to be immediately rebooted after provisioning).

## Notes

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
    end

    ...
end
```
The templates that need to install/update the VirtualBox Guest Additions already (re)enable `auto_update` explicitly.

### Clock Drift

On my older Macbook Pro the (VM) clocks drift quite significantly with paravirtualization enabled, and I never quite figured out how to fix it. If you notice this happening, just add the following to your `~/.vagrant.d/Vagrantfile`:
```ruby
Vagrant.configure(2) do |config|
    ...

    config.vm.provider "virtualbox" do |v, override|
        v.customize ["modifyvm", :id, "--paravirtprovider", "legacy"]
    end

    ...
end
```
