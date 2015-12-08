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
  my ($self,$config) = @_;

  my $hub = $self->hub;
  my $session = $hub->session;
  my $orient_in = $hub->param('orient');
  my $seq = $hub->param('seq');

  my $orient;
  eval {
    $orient = JSON->new->decode($orient_in);
  };
  warn "$@\n" if $@;
  return unless defined $orient;

  $config->filter_saved($orient);

  my %args    = ( type => 'newtable', code => $config->class );

  # Sequence check
  my %data_in = %{$session->get_data(%args) || {}};
  my $old_seq = $data_in{'seq'}||-1;
  my $new_seq = $hub->param('seq')||0;

  return if $old_seq >= $new_seq; # Out of order

  my %data;
  eval {
    $data{'orient'} = JSON->new->encode($orient);
    $data{'seq'} = $new_seq;
  };
  warn "$@\n" if $@;

  $session->purge_data(%args);
  $session->set_data(%args, %data) if scalar keys %data;
}

sub extend_config {
  my ($self,$hub,$config) = @_;

  my $session = $hub->session;
  
  my %args    = ( type => 'newtable', code => $self->class );
  my %data    = %{$session->get_data(%args) || {}};

  $config->{'saved_orient'} = {};
  eval {
    $config->{'saved_orient'} = JSON->new->decode(((\%data||{})->{'orient'})||"{}");
  };
  warn "$@\n" if $@;
}

1;
