package EnsEMBL::Web::Object::DAS::transcripts;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Types {
    my $self = shift;

    my @features;
    push @features, ['exon', '', '', 'Unknown number'];
    return \@features;
}

sub Features {
    my $self = shift;

    my @segments = $self->Locations;
    my @features;

    my @fts = grep { $_ } @{$self->FeatureTypes || []};

    my @groups = grep { $_ } @{$self->GroupIDs || []};
    my @ftids  = grep { $_ } @{$self->FeatureIDs || []};

    my $dba = $self->{data}->{_databases}->{_dbs}->{ $self->real_species }->{'core'};
    

    foreach my $e (@ftids) {
	my ($f, @exon_groups);

	if ($e =~ /^ENS(.+)?E\d/) {
	    if (my $exon = $dba->get_ExonAdaptor->fetch_by_stable_id($e)) {
		if (my $trans = $dba->get_TranscriptAdaptor->fetch_all_by_exon_stable_id($e)) {
		    my %genes;

		    foreach my $t (@{$trans || []}) {

			if (my $gene = $dba->get_GeneAdaptor->fetch_by_transcript_stable_id($t->stable_id)) {
			    if ( ! defined ($genes{$gene->display_id})) {
				$genes{$gene->display_id} = 1;
				push @exon_groups, {
				    'ID' => $gene->display_id,
				    'TYPE' => 'gene',
				    'LABEL' => $gene->display_xref ? $gene->display_xref->display_id : undef, 
				    'LINK' => [
					       {
						   href => sprintf("http://www.ensembl.org/%s/geneview?gene=%s", $self->real_species, $gene->display_id),
						   text => 'GeneView'
						   }
					       ]
					       };
			    }
			}


			push @exon_groups, {
			    'ID' => $t->display_id,
			    'TYPE' => 'transcript',
			    'LABEL' => $t->display_xref ? $t->display_xref->display_id : undef, 
			    'LINK' => [
				       {
					   href => sprintf("http://www.ensembl.org/%s/transview?transcript=%s", $self->real_species, $t->display_id),
					   text => 'TransView'
					   }
				       ]
				       };
		    }
		}

		my $fe = {
		    'ID'          => $exon->stable_id,
		    'TYPE'        => 'exon', 
		    'METHOD'      => 'ensembl',
		    'START'       => $exon->start,
		    'END'         => $exon->end,
		    'ORIENTATION' => $exon->strand > 0 ? '+' : '-',
		    'GROUP' => \@exon_groups,
		};

		$f = {
		    'REGION' => $exon->slice->seq_region_name, 
		    'START'  => $exon->start, 
		    'STOP'   => $exon->end,
		    'FEATURES' => [ $fe ]
		};

		push @features, $f;
		    
	    }
	}
    }

    foreach my $g (@groups) {
	my ($gene, @transcripts, $f, @segment_features);
	
	if ($g =~ /^ENS(.+)?G\d/) {
	    if ($gene = $dba->get_GeneAdaptor->fetch_by_stable_id($g)) {
		push @transcripts, @{$gene->get_all_Transcripts || []};
# Might need a shift by $gene->slice->seq_region_start -1 
		$f = {
		    'REGION' => $gene->slice->seq_region_name, 
		    'START'  => $gene->start, 
		    'STOP'   => $gene->end,
		};
	    }

	} elsif ($g =~ /^ENS(.+)?T\d/) {
	    if ($gene = $dba->get_GeneAdaptor->fetch_by_transcript_stable_id($g)) {
		my $trans = $dba->get_TranscriptAdaptor->fetch_by_stable_id($g);
		push @transcripts, $trans;
		$f = {
		    'REGION' => $gene->slice->seq_region_name, 
		    'START'  => $trans->start_Exon->start, 
		    'STOP'   => $trans->end_Exon->end,
		};
	    }
	}

	next unless $gene;

	my $gene_group = {
	    'ID' => $gene->display_id,
	    'TYPE' => 'gene',
	    'LINK' => [
		       {
			   href => sprintf("http://www.ensembl.org/%s/geneview?gene=%s", $self->real_species, $gene->display_id),
			   text => 'GeneView'
			   }
		       ]
	};

	if( $gene->display_xref ) {
	    $gene_group->{LABEL} = $gene->display_xref->display_id;
	}

	foreach my $t (@transcripts) {
	    my $transcript_group = {
		'ID' => $t->display_id,
		'TYPE' => 'transcript',
		'LINK' => [
			   {
			       href => sprintf("http://www.ensembl.org/%s/transview?transcript=%s", $self->real_species, $t->display_id),
			       text => 'TransView'
			       }
			   ]
		};


	    if( $t->display_xref ) {
		$transcript_group->{LABEL} = $t->display_xref->display_id;
	    }

	    my $exons = $t->get_all_Exons;
	    foreach my $e (@$exons) {
		my $fe = {
		    'ID'          => $e->stable_id,
		    'TYPE'        => 'exon', 
		    'METHOD'      => 'ensembl',
		    'START'       => $e->start,
		    'END'         => $e->end,
		    'ORIENTATION' => $e->strand > 0 ? '+' : '-',
		    'GROUP' => [$gene_group, $transcript_group]
		};
		push @segment_features, $fe;

	    }
	}

	$f->{FEATURES} = \@segment_features;

	push @features, $f;
    }

    foreach my $s (@segments) {
	if (ref($s) eq 'HASH' && $s->{'TYPE'} eq 'ERROR') {
	    push @features, $s;
	    next;
	}
	my $slice = $s->slice;
	my @segment_features;

	foreach my $gene ( @{$slice->get_all_Genes} ) {
	    my @transcripts = @{$gene->get_all_Transcripts || []};
	    my $gene_group = {
		'ID' => $gene->display_id,
		'TYPE' => 'gene',
		'LINK' => [
			   {
			       href => sprintf("http://www.ensembl.org/%s/geneview?gene=%s", $self->real_species, $gene->display_id),
			       text => 'GeneView'
			       }
			   ]
			   };

	    if( $gene->display_xref ) {
		$gene_group->{LABEL} = $gene->display_xref->display_id;
	    }

	    foreach my $t (@transcripts) {
		my $transcript_group = {
		    'ID' => $t->display_id,
		    'TYPE' => 'transcript',
		    'LINK' => [
			       {
				   href => sprintf("http://www.ensembl.org/%s/transview?gene=%s", $self->real_species, $t->display_id),
				   text => 'TransView'
				   }
			       ]
			       };


		if( $t->display_xref ) {
		    $transcript_group->{LABEL} = $t->display_xref->display_id;
		}

		my $exons = $t->get_all_Exons;
		foreach my $e ( @$exons) {
		    next if ( ($e->end < 0) || ($e->start > $slice->length));

		    my $estart = $s->seq_region_start + $e->start;
		    my $eend = $s->seq_region_start + $e->end;

		    my $fe = {
			'ID'          => $e->stable_id,
			'TYPE'        => 'exon', 
			'METHOD'      => 'ensembl',
			'START'       => $estart,
			'END'         => $eend,
			'ORIENTATION' => $e->strand > 0 ? '+' : '-',
			'GROUP' => [$gene_group, $transcript_group]
			};
		    push @segment_features, $fe;

		}
	    }
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
