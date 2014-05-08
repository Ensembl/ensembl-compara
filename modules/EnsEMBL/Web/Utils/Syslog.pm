package EnsEMBL::Web::Utils::Syslog;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(syslog);

use SiteDefs;

sub syslog {
  my ($str) = @_;

  my $cmd = $SiteDefs::SYSLOG_COMMAND; 
  return unless $cmd;
  if(ref($cmd) eq 'CODE') {
    $cmd->($str);
  } else {
    $cmd =~ s/\[\[TEXT\]\]/$str/g;
    system($cmd);
  }
}

1;

