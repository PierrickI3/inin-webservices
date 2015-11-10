# == Class: webservices
#
# Installs and configures ININ Web Services
#
# === Parameters
#
# [*ensure*]
#   Only installed is supported at this time
#
# [*targetchatworkgroup*]
#   Default workgroup to queue chats
#
# [*targetcallbackworkgroup*]
#   Default workgroup to queue callbacks
#
# === Examples
#
#  class { 'webservices':
#    ensure                  => installed,
#    targetchatworkgroup     => 'Marketing',
#    targetcallbackworkgroup => 'Marketing',
#  }
#
# === Authors
#
# Pierrick Lozach <pierrick.lozach@inin.com>
#
# === Copyright
#
# Copyright 2015 Interactive Intelligence, Inc.
#
class webservices (
  $ensure = installed,
  $targetchatworkgroup,
  $targetcallbackworkgroup,
){
  $daascache        = 'C:/daas-cache/'
  $installfilespath = 'C:/I3/IC/Install/IC Web Services Chat Files'
  $configurationzip = 'IWT_Configuration-3-0'
  $exampleszip      = 'IWT_Examples-3-0'
  $i3rootzip        = 'IWT_I3Root-3-0'

  if ($::operatingsystem != 'Windows')
  {
    err('This module works on Windows only!')
    fail('Unsupported OS')
  }

  $cache_dir = hiera('core::cache_dir', 'c:/users/vagrant/appdata/local/temp') # If I use c:/windows/temp then a circular dependency occurs when used with SQL
  if (!defined(File[$cache_dir]))
  {
    file {$cache_dir:
      ensure   => directory,
      provider => windows,
    }
  }

  ######################
  # URL REWRITE MODULE #
  ######################

  # Download URL Rewrite module
  exec {'Download URL Rewrite module':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('http://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi','${cache_dir}/rewrite_amd64.msi')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  # Install URL Rewrite module
  package {'Install URL Rewrite module':
    ensure          => installed,
    source          => "${cache_dir}/rewrite_amd64.msi",
    install_options => [
      '/l*v',
      'c:\\windows\\logs\\rewrite_amd64.log',
    ],
    provider        => 'windows',
    require         => Exec['Download URL Rewrite module'],
  }

  ###############################
  # Application Request Routing #
  ###############################

  # Download Microsoft Application Request Routing Version 3 for IIS
  exec {'Download Microsoft Application Request Routing V3':
    command  => "\$wc = New-Object System.Net.WebClient;\$wc.DownloadFile('http://download.microsoft.com/download/E/9/8/E9849D6A-020E-47E4-9FD0-A023E99B54EB/requestRouter_amd64.msi','${cache_dir}/requestRouter_amd64.msi')",
    path     => $::path,
    cwd      => $::system32,
    timeout  => 900,
    provider => powershell,
  }

  # Install the Microsoft Application Request Routing Version 3 for IIS
  package {'Microsoft Application Request Routing V3':
    ensure          => installed,
    source          => "${cache_dir}/requestRouter_amd64.msi",
    install_options => [
      '/l*v',
      'c:\\windows\\logs\\requestRouter_amd64.log',
    ],
    provider        => 'windows',
    require         => Exec['Download Microsoft Application Request Routing V3'],
  }

  ##########
  # I3ROOT #
  ##########

  # Create I3Root folder in wwwroot
  file { 'C:/inetpub/wwwroot/I3Root':
    ensure  => directory,
    require => [
      Package['Microsoft Application Request Routing V3'],
      Package['Install URL Rewrite module'],
    ],
  }

  # Create Configuration folder
  file { "C:/inetpub/wwwroot/I3Root/${configurationzip}":
    ensure  => directory,
    require => File['C:/inetpub/wwwroot/I3Root'],
  }

  # Unzip configuration zip file
  unzip {'Unzip Configuration File':
    name        => "${installfilespath}/${configurationzip}.zip",
    destination => "c:/inetpub/wwwroot/I3Root/${configurationzip}",
    creates     => "c:/inetpub/wwwroot/I3Root/${configurationzip}/configuration.html",
    require     => File['C:/inetpub/wwwroot/I3Root'],
  }

  # Create Examples folder
  file { "C:/inetpub/wwwroot/I3Root/${exampleszip}":
    ensure  => directory,
    require => File['C:/inetpub/wwwroot/I3Root'],
  }

  # Unzip examples zip file
  unzip {'Unzip Examples File':
    name        => "${installfilespath}/${exampleszip}.zip",
    destination => "c:/inetpub/wwwroot/I3Root/${exampleszip}",
    creates     => "c:/inetpub/wwwroot/I3Root/${exampleszip}/BypassLoginForm/index.html",
    require     => File['C:/inetpub/wwwroot/I3Root'],
  }

  # Unzip I3Root zip file
  unzip {'Unzip I3Root File':
    name        => "${installfilespath}/${i3rootzip}.zip",
    destination => "c:/inetpub/wwwroot/I3Root/${i3rootzip}",
    creates     => "c:/inetpub/wwwroot/I3Root/${i3rootzip}/index.html",
    require     => File['C:/inetpub/wwwroot/I3Root'],
  }

  # Copy the I3Root files to I3Root
  exec {'Copy I3Root Files':
    command  => "Copy-Item c:\\inetpub\\wwwroot\\I3Root\\${i3rootzip}\\* C:\\inetpub\\wwwroot\\I3Root\\ -Recurse -Force",
    provider => powershell,
    require  => Unzip['Unzip I3Root File'],
  }

  #####################
  # CIC Configuration #
  #####################

  # Create workgroup with ACD, chat and callback enabled?

  # Enable HTTP in Web Services configuration (registry)

  ##################
  # Config.js file #
  ##################

  file {'C:/inetpub/wwwroot/I3Root/js/config.js':
    ensure  => present,
    content => template('webservices/config.js.erb'),
    require => Exec['Copy I3Root Files'],
  }

  # Restart WebProcessorBridge (TODO create custom handler)

  #####################
  # IIS Configuration #
  #####################

  # Create Server1 subfolder
  file {'C:/inetpub/wwwroot/I3Root/Server1':
    ensure  => directory,
    require => File['C:/inetpub/wwwroot/I3Root'],
  }

  # Copy web.config
  file {'C:/inetpub/wwwroot/I3Root/Server1/web.config':
    ensure  => present,
    content => template('webservices/proxyserver.config.erb'),
    require => File['C:/inetpub/wwwroot/I3Root/Server1'],
  }
}
