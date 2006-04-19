package EnsEMBL::Web::Object::DAS::reference;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Features {
    my $self = shift;

    my @segments = $self->Locations;
    my @features;

    foreach my $s (@segments) {
	if (ref($s) eq 'HASH' && $s->{'TYPE'} eq 'ERROR') {
	    push @features, $s;
	    next;
	}

	my ($region_name, $region_start, $region_end) = ($s->name);

	if ($s->name =~ /^([-\w\.]+):([\.\w]+),([\.\w]+)$/ ) {
	    ($region_name,$region_start,$region_end) = ($1,$2,$3);
	}

	my $slice = $self->database('core', $self->real_species)->get_SliceAdaptor->fetch_by_region('', $region_name, $region_start, $region_end, 1 );

	my $subparts = 'yes';
	my $superparts = 'no';

# Get current coordinate system
	my $current_cs = $slice->coord_system;
	my @coord_systems = ($current_cs);

	my $current_rank = $current_cs->rank;

# Check if there are super and/or sub parts
	my $csa = $slice->coord_system->{adaptor};
	my $higher_cs = $csa->fetch_by_rank($current_rank - 1);
	if ($higher_cs && ! $higher_cs->is_top_level) { 
	    push @coord_systems, $higher_cs;
	    $superparts = 'yes';
	}

	my $lower_cs = $csa->fetch_by_rank($current_rank + 1);
	if ($lower_cs) { 
	    push @coord_systems, $lower_cs;
	    if ($lower_cs->is_sequence_level) {
		$subparts = 'no';
	    }
	}


	my @segment_features;

	my @projected_segments = @{$slice->project("seqlevel") || []};
	foreach my $psegment (@projected_segments) {
	    my $start      = $psegment->from_start;
	    my $end        = $psegment->from_end;
	    my $ctg_slice  = $psegment->to_Slice;
	    my $ORI        = $ctg_slice->strand;
	    my $feature = { 'start' => $start, 'end' => $end, 'name' => $ctg_slice->seq_region_name };


	    foreach ( @coord_systems ) {
		my $path;
		eval { $path = $ctg_slice->project($_->name); };
		next unless(@$path);
		$path = $path->[0]->to_Slice;
		$feature->{'locations'}{$_->rank} = [ $path->seq_region_name, $path->start, $path->end, $path->strand ];
	    }
	    push @segment_features, $feature;
	    
	}

	my ($ids, $sids);

	foreach my $f (@segment_features) {
	    my $id = $f->{'locations'}{ ($current_rank + 1) }->[0];
	    my $start = $f->{'locations'}{ ($current_rank) }->[1];
	    my $end = $f->{'locations'}{ ($current_rank) }->[2];

	    my $target_start = $f->{'locations'}{ ($current_rank + 1) }->[1];
	    my $target_end = $f->{'locations'}{ ($current_rank + 1) }->[2];
	    
	    if (exists($ids->{$id})) {
		$ids->{$id}->[2] = $end;
		$ids->{$id}->[4] = $target_end;
	    } else {
		if ($lower_cs) {
		    $ids->{$id} = [ $lower_cs->name, $start, $end, $target_start, $target_end ];
		}
	    }

	    if ($higher_cs && ! $higher_cs->is_top_level) {
		my $id = $f->{'locations'}{ ($current_rank-1) }->[0];
		my $pstart = $f->{'locations'}{ ($current_rank - 1) }->[1];
		my $pend = $f->{'locations'}{ ($current_rank - 1) }->[2];

		if (exists($sids->{$id})) {
		    $sids->{$id}->[2] = $end;
		    $sids->{$id}->[4] = $pend;
		} else {
		    $sids->{$id} = [$higher_cs->name, $start, $end, $pstart, $pend, 
				    $higher_cs->rank == 1 ? 'no' : 'yes'];
		}

	    }

#	    warn(Data::Dumper::Dumper($f));
	    
	} 

	my @ss;

	push @ss, {
	    'ID' => $slice->seq_region_name, 
	    'START' => $slice->start, 
	    'END' => $slice->end,
	    'TARGET_ID' => $slice->seq_region_name, 
	    'TARGET_START' => $slice->start, 
	    'TARGET_END' => $slice->end,
	    'TYPE' => $current_cs->name, 
	    'SUPERPARTS' => $superparts, 
	    'SUBPARTS' => %$ids ? 'yes' : 'no', 
	    'CATEGORY' => 'component',
	    };

	foreach my $id ( keys %$ids ) {
	    push @ss, {
		'ID' =>  "$ids->{$id}->[0]\:$id", 
		'START' => $ids->{$id}->[1], 
		'END' => $ids->{$id}->[2],
		'TARGET_ID' => $id, 
		'TARGET_START' => $ids->{$id}->[3], 
		'TARGET_END' => $ids->{$id}->[4],
		'TYPE' => $ids->{$id}->[0], 
		'SUBPARTS' => $subparts,
		'SUPERPARTS' => 'yes',
		'CATEGORY' => 'component',
		};
	}

	foreach my $id ( keys %$sids ) {
	    push @ss, {
		'ID' =>  "$sids->{$id}->[0]\:$id", 
		'START' => $sids->{$id}->[1], 
		'END' => $sids->{$id}->[2],
		'TARGET_ID' => $id, 
		'TARGET_START' => $sids->{$id}->[3], 
		'TARGET_END' => $sids->{$id}->[4],
		'TYPE' => $sids->{$id}->[0], 
		'SUPERPARTS' => $sids->{$id}->[5], 
		'SUBPARTS' => 'yes',
		'CATEGORY' => 'supercomponent',
		};
	}



	push @features, {
    	    'REGION' => $region_name, 
	    'START'  => $region_start, 
	    'STOP'   => $region_end,
	    'FEATURES' => \@ss
	    };
    }


#    warn(Data::Dumper::Dumper(\@features));

    return \@features;
}


sub EntryPoints {
    my ($self) = @_;

    my $slice_adaptor = $self->database('core', $self->real_species)->get_SliceAdaptor();


    my @chromosome_slices = @{$slice_adaptor->fetch_all('chromosome')};
    my $collection;

    my @toplevel_slices = @{$slice_adaptor->fetch_all('toplevel', undef, 1)};

#    foreach my $chromosome_slice (@chromosome_slices) {
    foreach my $chromosome_slice (@toplevel_slices) {
	my ($ctype, $build, $region, $start, $end, $ori) = split(/:/,$chromosome_slice->name());
	push @$collection, [$region, $start, $end, $ori > 0 ? '+': '-', $region];
    }

    return $collection;
}


sub DNA {
    my $self = shift;
    my @segments = $self->Locations;
    my @features;

    foreach my $s (@segments) {
	if (ref($s) eq 'HASH' && $s->{'TYPE'} eq 'ERROR') {
	    push @features, $s;
	    next;
	}

	my ($region_name, $region_start, $region_end) = ($s->name);

	if ($s->name =~ /^([-\w\.]+):([\.\w]+),([\.\w]+)$/ ) {
	    ($region_name,$region_start,$region_end) = ($1,$2,$3);
	}

	my $slice = $self->database('core', $self->real_species)->get_SliceAdaptor->fetch_by_region('', $region_name, $region_start, $region_end, 1 );

	my $seq = lc($slice->seq());

	push @features, {
    	    'REGION' => $region_name, 
	    'START'  => $region_start, 
	    'STOP'   => $region_end,
	    'SEQ' => $seq
	    };
    }

    return \@features;
}

1;
