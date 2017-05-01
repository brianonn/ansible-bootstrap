
# ansible-bootstrap

This is a bootstrap installer for Ansible.  It can be used to install a standalone `ansible` and `ansible-playbook` for use in local mode. There are some example playbooks in the directory **sample-playbooks**. The following example will ask the user for the `sudo` password and then run `whoami`. 
```bash
$ ansible-playbook -i localhost, -c local \
	--ask-become-pass sample-playbook/whoami.yml
```
if you don't want to see the cows from `cowsay` then set the environment variable first to
```bash
export ANSIBLE_COW_SELECTION=no
```

### For Linux

1. Run the script `bootstrap.sh` with sudo: 
```bash 
sudo -H bootstrap.sh
```


### For OS X 10.9 or later

1. Download the latest version of Xcode from the [Apple Developer Website](WWW) or get it using the [Apple Store](https://itunes.apple.com/us/app/xcode/id497799835).  Once you have Xcode installed, open a terminal window and run `xcode-select --install`. Click the install button to install the command line tools. If you see a message telling you that the software cannot be installed because it is not currently available, this usually means that the software is already installed and at the latest version.  You can also get the command line tools via the Apple Store.
2. Run the script `bootstrap.sh` with sudo as the root user: 
```bash 
sudo -H bootstrap.sh
```

### For FreeBSD
FreeBSD support is coming soon!

### License
This code is copyright Brian A. Onn and licensed with the MIT license. See the file **LICENSE.md**


