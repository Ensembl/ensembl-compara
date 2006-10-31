package EnsEMBL::Web::Object::DAS::karyotype;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Types {
    my $self = shift;

    my @segments = $self->Locations;
    my @features;
    my $dba = $self->database('core', $self->real_species); #->get_SliceAdaptor
    
    my $sth = $dba->prepare("SELECT stain, count(*) FROM karyotype GROUP BY stain");
    $sth->execute();
    while (my @row = $sth->fetchrow_array) {
        push @features, [ $row[0], '', '',$row[1] ]
    }

    return \@features;
}

sub Features {
    my $self = shift;

    my @segments = $self->Locations;
    my @features;

    my @fts = grep { $_ } @{$self->FeatureTypes || []};

    foreach my $s (@segments) {
	if (ref($s) eq 'HASH' && $s->{'TYPE'} eq 'ERROR') {
	    push @features, $s;
	    next;
	}
	my $slice = $s->slice;
	my @segment_features;
	foreach my $ft (@{$slice->get_all_KaryotypeBands() || [] }){
	    if (@fts > 0) {
		next unless grep {$_ eq $ft->{'stain'}} @fts;
	    }

	    my $f = {
		'ID'          => $ft->{'name'},
		'TYPE'        => $ft->{'stain'}||'', 
		'METHOD'      => 'ensembl',
		'START'       => $ft->{'start'},
		'END'         => $ft->{'end'},
		'ORIENTATION' => $ft->{'strand'}+0,
	    };
	    push @segment_features, $f;
	}

	push @features, {
    	    'REGION' => $s->seq_region_name, 
	    'START'  => $s->seq_region_start, 
	    'STOP'   => $s->seq_region_end,
	    'FEATURES' => \@segment_features
	    };
    }
    return \@features;
}

1;
