package EnsEMBL::Web::ExtIndex::MFETCH;

use strict;
use IO::Socket;
use Sys::Hostname;

sub new { my $class = shift; my $self = {}; bless $self, $class; return $self; }

sub get_seq_by_acc { my $self = shift; $self->get_seq_by_id( @_ ); }

sub get_seq_by_id {
  my ($self, $arghashref)=@_;

  # Get the ID to mfetch
  my $id = $arghashref->{'ID'} || return [];
  my $db = $arghashref->{'DB'};
  my $str;

  #hack to get a CCDS record using mfetch - need a wildcard for version
  if ($db eq 'CCDS') {
    if ($id !~ /\.\d{1,3}$/) {
      $id .= '.*';
    }
    $str = qq(-d refseq -i ccds:).$id;
    $str .= qq(&div:NM -v fasta);
  }
  else {
    $str == $id;
  }

  #get the mfetch server
  my $server = $self->fetch_mfetch_server(
    $arghashref->{'species_defs'}->ENSEMBL_MFETCH_SERVER,
    $arghashref->{'species_defs'}->ENSEMBL_MFETCH_PORT
  );

  #get the sequence from the server
  if ($server){
    my $hostname = &Sys::Hostname::hostname();
    print $server "$str \n";		
    my $output;

    #only return one sequence (more than one can have the same CCDS attached
    my $rec_c = 0;
    while (<$server>) {
      $rec_c++ if ($_ =~ /^>/m);
      unless ($rec_c > 1) {
	push @$output, $_;
      }
    }
    return $output;
  }
  else {
    print qq(Problems retrieving the $db sequence, please refresh the page\n);
  }
}

sub fetch_mfetch_server {
  my $self    = shift;
  my $server  = shift;
  my $port    = shift;
  if( ! $server ){ die "No ENSEMBL_PFETCH_SERVER found in config" }

  my $s = IO::Socket::INET->new(
    PeerAddr => $server,
    PeerPort => $port,
    Proto    => 'tcp',
    Type     => SOCK_STREAM,
    Timeout  => 10,
  );
  if ($s){
    $s->autoflush(1);
    return( $s );
  }
}

1;
