#########
# Author:        jc3
# Maintainer:    $Author$
# Created:       2009-04-09
# Last Modified: $Date$
# Revision: $Revision$
# Id: $Id$

package Website::StopIPs;

use strict;
use warnings;
use Net::DNS;

our $VERSION      = 0.2;
our $DEBUG        = 0;
our @DEFAULT_LIST = qw( zen.dnsbl.ja.net bl.spamcop.net );
# our @DEFAULT_LIST = qw( zen.spamhaus.org bl.spamcop.net );

sub new {
  my $class = shift;
  return bless { 
    'res'   => undef,
    'lists' => @_ ? \@_ : \@DEFAULT_LIST
  }, $class;
}

sub is_blacklisted {
  my ($self, $ips) = @_;

  return 0 unless @{$self->{'lists'}}; ## No lists so safe!

  ## check if $ips needs to be split into more than one.
  $ips             =~ s/\s+//gm; # remove the white space
  my @rev_ips      = map { join q(.), reverse split /\./m, $_ } split /,/, $ips;

  return -1 unless @rev_ips; ## No IPs specified AUTO BLOCK!

  my $blocked      = 0;
  $self->{'res'} ||= Net::DNS::Resolver->new(); ## Lazy load resolver...
  
  for my $rev (@rev_ips) {
    $blocked += grep { 
      defined $self->{'res'}->search("$rev.$_",'A'  ) &&
      defined $self->{'res'}->search("$rev.$_",'TXT')
    } @{$self->{'lists'}};
  }

  return $blocked/@rev_ips/@{$self->{'lists'}};
}

1;
