package EnsEMBL::Web::Object::DAS::transcripts;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;
  return [
    { 'id' => 'exon'  }
  ];
}

sub Features {
### Return das features...
  my $self = shift;

  my @segments = $self->Locations;
  my @features;
  my %fts    = map { $_=>1 } grep { $_ } @{$self->FeatureTypes  || []};
  my @groups =               grep { $_ } @{$self->GroupIDs      || []};
  my @ftids  =               grep { $_ } @{$self->FeatureIDs    || []};

  my %genes;
  my %transcripts;
  my %exons;
#  my @dbs = qw(core vega otherfeatures);
  my $dba_hashref;
  my @logic_names;
  my @dbs = ();
  if( $ENV{'ENSEMBL_DAS_SUBTYPE'} ) {
    my( $db, @logic_names ) = split /-/, $ENV{'ENSEMBL_DAS_SUBTYPE'};
    push @dbs, $db;
  } else {
    @dbs = ('core');
  }
  foreach (@dbs) {
    my $T = $self->{data}->{_databases}->get_DBAdaptor($_,$self->real_species);
    $dba_hashref->{$_}=$T if $T;
  }
  @logic_names = (undef) unless @logic_names;
  my %features_to_grab;

## First let us look at feature IDs - these prediction transcript exons...
## Prediction transcript exons have form 
##   {prediction_transcript.display_xref}.{prediction_exon.exon_rank}
## Second let us look at groups IDs - these are either transcript ids' / gene ids'

## The following are exons ids'
  my $filters    = {};
  my $no_filters = {};
  foreach my $id (@ftids)  { $filters->{$id} = 'exon'; }
  foreach my $id (@groups) { $filters->{$id} = 'transcript'; }

## Finally let us loop through all the segments and retrieve all the
## Prediction transcripts...
  foreach my $segment (@segments) {
    if( ref($segment) eq 'HASH' && $segment->{'TYPE'} eq 'ERROR' ) {
      push @features, $segment;
      next;
    }
    foreach my $db_key ( keys %$dba_hashref ) {
      foreach my $logic_name (@logic_names) {
warn "$db_key...................$logic_name.............................";
        foreach my $gene ( @{$segment->slice->get_all_Genes($logic_name,$db_key) } ) {
          my $gsi = $gene->stable_id;
warn "$gsi.......................";
          $genes{ $gsi } = { 'db' => $db_key, 'obj' => $gene, 'transcripts' => [] };
          delete $filters->{$gsi};
          $no_filters->{$gsi} = 1;
          foreach my $transcript ( @{$gene->get_all_Transcripts} ) {
            my $tsi = $transcript->stable_id;
            my $transobj = { 'obj' => $transcript, 'exons' => [] };
            delete $filters->{$tsi};
            $no_filters->{$tsi} = 1;
            foreach my $exon ( @{$transcript->get_all_Exons} ) {
              my $esi = $exon->stable_id;
              delete $filters->{$esi};
              push @{ $transobj->{'exons'} }, $exon;
              $no_filters->{$esi} = 1;
            }
            push @{ $genes{$gsi}->{'transcripts'} },$transobj;
# warn "PUSHED transcript $tsi onto gene $gsi";
          }
        }
      }
    }
  }
## Now we have grabbed all these features on segments we can go back and see if
## we need to grab any more of the group_id / filter_id features...
  my $ga_hashref = {};

  foreach my $id ( keys %$filters ) {
    next unless $filters->{$id};
    my $gene;
    my $filter;
    my $db_key;
    foreach my $db ( keys %$dba_hashref ) {
#      foreach my $logic_name (@logic_names) {
        $db_key = $db;
        $ga_hashref->{$db} ||= $dba_hashref->{$db}->get_GeneAdaptor;
        if( $filters->{$id} eq 'exon' ) {
          $gene = $ga_hashref->{$db}->fetch_by_exon_stable_id( $id );
          $filter = 'exon';
        } elsif( $gene = $ga_hashref->{$db}->fetch_by_stable_id( $id ) ) {
          $filter = 'transcript';
        } else {
          $gene = $ga_hashref->{$db}->fetch_by_transcript_stable_id( $id );
          $filter = 'gene';
        }
        last if $gene;
#      }
#      last if $gene;
    }
    next unless $gene;
    my $gsi = $gene->stable_id;
    unless( exists $genes{$gsi} ) { ## Gene doesn't exist so we have to store it and grab transcripts and exons...
      $genes{ $gsi } = { 'obj' => $gene, 'transcripts' => [] };
      foreach my $transcript ( @{$gene->get_all_Transcripts} ) {
        my $tsi = $transcript->stable_id;
        my $transobj = { 'obj' => $transcript, 'exons' => [] };
        foreach my $exon ( @{$transcript->get_all_Exons} ) {
          my $esi = $exon->stable_id;
          push @{ $transobj->{'exons'} }, $exon;
        }
        push @{ $genes{$gsi}->{'transcripts'} },$transobj;
# warn "PU**ED transcript $tsi onto gene $gsi";
      }
    }
    if( $filter eq 'gene' ) { ## Delete all filters on Gene and subsequent exons
      delete $filters->{$gsi};
      $no_filters->{$gsi} = 1;
      foreach my $transobj ( @{ $genes{$gsi}{'transcripts'} } ) {
        my $transcript = $transobj->{'obj'}; 
        delete $filters->{$transcript->stable_id};
        $no_filters->{$transcript->stable_id} = 1;
        foreach my $exon ( @{$transobj->{'exons'}} ) {
          $no_filters->{$exon->stable_id} = 1;
          delete $filters->{$exon->stable_id};
        }
      }
    } elsif( $filter eq 'transcript' ) { ## Delete filter on Transcript...
      foreach my $transobj ( @{ $genes{$gsi}{'transcripts'} } ) {
        my $transcript = $transobj->{'obj'}; 
        next unless $transcript->stable_id eq $id;
        foreach my $exon ( @{$transobj->{'exons'}} ) {
          $no_filters->{$exon->stable_id} = 1;
          delete $filters->{$exon->stable_id};
        }
      }
    }

  }


## Transview template...
  my $transview_url = sprintf( '%s/%s/transview?transcript=%%s;db=%%s',
    $self->species_defs->ENSEMBL_BASE_URL, $self->real_species
  );
  my $geneview_url  = sprintf( '%s/%s/geneview?gene=%%s;db=%%s',
    $self->species_defs->ENSEMBL_BASE_URL, $self->real_species
  );
  my $protview_url  = sprintf( '%s/%s/protview?peptide=%%s;db=%%s',
    $self->species_defs->ENSEMBL_BASE_URL, $self->real_species
  );

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my %features;
  my %slice_hack;
  foreach my $gene_stable_id ( keys %genes ) {
    my $gene = $genes{$gene_stable_id}{'obj'};
    my $db   = $genes{$gene_stable_id}{'db'};
    my $gene_href = { 
      'href' => sprintf( $geneview_url, $gene_stable_id, $db ),
      'text' => sprintf( 'e! GeneView %s (%s)', $gene_stable_id, $gene->external_name || 'Novel' )
    };
    foreach my $transobj ( @{ $genes{$gene_stable_id}{'transcripts'} } ) {
      my $transcript = $transobj->{'obj'};
      my $transcript_stable_id = $transcript->stable_id;
      my $transcript_group = {
        'ID'    => $transcript_stable_id, 
        'TYPE'  => 'transcript:'.$transcript->analysis->logic_name,
        'LABEL' =>  sprintf( '%s (%s)', $transcript_stable_id, $transcript->external_name || 'Novel' ),
        'LINK'  => [{ 'href' => sprintf( $transview_url, $transcript_stable_id, $db ),
                      'text' => "e! TransView $transcript_stable_id" }, $gene_href  ]
      };
      if( $transcript->translation ) {
        push @{$transcript_group->{'LINK'}}, {
          'href' => sprintf( $protview_url, $transcript->translation->stable_id, $db ),
          'text' => "e! ProtView ".$transcript->translation->stable_id };
      } 
      my $coding_region_start = $transcript->coding_region_start;
      my $coding_region_end   = $transcript->coding_region_end;
      if( $transobj->{'exons'}[0]->slice->strand > 0 ) {
        $coding_region_start += $transobj->{'exons'}[0]->slice->start - 1;
        $coding_region_end   += $transobj->{'exons'}[0]->slice->start - 1;
      } else {
        $coding_region_start *= -1;
        $coding_region_end   *= -1;
        $coding_region_start += $transobj->{'exons'}[0]->slice->end + 1;
        $coding_region_end   += $transobj->{'exons'}[0]->slice->end + 1;
      }
      foreach my $exon ( @{$transobj->{'exons'}}) {
        my $exon_stable_id = $exon->stable_id;
        my $slice_name = $exon->slice->seq_region_name.':'.$exon->slice->start.','.$exon->slice->end.':'.$exon->slice->strand;
        unless( exists $features{$slice_name} ) {
          $features{$slice_name} = {
            'REGION' => $exon->slice->seq_region_name,
            'START'  => $exon->slice->start,
            'STOP'   => $exon->slice->end,
            'FEATURES' => [],
          };
## Offset and orientation multiplier for features to map them back to slice
## co-ordinates - based on the orientation of the slice.
#          if( $exon->slice->strand > 0 ) {
#            $slice_hack{$slice_name} = [  1, $features{$slice_name}{'START'}-1 ];
#          } else {
#            $slice_hack{$slice_name} = [ -1, $features{$slice_name}{'STOP'} +1 ];
#          }
        }
        
        unless( exists $no_filters->{$gene_stable_id} || exists $no_filters->{$transcript_stable_id } || exists $no_filters->{$gene_stable_id} ) { ## WE WILL DRAW THIS!!
          unless( exists $filters->{$exon_stable_id} || exists $filters->{$transcript_stable_id} ) {
            next;
          }
        }
## If we have an exon filter for this transcript... check that the rank is in the
## list if not skip the rest of this loop
## Push the features on to the slice specific array
## Now we have to work out the overlap with coding sequence...
        my $exon_start = $exon->seq_region_start;
        my $exon_end   = $exon->seq_region_end;
        my @sub_exons  = ();
        if( defined $coding_region_start ) {
          my $exon_coding_start;
          my $exon_coding_end;
          if( $exon->strand > 0 ) {
            if( $exon_start < $coding_region_end && $exon_end > $coding_region_start ) {
              $exon_coding_start = $exon_start < $coding_region_start ? $coding_region_start : $exon_start;
              $exon_coding_end   = $exon_end   > $coding_region_end   ? $coding_region_end   : $exon_end;
              if( $exon_start < $exon_coding_start ) {
                push @sub_exons, [ "5'UTR", $exon_start, $exon_coding_start - 1 ];
              }
              if( $exon_end > $exon_coding_end ) {
                push @sub_exons, [ "3'UTR", $exon_coding_end+1, $exon_end       ];
              }
              push @sub_exons, [ "coding", $exon_coding_start, $exon_coding_end ];
            } elsif( $exon_end < $coding_region_start ) {
              push @sub_exons, [ "5'UTR", $exon_start, $exon_end ];
            } else {
              push @sub_exons, [ "3'UTR", $exon_start, $exon_end ];
            }
          } else {
            if( $exon_start < $coding_region_end && $exon_end > $coding_region_start ) {
              $exon_coding_start = $exon_start < $coding_region_start ? $coding_region_start : $exon_start;
              $exon_coding_end   = $exon_end   > $coding_region_end   ? $coding_region_end   : $exon_end;
              if( $exon_start < $exon_coding_start ) {
                push @sub_exons, [ "5'UTR", $exon_start, $exon_coding_start - 1 ];
              }
              if( $exon_end > $exon_coding_end ) {
                push @sub_exons, [ "3'UTR", $exon_coding_end+1, $exon_end       ];
              }
              push @sub_exons, [ "coding", $exon_coding_start, $exon_coding_end ];
            } elsif( $exon_end < $coding_region_start ) {
              push @sub_exons, [ "5'UTR", $exon_start, $exon_end ];
            } else {
              push @sub_exons, [ "3'UTR", $exon_start, $exon_end ];
            }
          }
        } else { 
          @sub_exons = ( [ 'non_coding', $exon_start, $exon_end ] );
        }
        foreach my $se (@sub_exons ) {
          push @{$features{$slice_name}{'FEATURES'}}, {
           'ID'          => $exon_stable_id,
            'TYPE'        => 'exon:'.$transcript->analysis->logic_name,
            'METHOD'      => $transcript->analysis->logic_name,
            'CATEGORY'    => $se->[0],
            'START'       => $se->[1], # $slice_hack{$slice_name}[0] * $se->[1] + $slice_hack{$slice_name}[1],
            'END'         => $se->[2], # $slice_hack{$slice_name}[0] * $se->[2] + $slice_hack{$slice_name}[1],
            'ORIENTATION' => $self->ori($exon->strand), # slice_hack{$slice_name}[0] * $exon->strand > 0 ? '+' : '-',
            'GROUP'       => [$transcript_group]
          };
        }
      }
    }
  }
## Return the reference to an array of the slice specific hashes.
  push @features, values %features;
  return \@features;
}

sub Stylesheet {
  my $self = shift;
  my $stylesheet_structure = {};
  my $colour_hash = { 
    'default' => 'grey50',
    'havana'  => 'blue',
    'ensembl' => 'rust',
    'ensembl_havana_transcript' => 'gold1',
    'estgene' => 'violet',
    'otter'   => 'darkblue',
  };
  foreach my $key ( keys %$colour_hash ) {
    my $exon_key  = $key eq 'default' ? $key : "exon:$key";
    my $trans_key = $key eq 'default' ? $key : "transcript:$key";
    my $colour = $colour_hash->{$key};
    $stylesheet_structure->{"3'UTR"}{$exon_key}=
    $stylesheet_structure->{"5'UTR"}{$exon_key}=
    $stylesheet_structure->{"non_coding"}{$exon_key}=
      [{ 'type' => 'box', 'attrs' => { 'FGCOLOR' => $colour, 'BGCOLOR' => 'white', 'HEIGHT' => 6  } }];
    $stylesheet_structure->{"coding"}{$exon_key}=
      [{ 'type' => 'box', 'attrs' => { 'BGCOLOR' => $colour, 'FGCOLOR' => $colour, 'HEIGHT' => 10  } }];
    $stylesheet_structure->{"group"}{$trans_key}=
      [{ 'type' => 'line', 'attrs' => { 'STYLE' => 'intron', 'HEIGHT' => 10, 'FGCOLOR' => $colour, 'POINT' => 1 } }];
  }
  return $self->_Stylesheet( $stylesheet_structure );
}
1;
