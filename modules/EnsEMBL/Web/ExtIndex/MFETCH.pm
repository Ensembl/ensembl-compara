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
    elsif ($db =~ /uniprot/i) {
	#strip off any version number for uniprot
	$id =~ s/\.\d{1,3}$//;
	$str = qq(-d uniprot -i acc:).$id.' -v fasta';
    }
    else {
	$str == $id;
    }

    #get the mfetch server
    my $server = $self->fetch_mfetch_server(
	$arghashref->{'species_defs'}->ENSEMBL_MFETCH_SERVER_1,
	$arghashref->{'species_defs'}->ENSEMBL_MFETCH_SERVER_2,
	$arghashref->{'species_defs'}->ENSEMBL_MFETCH_PORT
    );
    #get the sequence from the server
    if ($server){
	my $hostname = &Sys::Hostname::hostname();
	print $server "$str \n";		
	my $output;
	push @$output, $_ while(<$server>);
	return $output;
    }
    else {
	print qq(Problems retrieving the $db sequence, please refresh the page\n);
    }
    #	$server->shutdown;
}

sub fetch_mfetch_server {
	my $self    = shift;
	my $server1 = shift;
	my $server2 = shift;
	my $port    = shift;
	if( ! ($server1 || $server2) ){ die "No ENSEMBL_PFETCH_SERVER found in config" }

	#use one of the two mfetch servers at random
	my @servers = ($server1,$server2);
	my $c = rand(@servers);
	my $server = $servers[$c];

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
	else {

		#try the other server if no reply from the first
		$c = ($c == 1) ? 0 : 1;
		$server =  $servers[$c];
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
}

1;
