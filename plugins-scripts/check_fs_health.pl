#! /usr/bin/perl

use strict;

eval {
  if ( ! grep /AUTOLOAD/, keys %Monitoring::GLPlugin::) {
    require Monitoring::GLPlugin;
    require Monitoring::GLPlugin::SNMP;
  }
};
if ($@) {
  printf "UNKNOWN - module Monitoring::GLPlugin was not found. Either build a standalone version of this plugin or set PERL5LIB\n";
  printf "%s\n", $@;
  exit 3;
}

my $plugin = Classes::Device->new(
    shortname => '',
    usage => 'Usage: %s [ -v|--verbose ] [ -t <timeout> ] '.
        '--mode <what-to-do> '.
        '  ...]',
    version => '$Revision: #PACKAGE_VERSION# $',
    blurb => 'This plugin checks the availability of a file system ',
    url => 'http://labs.consol.de/nagios/check_fs_health',
    timeout => 60,
);
$plugin->add_mode(
    internal => 'device::fs::write',
    spec => 'check-writable',
    alias => undef,
    help => 'Check if a file system is writable',
);
$plugin->add_mode(
    internal => 'device::fs::read',
    spec => 'check-readable',
    alias => undef,
    help => 'Check if a file system is readable',
);
$plugin->add_mode(
    internal => 'device::fs::free',
    spec => 'check-free',
    alias => undef,
    help => 'Check if a file system has enough free space (and inodes)',
);
$plugin->add_default_args();
$plugin->mod_arg("name",
    help => "--name
   The path name of a file system",
);
$plugin->mod_arg("name2",
    help => "--name2
   The path name of a file (get written or is expected to exist)",
    default => 'check_fs_health.test',
    required => 0,
);
$plugin->add_arg(
    spec => "fstype=s",
    help => "--fsytpe
   The filesystem type of name's mount point. (optional)",
    required => 0,
);
$plugin->add_arg(
    spec => "compat",
    help => "--compat
   Tells the plugin to write the same stupid performance data as check_disk",
    required => 0,
);
#$plugin->add_arg(
#    spec => "speed",
#    help => "--speed
#   Tells the plugin to measure read/write performance",
#    required => 0,
#);
#$plugin->add_arg(
#    spec => "size=i",
#    help => "--size
#   Tells the plugin to write a file of <size>mb",
#    required => 0,
#);
#
$plugin->getopts();
$plugin->classify();
$plugin->validate_args();

if (! $plugin->check_messages()) {
  $plugin->init();
  if (! $plugin->check_messages()) {
    $plugin->add_ok($plugin->get_summary())
        if $plugin->get_summary();
    $plugin->add_ok($plugin->get_extendedinfo(" "))
        if $plugin->get_extendedinfo();
  }
} else {
  $plugin->add_critical('wrong device');
}
my ($code, $message) = $plugin->opts->multiline ?
    $plugin->check_messages(join => "\n", join_all => ', ') :
    $plugin->check_messages(join => ', ', join_all => ', ');
$message .= sprintf "\n%s\n", $plugin->get_info("\n")
    if $plugin->opts->verbose >= 1;
#printf "%s\n", Data::Dumper::Dumper($plugin);

$plugin->nagios_exit($code, $message);
