# Debian 13

To start, read the [official release notes](https://www.debian.org/releases/trixie/release-notes/upgrading.en.html).

If your install fits into "vanilla Debian plus maybe a handful of 3rd-party repos", then this guide for a simple upgrade to Debian 13 "trixie" from Debian 12 "bookworm" can be helpful. 3rd-party repos are handled with a find command.

Note upgrade is only supported from Debian 12 to Debian 13. If you are on Debian 11, [upgrade to Debian 12](https://gist.github.com/yorickdowne/ec9e2c6f4f8a2ee93193469d285cd54c) first. Then once on Debian 12, you can upgrade to Debian 13.

> This guide is only for the OS itself. Applications are as plentiful as sand on the beach, and they may all require additional steps. Plan for that.

- Check free disk space

`df -h`

5 GiB free is a conservative amount. `sudo apt clean` and `sudo apt autoremove` can be used to free some disk space.

On a server with only docker installed, even 1 GiB free was sufficient. Do err on the side of caution here, however.

- Identify any 3rd-party repos that may need to be updated. They'll be changed with a `find` command, below.

`ls /etc/apt/sources.list.d`

- Update current distribution

`sudo apt-get update && sudo apt-get dist-upgrade --autoremove -y`

If this brought in a new kernel, `sudo reboot` - otherwise continue

- Change repo to trixie, from bookworm.

```
sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
```

- Change all 3rd-party repos

> This assumes the repos have trixie versions. Run `sudo apt update` after the change to trixie to confirm, and deal with any repos that aren't available in trixie.

```
sudo find /etc/apt/sources.list.d -type f -exec sed -i 's/bookworm/trixie/g' {} \;
```

- Update Debian

For the following, say Yes to restarting services, and keep existing config files when prompted.

`sudo apt-get update && sudo apt-get dist-upgrade --autoremove -y`

And finally, reboot

`sudo reboot`

- Modernize Debian sources

Optional but recommended: Switch to `deb822` format for the `sources.list`. This will write `/etc/apt/sources.list.d/debian.sources` and `/etc/apt/sources.list.d/debian-backports.sources`

`sudo apt modernize-sources`

> Caveat that trixie-backports won't have a `Signed-By` until trixie has been released. You can fix this by manually setting `Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg` in `/etc/apt/sources.list.d/debian-backports.sources`

## Automated by Ansible
Config `ansible.cfg`:
```
[defaults]
interpreter_python = /usr/bin/python3
```

Playbook `trixie.yml`:

```
---
- name: Upgrade to Debian trixie
  hosts: all
  serial: 1
  gather_facts: false
  roles:
    - base/upgrade_trixie
```

Role `base/upgrade_trixie/tasks/main.yml`:

```
---
- name: Get distribution version
  setup:
    filter: ansible_distribution*
- name: Skip if not Debian 12
  meta: end_host
  when: ansible_distribution != 'Debian' or ansible_distribution_major_version != '12'
- name: apt clean
  apt:
    clean: yes
  become: yes
- name: Get filesystem facts
  setup:
    filter: ansible_mounts
- name: Fail if free space on / is below 5 GiB
  ansible.builtin.assert:
    that:
      - item.size_available > (5 * 1024 * 1024 * 1024)
    fail_msg: "Free disk space on {{ item.mount }} is below 5 GiB"
  loop: "{{ ansible_mounts }}"
  when: item.mount == "/"
- name: All apt packages up to date
  apt:
    upgrade: dist
    update_cache: yes
  become: yes
- name: apt autoremove
  apt:
    autoremove: yes
  become: yes
- name: apt clean
  apt:
    clean: yes
  become: yes
- name: Check if reboot required
  ansible.builtin.stat:
    path: /run/reboot-required
    get_checksum: no
  register: reboot_required_file
- name: Reboot if required
  ansible.builtin.reboot:
    msg: "Reboot initiated by Ansible"
    connect_timeout: 5
    reboot_timeout: 600
    pre_reboot_delay: 0
    post_reboot_delay: 60
    test_command: whoami
  when: reboot_required_file.stat.exists
  become: true
- name: Switch OS from bookworm to trixie
  ansible.builtin.replace:
    path: /etc/apt/sources.list
    regexp: 'bookworm'
    replace: 'trixie'
  become: yes
- name: Find all 3rd-party repos
  ansible.builtin.find:
    paths: /etc/apt/sources.list.d
    patterns: '*'
    recurse: no
  register: third_party_repos
- name: Switch 3rd-party repos from bookworm to trixie
  ansible.builtin.replace:
    path: "{{ item.path }}"
    regexp: 'bookworm'
    replace: 'trixie'
  loop: "{{ third_party_repos.files }}"
  loop_control:
    label: "{{ item.path }}"
  become: yes 
- name: Use apt to move to trixie
  apt:
    upgrade: dist
    update_cache: yes
  become: yes
- name: Get distribution version
  setup:
    filter: ansible_distribution*
- name: Fail if not Debian 13
  assert:
    that:
      - ansible_distribution_major_version == '13'
    fail_msg: "Upgrade to Debian 13 failed"
- name: apt autoremove
  apt:
    autoremove: yes
  become: yes
- name: apt clean
  apt:
    clean: yes
  become: yes
- name: Reboot on trixie
  ansible.builtin.reboot:
    msg: "Reboot initiated by Ansible"
    connect_timeout: 5
    reboot_timeout: 600
    pre_reboot_delay: 0
    post_reboot_delay: 60
    test_command: whoami
  become: yes
- name: Modernize apt sources
  ansible.builtin.command:
    cmd: apt -y modernize-sources
  become: yes
- name: Pause for 5 minutes for staggered upgrades
  pause:
    minutes: 5
```
