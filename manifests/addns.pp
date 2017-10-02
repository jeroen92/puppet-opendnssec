# == Class: opendnssec
#
define opendnssec::addns (
  Array[String] $masters      = [],
  Array[String] $provide_xfrs = [],
) {

  include ::opendnssec
  $user               = $::opendnssec::user
  $group              = $::opendnssec::group
  $manage_ods_ksmutil = $::opendnssec::manage_ods_ksmutil
  $enabled            = $::opendnssec::enabled
  $remotes            = $::opendnssec::remotes
  $remotes_dir        = $::opendnssec::remotes_dir
  $tsigs_dir          = $::opendnssec::tsigs_dir
  $xferout_enabled    = $::opendnssec::xferout_enabled
  $default_tsig_name  = $::opendnssec::default_tsig_name

  $masters.each |String $master| {
    if ! defined(Opendnssec::Remote[$master]) {
      fail("addns-${name}: Opendnssec::Remote['${master}'] doesn't exist")
    }
  }
  $provide_xfrs.each |String $provide_xfr| {
    if ! defined(Opendnssec::Remote[$provide_xfr]) {
      fail("addns-${name}: Opendnssec::Remote['${provide_xfr}'] doesn't exist")
    }
  }

  file { "/etc/opendnssec/addns-${name}.xml":
    owner   => $user,
    group   => $group,
    content => template('opendnssec/etc/opendnssec/addns.xml.erb'),
  }
  if $manage_ods_ksmutil and $enabled {
    exec {"Forcing ods-ksmutil to update after modifying addns-${name}.xml":
      command     => '/usr/bin/yes | /usr/bin/ods-ksmutil update all',
      user        => $user,
      refreshonly => true,
      subscribe   => File["/etc/opendnssec/addns-${name}.xml"],
    }
  }
}
