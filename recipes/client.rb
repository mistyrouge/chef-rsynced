#
# Cookbook Name:: rsynced
# Recipe:: default
#
# All rights reserved - Do Not Redistribute
#

# Check inputs
username = node['rsynced']['client']['user']
unless username
    Chef::Application.fatal!("You need to specify a user to use for rsync.")
end
directories = node['rsynced']['client']['directories'].join(' ')
unless directories
    Chef::Application.fatal!("You need to specify directories to backup.")
end
target_name = node['rsynced']['client']['target']
unless target_name
    Chef::Application.fatal!("You need to specify a target node to backup to.")
end
target_hosts = search(:node, "name:#{target_name}")
unless target_hosts
    Chef::Application.fatal!("Could not find host `#{target_host}`")
end
target_host = target_hosts[0]



user = data_bag_item('users', username)
keypath = "/home/#{username}/.ssh/id_rsa_rsynced"

if File.exist?(keypath)
    # Make sure the key fingerprint is correct
    pubkey = File.read("#{keypath}.pub").strip()
else
    # Generate new ssh Key
    chef_gem 'sshkey'
    require 'sshkey'
    sshkey = SSHKey.generate(type: 'RSA', comment: "#{username}'s backup")
    pubkey = sshkey.ssh_public_key

    group user['groups'][0] do
        action :create
        members user['id']
        append true
    end
    directory "/home/#{username}/.ssh" do
        owner user['id']
        group user['groups'][0]
        mode 00700
    end
    file keypath do
        content sshkey.private_key
        mode '0600'
        owner user['id']
    end
    file "#{keypath}.pub" do
        content pubkey
        mode '0644'
        owner username
    end
end


# Push public key to chef
cli = [
    "command=\"/usr/local/bin/rrsync ~/\"",
    "no-agent-forwarding",
    "no-port-forwarding",
    "no-pty",
    "no-user-rc",
    "no-X11-forwarding",
].join(',')

entry = "#{cli} #{pubkey}"
user['ssh_keys'] = [] unless user['ssh_keys']
user['ssh_keys'].push(entry) unless user['ssh_keys'].include? entry
user.save


# Find ipv6 of the destination
address = nil
target_interface = target_host['network']['default_inet6_interface']
addresses = target_host['network']['interfaces'][target_interface]['addresses']
addresses.each do |addr, spec|
    if spec['family'] == 'inet6' and spec['scope'] == 'Global'
        address = addr
    end
end
unless address
    Chef::Application.fatal!("Couldn't find ipv6 address for `#{target_host}`")
end


# Set up rsync cron
idempotence = "pgrep rsync ||"
nice = "/usr/bin/nice -n 19"
ionice = "/usr/bin/ionice -c2 -n7"
rsync = "/usr/bin/rsync -azH --exclude=\".*\" --delete"
ssh = "-e 'ssh -i #{keypath}'"
cron 'install backup cron' do
    minute  node['rsynced']['client']['minute']
    hour    node['rsynced']['client']['hour']
    weekday node['rsynced']['client']['weekday']
    mailto  user['email'] if user['email']
    user    username
    command "#{idempotence} #{nice} #{ionice} #{rsync} #{ssh} #{directories} [#{address}]:data/"
end
