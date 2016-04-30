#
# Cookbook Name:: rsynced
# Recipe:: default
#
# All rights reserved - Do Not Redistribute
#
# Back up all data from a laptop/desktop by rsync'ing the data to another host.


def assert(condition, message)
  unless condition
    Chef::Application.fatal!(message)
  end
end


def get_ipv6(hostname)
  host = search(:node, "name:#{hostname}").pop
  assert(host, "Could not find host `#{hostname}`.")
  interface = host['network']['default_inet6_interface']
  addresses = host['network']['interfaces'][interface]['addresses']
  address = addresses.select { |addr, spec|
    spec['family'] == 'inet6' and spec['scope'] == 'Global'
  }.keys.pop
  assert(address, "Couldn't find ipv6 address for `#{hostname}`")
  return address
end


def get_or_create_rsa(keypath)
  if File.exist?(keypath)
    privkey = File.read("#{keypath}").strip()
    pubkey = File.read("#{keypath}.pub").strip()
  else
    chef_gem 'sshkey'
    require 'sshkey'
    sshkey = SSHKey.generate(type: 'RSA', comment: "rsynced key")
    privkey = sshkey.private_key
    pubkey = sshkey.ssh_public_key
  end
  return privkey, pubkey
end


node['rsynced']['laptops'].each do |laptop|

  # Verify inputs
  assert(laptop['username'], "Missing user to use for rsync.")
  assert(!laptop['directories'].empty?, "Missing directories to backup.")
  assert(laptop['target']['directory'], "Missing backup destination directory.")
  assert([laptop['target']['host'], laptop['target']['ip']].one?,
         "Need either host or ip but not both.")
  assert(!laptop['schedule'].empty?, "Need a schedule.")


  # Generate a RSA key if needed
  username = laptop['username']
  ssh_dir = "/home/#{username}/.ssh"
  keypath = "#{ssh_dir}/id_rsa_rsynced"
  privkey, pubkey = get_or_create_rsa(keypath)
  directory ssh_dir do
    owner username
    group 'root'
    mode 00700
  end
  file keypath do
    content privkey
    mode '0600'
    owner username
  end
  file "#{keypath}.pub" do
    content pubkey
    mode '0644'
    owner username
  end


  # Push RSA public key to the user data bag
  user = data_bag_item('users', username)
  assert(user, "Could not find databag `users.#{user}`.")
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


  # Set up cron job
  if laptop['target']['host']
    ipaddr = get_ipv6(laptop['target']['host'])
  else
    ipaddr = laptop['target']['ip']
  end
  idempotence = "pgrep rsync ||"
  nice = "/usr/bin/nice -n 19"
  ionice = "/usr/bin/ionice -c2 -n7"
  rsync = "/usr/bin/rsync -azH --exclude=\".*\" --delete"
  ssh = "-e 'ssh -i #{keypath}'"
  dirs = laptop['directories'].join(' ')
  target = "[#{ipaddr}]:#{laptop['target']['directory']}"
  cron 'install backup cron' do
    time    laptop['schedule']['time']
    minute  laptop['schedule']['minute']
    hour    laptop['schedule']['hour']
    day     laptop['schedule']['day']
    month   laptop['schedule']['month']
    weekday laptop['schedule']['weekday']
    user    username
    command "#{idempotence} #{nice} #{ionice} #{rsync} #{ssh} #{dirs} #{target}"
  end


  # Set up canary file to identify breakage in the pipeline
  require 'date'
  laptop['directories'].each do |directory|
    file "#{directory}/.rsynced.canary" do
      content DateTime.now().to_s
      mode '0600'
      owner username
    end
  end

end
