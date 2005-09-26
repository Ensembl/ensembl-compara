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

sub feature_type : lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_feature_type'} = $p} return $_[0]->{'_feature_type' }; }
sub feature_id : lvalue {  my ($self, $p) = @_; if ($p) {$_[0]->{'_feature_id'} = $p} return $_[0]->{'_feature_id' }; }
sub data         : lvalue { $_[0]->{'_data'         }; }

sub retrieve_features {
  my ($self, $feature_type) = @_;
  my $method;
  if ($feature_type) {
    $method = "retrieve_$feature_type";
  }
  else {
    $method = "retrieve_".$self->feature_type;
  }
  return $self->$method() if defined &$method;
}

sub retrieve_Disease {
  my $self = shift;
  my $results = [];
  my @P = (0,0,0,0);
  foreach my $ap ( sort {
    lc($a->{'disease'})  cmp lc($b->{'disease'})  || 
    $a->{'OMIM'}         <=> $b->{'OMIM'}         ||
    lc($a->{'cyto'})     cmp lc($b->{'cyto'})     ||
    lc($a->{'gsi'})      cmp lc($b->{'gsi'})      || 
    lc($a->{'genename'}) cmp lc($b->{'genename'}) 
  } @{$self->Obj->{'Disease'}}) {
    if( lc($ap->{'disease'}) eq $P[0] && $ap->{'OMIM'} eq $P[1] && lc($ap->{'gsi'}) eq $P[2] && lc($ap->{'cyto'}) eq $P[3] ) {
      $results->[-1]->{'extname'}.=" $ap->{'genename'}";
      next;
    }
    @P = ( lc($ap->{'disease'}), $ap->{'OMIM'}, lc($ap->{'gsi'}), lc($ap->{'cyto'}) );
    my $gene = $ap->{'gene'};
    if( $gene ) {
      push @$results, {
        'region'   => $gene->seq_region_name,
        'start'    => $gene->start,
        'end'      => $gene->end,
        'strand'   => $gene->strand,
        'length'   => $gene->end-$ap->{'gene'}->start+1,
        'extname'  => $ap->{'genename'}, #$gene->external_name,
        'label'    => $gene->stable_id,
        'extra'    => [],
        'initial'  => [ $ap->{'disease'}, $ap->{'omim_id'}, $ap->{'cyto'} ]
      };
    } else {
      push @$results, {
        'region'   => '',
        'start'    => '', 'end' => '',
        'strand'   => '',
        'length'   => '',
        'extname'  => $ap->{'genename'},
        'label'    => '',
        'extra'    => [],
        'initial'  => [ $ap->{'disease'}, $ap->{'omim_id'}, $ap->{'cyto'} ]
      };
    } 
  }
  return ( $results, [], ['Disease', 'OMIM', 'Cyto loc'], {'sorted'=>'yes'} );
}

sub retrieve_Gene {
  my $self = shift;
  
  my $results = [];
  foreach my $ap (@{$self->Obj->{'Gene'}}) {
    push @$results, {
      'region'   => $ap->seq_region_name,
      'start'    => $ap->start,
      'end'      => $ap->end,
      'strand'   => $ap->strand,
      'length'   => $ap->end-$ap->start+1,
      'extname'  => $ap->external_name, 
      'label'    => $ap->stable_id,
      'extra'    => [ $ap->description ]
    }
  }
  
  return ( $results, ['Description'] );
}

sub retrieve_AffyProbe {
  my $self = shift;
  
  my $results = [];
  foreach my $ap (@{$self->Obj->{'AffyProbe'}}) {
    my $names = join ' ', sort @{$ap->get_all_complete_names()};
    foreach my $f (@{$ap->get_all_AffyFeatures()}) {
      push @$results, {
        'region'   => $f->seq_region_name,
        'start'    => $f->start,
        'end'      => $f->end,
        'strand'   => $f->strand,
        'length'   => $f->end-$f->start+1,
        'label'    => $names,
        'extra'    => [ $f->mismatchcount ]
      }
    }
  }
  return ( $results, ['Mismatches'] );
}

sub coord_systems {
  my $self = shift;
  return [ map { $_->name } @{ $self->Obj->[0]->adaptor->db->get_CoordSystemAdaptor()->fetch_all() } ];
}

sub retrieve_DnaAlignFeature {
  my $self = shift;
  my $results = [];
  my $coord_systems = $self->coord_systems();
  foreach my $f ( @{$self->Obj->{'AlignFeature'}} ) { 
	next unless ($f->score > 80);
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
      'label'    => "@{[$f->hstart]}-@{[$f->hend]}",
      'extra' => [ $f->alignment_length, $f->hstrand * $f->strand, $f->percent_id, $f->score, $f->p_value ]
    };
  }
  return $results, [ 'Alignment length', 'Rel ori', '%id', 'score', 'p-value' ];
}

sub retrieve_ProteinAlignFeature {
  return $_[0]->retrieve_DnaAlignFeature();
}

sub retrieve_RegulatoryFactor {
  my $self = shift;
  
  my $results = [];
  foreach my $ap (@{$self->Obj->{'RegulatoryFactor'}}) {
    push @$results, {
      'region'   => $ap->seq_region_name,
      'start'    => $ap->start,
      'end'      => $ap->end,
      'strand'   => $ap->strand,
      'length'   => $ap->end-$ap->start+1,
      'label'    => $ap->name,
      'extra'    => [ $ap->analysis->description ]
    }
  }
  
  return ( $results, ['Feature analysis'] );
}

1;
