# $Source$
# $Revision$
# $Date$
# $Author$
# module for retrieving sequences using the EBI dbfetch REST service

package EnsEMBL::Web::ExtIndex::EGFETCH;

use warnings;
use strict;
#use IO::Socket;
#use Sys::Hostname;
use Data::Dumper;
use Carp;
use LWP::UserAgent;

my $DEFAULT_PARAMS = {
	agent        => 'EgFetch/1.0',
#	service_base => 'http://www.ebi.ac.uk/Tools/webservices/rest/dbfetch/',
	
	service_base => 'http://www.ebi.ac.uk/Tools/webservices/rest/dbfetch/%dbname%/%id%/%format%',
	format       => 'fasta',
    srs_seq_query_url => 'http://srs.ebi.ac.uk/srsbin/cgi-bin/wgetz?%query%+-f+seq+-sf+%format%',
    srs_entry_query_url => 'http://srs.ebi.ac.uk/srsbin/cgi-bin/wgetz?%query%+-e+-ascii',
};

my $dbnames = {
	embl=>'embl',
	emblcds=>'emblcds',
	embl_component=>'embl',
	uniprot=>'uniprotkb',
	uniprotkb=>'uniprotkb',
	uniparc=>'uniparc',
	'refseq'=>'refseq',
       'uniprot/swissprot' => 'uniprotkb',
       'uniprot/sptrembl' => 'uniprotkb',
       'refseq_peptide' => 'refseq',
       'protein_id' => 'emblcds',
       'refseq_dna'=>'refseq',
       'embl_dna' => 'embl',
       'unigene' => 'unigene',
       'swiss-2dpage' => 'uniprotkb',
};

my $db_to_url_sub = {

    embl=>'dbfetch_path_for_id',
    emblcds=>'dbfetch_path_for_id',
    uniprot=>'dbfetch_path_for_id',
    uniprotkb=>'dbfetch_path_for_id',
    uniparc=>'dbfetch_path_for_id',
    refseq=>'dbfetch_path_for_id',
    unigene=>'unigene_path_for_id'
};

my $db_to_parser_sub = {
   unigene=>'unigene_parser'
};

sub new {
	my $class = shift;
	my $self  = bless( {}, ref($class) || $class );
	my $args  = {@_};

	foreach my $par_name ( keys(%$DEFAULT_PARAMS) ) {
		$self->{$par_name} = $DEFAULT_PARAMS->{$par_name};
	}
	foreach my $par_name ( keys(%$args) ) {
		$self->{$par_name} = $args->{$par_name};
	}
	$self->{ua} = new LWP::UserAgent;
	$self->{ua}->agent( $self->{params}{agent} );
	if ( defined $self->{proxy} ) {
		my $url    = new URI::URL $self->{service_base};
		my $scheme = $url->scheme;
		$self->{ua}->proxy( $scheme, $self->{proxy} );
	}
	if(defined $args->{dbnames}) {
		foreach my $key (%{$args->{dbnames}}) {
			$dbnames->{$key} = $$args->{dbnames}{$key};
		}
	}
	return $self;
}

sub get_sequence_by_id_old {
	my ( $self, $id, $dbname, $format ) = @_;
	my $seq = $self->do_request( 'GET', $self->path_for_id( $id, $dbname ) );
	if($seq =~ m/No entries found/) {
		croak "No entries found for $dbname:$id";
	}
	return $seq;
}

sub get_sequence_by_id {
    my ( $self, $id, $dbname_b, $format ) = @_;
    $dbname_b =~ s/_predicted$//i;
    my $dbname = $dbnames->{lc $dbname_b};
    if(!$dbname) {
		warn "Database name not found for ID ($dbname_b): $id";
    }

    if ( $dbname =~ /emblcds|refseq/ || $dbname eq 'embl') {
	$id =~ s/\..+$//;
    }


    if(!$format) {
	$format = $self->{format};
    }
    my $url_sub = $db_to_url_sub->{$dbname};
    if(!$url_sub) {
	$url_sub = 'dbfetch_path_for_id';
    }

    my $url = $self->$url_sub($id, $dbname, $format);
    my $seq = $self->do_request( 'GET', $url );
#    warn "GET ($url)";
    if($seq =~ m/No entries found/) {
	return "No entries found for $dbname:$id";
    }
    my $parser_sub = $db_to_parser_sub->{$dbname};
    if($parser_sub) {
	$seq = $self->$parser_sub($seq);
    }
    return $seq;
}

sub path_for_id {
	my ( $self, $id, $dbname, $format ) = @_;

	$dbname =~ s/_predicted$//i;
#	warn "DB $dbname";

	my $dbf_dbname = $dbnames->{lc $dbname};
	if ( !$dbf_dbname ) {
		warn "Database name not found for ID ($dbname): $id";
                croak;
	}
	if ( $dbf_dbname =~ /emblcds|refseq/) {
	    $id =~ s/\..+$//;
	}

	if(!$format) {
		$format = $self->{format};
	}
	my $url = $self->{service_base} . $dbf_dbname . '/' . $id . '/' . $format;
	return $url;
}



sub dbfetch_path_for_id {
    my ( $self, $id, $dbname, $format ) = @_;
    if ( !$dbname ) {
	croak "Database name not found for ID $id";
    }
    my $url = $self->{service_base};
    $url =~ s/%dbname%/$dbname/;
    $url =~ s/%id%/$id/;
    $url =~ s/%format%/$format/;
    return $url;
}

sub unigene_path_for_id {
    my ( $self, $id, $dbname, $format ) = @_;
    my $url  = $self->{srs_entry_query_url};
    $url =~ s/%query%/[$dbname:$id]/;
    return $url;
}

sub srs_path_for_id {
    my ( $self, $id, $dbname, $format ) = @_;
    my $url  = $self->{srs_seq_query_url};
    $url =~ s/%query%/[$dbname:$id]/;
    $url =~ s/%format%/$format/;
    return $url;
}

my $unigene_heads = {
    ID=>1,
    TITLE=>1,
    GENE=>1,
    CYTOBAND=>1,
    GENE_ID=>1,
    LOCUSLINK=>1,
    HOMOL=>1,
    CHROMOSOME=>1
    };

sub unigene_parser {
    my ($self,$seq) = @_;
    my @new_seq = grep { my ($title) = split /\s+/; $title && $unigene_heads->{$title} }split(/\n/,$seq);
#    return join "\n", @new_seq;
    return '>' . join "; ", @new_seq;
}


sub do_request {

	my ( $self, $method, $path ) = @_;
#	warn "REQ: $path";
	# Ask the User Agent object to request a URL.
	# Results go into the response object (HTTP::Response).
	my $request = new HTTP::Request( $method, $path );
	my $response = $self->{ua}->request($request);

	# Parse/convert the response object for "easier reading"
	my $code    = $response->code;
	my $desc    = HTTP::Status::status_message($code);
	my $headers = $response->headers_as_string;
	my $body    = $response->content;
	if ( $response->is_error ) {
		warn "Could not do request $method $path:" . $response->error_as_HTML;
	}
	return $body;

}

# The function is used by EnsEMBL::Web::ExtIndex
sub get_seq_by_id_old {
	my ( $self, $args) = @_;
        my ($id, $dbname, $format ) = ($args->{ID}, $args->{DB}, $args->{FORMAT});
#	warn "GET SEQ: $id * $dbname * format";
	my $seq = $self->do_request( 'GET', $self->path_for_id( $id, $dbname ) );
	if($seq =~ m/No entries found/) {
		warn "No entries found for $dbname:$id";
		croak;
	}
#	warn "SEQ: * ", length($seq);
	return [$seq];
}


sub get_seq_by_id {
	my ( $self, $args) = @_;
        my ($id, $dbname, $format ) = ($args->{ID}, $args->{DB}, $args->{FORMAT});

	my $seq;

	if ($dbname !~ /PUBLIC/) {
	    $seq = $self->get_sequence_by_id($id, $dbname, $format );
	} else {
	    foreach my $db (qw(uniprot refseq embl)) {

		$seq = $self->get_sequence_by_id($id, $db, $format );
#		warn "GET SEQ: $id * $dbname * format \n[$seq]\n";
		last if ($seq && ($seq !~ m/No entries/));
	    }
	}

#	my $seq = $self->do_request( 'GET', $self->path_for_id( $id, $dbname ) );


	if($seq =~ m/No entries found/) {
		warn "No entries found for $dbname:$id";
	}
	
#	warn "SEQ: * ($seq) ", length($seq);
	$seq =~ s/\r/\n/g;
	return [$seq];
}

1;

__END__

=head1 NAME

EgFetch

=head1 AUTHORS

Dan Staines <dstaines@ebi.ac.uk>

=head1 DESCRIPTION

Module for simple access to sequences using EBI's web services

=head1 SYNOPSIS

use EgFetch;

my $fetcher = EgFetch->new();

my $seq = $fetcher->get_sequence_by_id('P12345','uniprotkb');
print $seq."\n";

=head1 METHODS

Methods for retrieving sequences

=head2 new

Purpose: 	Create a new instance of a EgFetch object representing a search session with the EBI dbfetch ref search
Arguments:	Optional hash of connection and search parameters.
Returns:	New instance of EgFetch

Valid arguments:
agent			agent string to use when contacting server (default 'EgFetch/1.0')
service_base	base URI for service (Default 'http://www.ebi.ac.uk/Tools/webservices/rest/dbfetch/')
format			output format (default is 'fasta')
dbnames 		hash of mappings from supplied database names to dbfetch names (lower cased) - merged with internal default
proxy			proxy URL (optional)

For more information on supported formats and databases, please see http://www.ebi.ac.uk/Tools/webservices/services/dbfetch_rest

=head2 get_sequence_by_id

Purpose: 	Retrieve the specified sequence given the ID and database name
Arguments:	id (required), database name (required, should be in dbnames mapping), format (optional, uses default if not supplied)
Returns:	Sequence as string
