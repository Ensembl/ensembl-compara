use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::State;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(SessionState)]; }
sub requires { return children(); }

package EnsEMBL::Web::NewTable::Plugins::SessionState;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

use JSON;

sub activity_save_orient {
  my ($self) = @_;

  my $hub = $self->hub;
  my $session = $hub->session;
  my $orient = $hub->param('orient');
  my $seq = $hub->param('seq');

  my %args    = ( type => 'newtable', code => 'XXX' );
  my %data;
  
  # XXX check seq
  $data{'orient'} = $orient;
  
  $session->purge_data(%args);
  $session->set_data(%args, %data) if scalar keys %data;
}

sub extend_config {
  my ($self,$hub,$config) = @_;

  warn "CALLED\n";

  my $session = $hub->session;
  
  my %args    = ( type => 'newtable', code => 'XXX' );
  my %data    = %{$session->get_data(%args) || {}};

  use Data::Dumper;
  warn Dumper("GOT",\%data);

  $config->{'saved_orient'} = {};
  eval { 
    $config->{'saved_orient'} = JSON->new->decode(((\%data||{})->{'orient'})||"");
  };
}

1;
