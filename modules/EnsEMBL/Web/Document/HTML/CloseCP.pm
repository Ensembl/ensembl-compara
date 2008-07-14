package EnsEMBL::Web::Document::HTML::CloseCP;

### Generates link to 'close' control panel (currently in Popup masthead)

use strict;
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub new { return shift->SUPER::new(); }

## Needed to avoid problems in Document::Common
sub logins    :lvalue { $_[0]{'logins'};   }

sub render   {
  my $self = shift;
  my $url;
  my @params = split(';', $ENV{'QUERY_STRING'});
  foreach my $param (@params) {
    next unless $param =~ '_referer';
    ($url = $param) =~ s/_referer=//;
    last;
  }
  $self->printf(qq(
    <a href="$url">Exit Control Panel</a>
  ));
}

1;

