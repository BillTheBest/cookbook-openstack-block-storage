#
# Cookbook Name:: cinder
# Recipe:: volume
#
# Copyright 2012, Rackspace US, Inc.
# Copyright 2012, AT&T, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ::Chef::Recipe
  include ::Openstack
end

if node["cinder"]["syslog"]["use"]
  include_recipe "openstack-common::logging"
end

platform_options = node["cinder"]["platform"]

platform_options["cinder_volume_packages"].each do |pkg|
  package pkg do
    options platform_options["package_overrides"]

    action :upgrade
  end
end

platform_options["cinder_iscsitarget_packages"].each do |pkg|
  package pkg do
    options platform_options["package_overrides"]

    action :upgrade
  end
end

db_user = node["cinder"]["db"]["username"]
db_pass = db_password "cinder"
sql_connection = db_uri("volume", db_user, db_pass)

rabbit_server_role = node["cinder"]["rabbit_server_chef_role"]
rabbit_info = config_by_role rabbit_server_role, "queue"

rabbit_user = node["cinder"]["rabbit"]["username"]
rabbit_pass = user_password "rabbit"
rabbit_vhost = node["cinder"]["rabbit"]["vhost"]

glance_api_role = node["cinder"]["glance_api_chef_role"]
glance = config_by_role glance_api_role, "glance"
glance_api_endpoint = endpoint "image-api"

node.override["cinder"]["netapp"]["dfm_password"] = service_password "netapp"

service "cinder-volume" do
  service_name platform_options["cinder_volume_service"]
  supports :status => true, :restart => true

  action [ :enable, :start ]
end

template "/etc/cinder/cinder.conf" do
  source "cinder.conf.erb"
  group  node["cinder"]["group"]
  owner  node["cinder"]["user"]
  mode   00644
  variables(
    :sql_connection => sql_connection,
    :rabbit_ipaddress => rabbit_info["host"],
    :rabbit_user => rabbit_user,
    :rabbit_password => rabbit_pass,
    :rabbit_port => rabbit_info["port"],
    :rabbit_virtual_host => rabbit_vhost,
    :glance_host => glance_api_endpoint.host,
    :glance_port => glance_api_endpoint.port
  )

  notifies :restart, "service[cinder-volume]"
end

service "iscsitarget" do
  service_name platform_options["cinder_iscsitarget_service"]
  supports :status => true, :restart => true

  action :enable
end

template "/etc/tgt/targets.conf" do
  source "targets.conf.erb"
  mode   00600

  notifies :restart, "service[iscsitarget]", :immediately
end

cookbook_file "/usr/share/pyshared/cinder/openstack/common/fileutils.py" do
  source "fileutils_new-b322585613c21067571442aaf9e4e6feb167832b.py"
  mode  00644
  owner "root"
  group "root"
end

link "/usr/lib/python2.7/dist-packages/cinder/openstack/common/fileutils.py" do
  to  "/usr/share/pyshared/cinder/openstack/common/fileutils.py"
end

cookbook_file "/usr/share/pyshared/cinder/openstack/common/gettextutils.py" do
  source "gettextutils_new-8e450aaa6ba1a2a88f6326c2e8d285d00fd28691.py"
  mode  00644
  owner "root"
  group "root"
end

cookbook_file "/usr/share/pyshared/cinder/openstack/common/lockutils.py" do
  source "lockutils_new-6dda4af1dd50582a0271fd6c96044ae61af9df7e.py"
  mode  00644
  owner "root"
  group "root"
end

link "/usr/lib/python2.7/dist-packages/cinder/openstack/common/lockutils.py" do
  to "/usr/share/pyshared/cinder/openstack/common/lockutils.py"
end

cookbook_file node["cinder"]["netapp"]["driver"] do
  source "netapp_new-42cdc4d947a73ae6a3dbbaab36634e425b57c18c.py"
  mode  00644
  owner "root"
  group "root"
  notifies :restart, "service[cinder-volume]"
end
