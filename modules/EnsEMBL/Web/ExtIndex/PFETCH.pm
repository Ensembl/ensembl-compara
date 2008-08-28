package EnsEMBL::Web::ExtIndex::PFETCH;

use strict;
use IO::Socket;
use Sys::Hostname;

sub new { my $class = shift; my $self = {}; bless $self, $class; return $self; }

sub get_seq_by_acc { my $self = shift; $self->get_seq_by_id( @_ ); }

sub get_seq_by_id {
  my ($self, $arghashref)=@_;

  # Get the ID to pfetch
  my $str = $arghashref->{ID} || return [];

  # Additional options
  if( $arghashref->{OPTIONS} eq 'desc'       ) { $str .= " -D" }
  if( $arghashref->{OPTIONS} =~ /(-d\s+\w+)/ ) { $str .= " $1" }
  if( $arghashref->{DB} eq 'PUBLIC'          ) { $str .= " -d public" }
  if( $arghashref->{DB} =~ /UNIPROT/         ) { $str = " -a $str" }

  # Get the pfetch server
  my $server = $self->fetch_pfetch_server(
    $arghashref->{'species_defs'}->ENSEMBL_PFETCH_SERVER,
    $arghashref->{'species_defs'}->ENSEMBL_PFETCH_PORT
  );
  my $hostname = &Sys::Hostname::hostname();
  print $server "--client $hostname $str \n";

  my $output;
  push @$output, $_ while(<$server>);

  return $output;
}

sub fetch_pfetch_server {
  my $self   = shift;
  my $server = shift;
  my $port   = shift;
  if( ! $server ){ die "No ENSEMBL_PFETCH_SERVER found in config" }
  
  my $s = IO::Socket::INET->new( PeerAddr => $server,
    PeerPort => $port, Proto    => 'tcp', Type     => SOCK_STREAM, Timeout  => 10,
  );
  if ($s){
    $s->autoflush(1);
    return( $s );
  } 
  die "Cannot connect to the Trace server - please try again later.";
}

1;
