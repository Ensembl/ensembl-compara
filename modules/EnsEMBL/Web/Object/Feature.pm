package EnsEMBL::Web::Object::Feature;
                                                                                   
use strict;
use warnings;
no warnings "uninitialized";
                                                                                   
use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Object;
                                                                                   
@EnsEMBL::Web::Object::Feature::ISA = qw(EnsEMBL::Web::Object);

use Bio::AlignIO;

=head2 sequenceObj

 Arg[1]           : none
 Example     : my $sequence = $seqdata->sequenceObj
 Description : Gets a sequence stored in the data object
 Return type : Bio::EnsEmbl::Feature

=cut

sub data         : lvalue { $_[0]->{'_data'}; }
sub feature_type : lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_feature_type'} = $p} return $_[0]->{'_feature_type' }; }
sub feature_id : lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_feature_id'} = $p} return $_[0]->{'_feature_id' }; }

sub feature_mapped {  
  my $self = shift;
  my $type = $self->feature_type;
  my $mapped = $self->{'data'}{'_object'}{$type}[0] =~ /UnmappedObject/ ? 0 : 1;
  return $mapped;
}

sub unmapped_detail {
  my ($self, $detail) = @_;
  my $type = $self->feature_type;
  my $value = $self->{'data'}{'_object'}{$type}[0]->$detail;
  return $value;
}

sub retrieve_features {
  my ($self, $feature_type) = @_;
  my $method;
  if ($feature_type) {
    $method = "retrieve_$feature_type";
  } else {
    $method = "retrieve_".$self->feature_type;
  }
  return $self->$method() if defined &$method;
  return [];
}

sub retrieve_Gene {
  my $self = shift;
  
  my $results = [];
  foreach my $g (@{$self->Obj->{'Gene'}}) {
    if (ref($g) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($g);
      push(@$results, $unmapped);
    }
    else {
      push @$results, {
        'region'   => $g->seq_region_name,
        'start'    => $g->start,
        'end'      => $g->end,
        'strand'   => $g->strand,
        'length'   => $g->end-$g->start+1,
        'extname'  => $g->external_name, 
        'label'    => $g->stable_id,
        'gene_id'  => [ $g->stable_id ],
        'extra'    => [ $g->description ]
      }
    }
  }
  
  return ( $results, ['Description'] );
}

sub retrieve_Xref {
  my $self = shift;
  
  my $results = [];
  foreach my $array (@{$self->Obj->{'Xref'}}) {
    my $xref = shift @$array;
    push @$results, {
      'label'     => $xref->primary_id,
      'xref_id'   => [ $xref->primary_id ],
      'extname'   => $xref->display_id,
      'extra'     => [ $xref->description, $xref->dbname ]
    };
    ## also get genes
    foreach my $g (@$array) {
      push @$results, {
        'region'   => $g->seq_region_name,
        'start'    => $g->start,
        'end'      => $g->end,
        'strand'   => $g->strand,
        'length'   => $g->end-$g->start+1,
        'extname'  => $g->external_name, 
        'label'    => $g->stable_id,
        'gene_id'  => [ $g->stable_id ],
        'extra'    => [ $g->description ]
      }
    }
  }
  
  return ( $results, ['Description'] );
}

sub retrieve_OligoProbe {
  my $self = shift;
  
  my $results = [];
  foreach my $ap (@{$self->Obj->{'OligoProbe'}}) {
    if (ref($ap) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($ap);
      push(@$results, $unmapped);
    }
    else {
      my $names = join ' ', map { /^(.*):(.*):\2/? "$1:$2" : $_ } sort @{$ap->get_all_complete_names()};
      foreach my $f (@{$ap->get_all_OligoFeatures()}) {
        push @$results, {
          'region'   => $f->seq_region_name,
          'start'    => $f->start,
          'end'      => $f->end,
          'strand'   => $f->strand,
          'length'   => $f->end-$f->start+1,
          'label'    => $names,
          'gene_id'  => [$names],
          'extra'    => [ $f->mismatchcount ]
        }
      }
    }
  }
  return ( $results, ['Mismatches'] );
}

sub coord_systems {
  my $self = shift;
  my ($exemplar) = keys(%{$self->Obj});
#warn $self->Obj->{$exemplar}->[0];
  return [ map { $_->name } @{ $self->Obj->{$exemplar}->[0]->adaptor->db->get_CoordSystemAdaptor()->fetch_all() } ];
}

sub unmapped_object {
  my ($self, $unmapped) = @_;

  my $analysis = $unmapped->analysis;
  #while (my($k, $v) = each (%$analysis)) {
  #  warn "$k = $v";
  #}

  my $result = {
    'label'     => $unmapped->{'_id_'},
    'reason'    => $unmapped->description,
    'object'    => $unmapped->ensembl_object_type,
    'score'     => $unmapped->target_score,
    'analysis'  => $$analysis{'_description'},
  };
  #while (my($k, $v) = each (%$unmapped)) {
  #  warn "$k = $v";
  #}

  return $result;
}

sub retrieve_DnaAlignFeature {
  my ($self, $ftype) = @_;
  $ftype = 'Dna' unless $ftype;
  my $results = [];

  foreach my $f ( @{$self->Obj->{$ftype.'AlignFeature'}} ) {
    if (ref($f) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($f);
      push(@$results, $unmapped);
    }
    else {
#	    next unless ($f->score > 80);
      my $coord_systems = $self->coord_systems();
      my( $region, $start, $end, $strand ) = ( $f->seq_region_name, $f->start, $f->end, $f->strand );
      if( $f->coord_system_name ne $coord_systems->[0] ) {
        foreach my $system ( @{$coord_systems} ) {
          # warn "Projecting feature to $system";
          my $slice = $f->project( $system );
          # warn @$slice;
          if( @$slice == 1 ) {
            ($region,$start,$end,$strand) = ($slice->[0][2]->seq_region_name, $slice->[0][2]->start, $slice->[0][2]->end, $slice->[0][2]->strand );
            last;
          }
        }
      }
      push @$results, {
        'region'   => $region,
        'start'    => $start,
        'end'      => $end,
        'strand'   => $strand,
        'length'   => $f->end-$f->start+1,
        'label'    => $f->display_id." (@{[$f->hstart]}-@{[$f->hend]})",
        'gene_id'  => ["@{[$f->hstart]}-@{[$f->hend]}"],
        'extra' => [ $f->alignment_length, $f->hstrand * $f->strand, $f->percent_id, $f->score, $f->p_value ]
      };
    }
  }

  if ($self->feature_mapped) {
    return $results, [ 'Alignment length', 'Rel ori', '%id', 'score', 'p-value' ];
  }
  else {
    return $results;
  }
}

sub retrieve_ProteinAlignFeature {
  return $_[0]->retrieve_DnaAlignFeature('Protein');
}

sub retrieve_RegulatoryFactor {
  my $self = shift;
  my $results = [];
  my $flag = 0;

  foreach my $ap (@{$self->Obj->{'RegulatoryFactor'}}) {
    my @stable_ids;
    my $gene_links;
    my $db_ent = $ap->get_all_DBEntries;
    foreach ( @{ $db_ent} ) {
      push @stable_ids, $_->primary_id;
      $gene_links .= qq(<a href="geneview?gene=$stable_ids[-1]">$stable_ids[-1]</a>);
    #  $flag = 1;
    }

    my @extra_results = $ap->analysis->description;
    $extra_results[0] =~ s/(https?:\/\/\S+[\w\/])/<a rel="external" href="$1">$1<\/a>/ig;
    
  unshift (@extra_results, $gene_links);# if $gene_links;

    push @$results, {
      'region'   => $ap->seq_region_name,
      'start'    => $ap->start,
      'end'      => $ap->end,
      'strand'   => $ap->strand,
      'length'   => $ap->end-$ap->start+1,
      'label'    => $ap->display_label,
      'gene_id'  => \@stable_ids,
      'extra'    => \@extra_results,
    }
  }
  my $extras = ["Feature analysis"];
  unshift @$extras, "Associated gene";# if $flag;

  return ( $results, $extras );
}


=head2 find_available_features

 Arg[1]	     : EnsEMBL::Web::Object::Feature (or EnsEMBL::Web::Proxy::Object)
 Example     : my $avail_features = $obj->find_available_features
 Description : looks in species_defs for size of feature tables and returns details of those that have entries
 Return type : arrayref

=cut	

sub find_available_features {
	my $self = shift;
	my $species      = $self->species;
	my $species_defs = $self->species_defs;

	my $all_feature_types = [
		{'table'=>'gene',value=>'Gene','text'=>"Gene"},
        {'table'=>'oligo_feature','value'=>'OligoProbe','text'=>"OligoProbe"},
        {'table'=>'dna_align_feature','value'=>'DnaAlignFeature','text'=>"Sequence Feature"},
        {'table'=>'protein_align_feature','value'=>'ProteinAlignFeature','text'=>"Protein Feature"},
        {'table'=>'regulatory_feature','value'=>'RegulatoryFactor','text'=>"Regulatory Factor"},
						  ];

	my $used_feature_types = [];
	foreach my $poss_feature (@$all_feature_types) {
		if ($species_defs->get_table_size( {-db=>'DATABASE_CORE',-table => $poss_feature->{'table'}},$species )) {
			push @$used_feature_types, $poss_feature;
		}
	}
  ## quick and dirty - ought to check for MIM in external_db
	if ($species eq 'Homo_sapiens') { 
		unshift @$used_feature_types, {'text'=>"OMIM Disease/Trait",'value'=>'Xref_MIM','href'=>"/$species/featureview?type=Xref_MIM",'raw'=>1};
	}
	return $used_feature_types;
}


1;
