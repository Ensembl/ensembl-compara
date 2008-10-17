package EnsEMBL::Web::Text::FeatureParser::GBrowse;

=head1 NAME

EnsEMBL::Web::Text::FeatureParser::GBrowse;

=head1 SYNOPSIS

This object parses data supplied by the user in BED format and identifies sequence locations for use by other Ensembl objects

=head1 DESCRIPTION

    my $parser = EnsEMBL::Web::Text::FeatureParser->new();
    $parser->init($data);
    $parser->parse($data);

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

=cut

use strict;
use warnings;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::Text::Feature::GBrowse;
use Data::Dumper;

our @ISA = qw(EnsEMBL::Web::Text::FeatureParser);

#----------------------------------------------------------------------

=head2 parse_row

    Arg [1]   :  
    Function  : Parses an individual row of data, i.e. a single feature
    Returntype: 
    Exceptions: 
    Caller    : 
    Example   : 

=cut

sub parse_row {
    my( $self, $row, $format ) = @_;
    return if ($row =~ /^\#/);
    $row =~ s/[\t\r\s]+$//g;
    return unless $row;


    if( $row =~ /^browser\s+(\w+)\s+(.*)/i ) {
	$self->{'browser_switches'}{$1}=$2;     
    }   elsif ($row =~ s/^track\s+(.*)$/$1/i) {
	my %config;
	while( $row ne '' ) {
	    if( $row =~ s/^(\w+)\s*=\s*\"([^\"]+)\"// ) {  
                my $key   = $1;
                my $value = $2;
                while( $value =~ s/\\$// && $row ne '') {
		    if( $row =~ s/^([^\"]+)\"\s*// ) {
			$value .= "\"$1";
		    } else {
			$value .= "\"$row"; 
			$row = '';
		    }
		}
		$row =~ s/^\s*//;
                $config{$key} = $value;
	    } elsif( $row =~ s/(\w+)\s*=\s*(\S+)\s*// ) {
                $config{$1} = $2;
            } else {
                $row ='';
            }
	}
	$config{'name'} ||= 'default';
        my $current_key = $config{'name'}; # || 'default';
        $self->{'tracks'}{ $current_key } = { 'features' => [], 'config' => \%config };
        $self->{'_current_key'} = $current_key;
    } else {
	my $current_key = $self->{'_current_key'} ; 

	if ($row =~ /\[(\w+)\]/) {
	    my $wigConfig = {
		'data' => 'style',
		'name' => $1,
	    };

	    $self->{'tracks'}{ $current_key }->{'mode'} = $wigConfig;
        } elsif ($row =~ /^reference(\s+)?=(\s+)?(.+)/i) {
	    my $wigConfig = {
		'data' => 'features',
		'name' => $3,
	    };
	    if ($wigConfig->{'name'} =~ /^ENSP/) {
		$self->{'tracks'}{ $current_key }->{'config'}->{'coordinate_system'} = 'ProteinFeature';
	    } else {
		$self->{'tracks'}{ $current_key }->{'config'}->{'coordinate_system'} = 'DnaAlignFeature';
	    }
	    $self->{'tracks'}{ $current_key }->{'mode'} = $wigConfig;
	} else {
	    my $wigConfig = $self->{'tracks'}{ $current_key }->{'mode'};
	    if (my $action = $wigConfig->{data}) {
		if ($action eq 'style') {
		    my $tname = $wigConfig->{name}; 
		    if (my @sdata = split /\=/, $row ) {
			$self->{'tracks'}{ $current_key }->{'styles'}->{$tname}->{$sdata[0]} = $sdata[1];
		    }
		} elsif ($action eq 'features') {
		    my @fields;
		    if (my @fields_with_spaces = ($row =~ m/\"([^\"]*)\"/g)) {
			$row =~ s/\"[^\"]*\"/___/g;
			@fields = split /\s+|\t/, $row;
			for (my $i=0; $i<=$#fields; $i++) {
			    if ($fields[$i] eq '___') {
				$fields[$i] = shift @fields_with_spaces;
			    }
			}
		    } else {
			@fields = split /\s+|\t/, $row;
		    }

		    my ($ftype, $fname, $fpos, $fdesc, $flink) = @fields;
		    my $fscore;

		    if ($fdesc && ($fdesc =~ /score=(\w+)/)) {
			$fscore = $1;
		    }

		    my @fparts = $fpos ? split /\,/, $fpos : ();
		    foreach my $fpart (@fparts) {
			
			my ($fstart, $fend) = ($fpart=~/\.\./) ? split /\.\./, $fpart : split /\-/, $fpart;
			my $fstrand = ($fstart > $fend) ? -1 : 1;

			$self->store_feature( $current_key , EnsEMBL::Web::Text::Feature::GBrowse->new( [$wigConfig->{'name'}, $fstart, $fend, $fstrand, $fname, $fscore, $ftype, $fdesc, $flink]));
		    }
		}
	    }
	}
    } 
}

1;
