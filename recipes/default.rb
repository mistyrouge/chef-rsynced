#
# Cookbook Name:: rsynced
# Recipe:: default
#
# All rights reserved - Do Not Redistribute
#


package 'rsync'


directories = node['rsynced']['directories'].join(' ')
destination = "#{node['rsynced']['dest_host']}:#{node['rsynced']['dest_dir']}/"
delete = '--delete' if node['rsynced']['delete_remote']
exlude = '--exclude=".*"'
# TODO: Support generating identity file and installing it on the server.
# TODO: Implement monitoring mechanism

cron 'install backup cron' do
    minute  node['rsynced']['minute']
    hour    node['rsynced']['hour']
    weekday node['rsynced']['weekday']
    mailto  node['rsynced']['mailto'] if node['rsynced']['mailto']
    user    node['rsynced']['local_user']
    command "rsync -azH #{directories} #{destination} #{exclude} #{delete}"
end
