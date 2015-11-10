class { 'webservices':
  ensure                  => installed,
  targetchatworkgroup     => 'glance',
  targetcallbackworkgroup => 'glance',
}
