package EnsEMBL::Web::Object::DAS::transcript;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Types {
### Returns a list of types served by this das source....
## Incomplete at present....
  my $self = shift;
  return [
    { 'id' => 'exon'  }
  ];
}

sub Features {
### Return das features...
### structure returned is an arrayref of hashrefs, each array element refers to
### a different segment, the hashrefs contain segment info (seg type, seg name,
### seg start, seg end) and an array of feature hashes

  my $self = shift;

###_ Part 1: initialize data structures...
  my @features;          ## Final array whose reference is returned - simplest way to handle errors/unknowns...
  my %features;          ## Temporary hash to store segments and features there on...
  my %genes;             ## Temporary hash to store ensembl gene objects...
  my $dba_hashref;       ## Hash ref of database handles...

## (although not implemented at the moment may allow multiple dbs to be connected to..)
  my @logic_names;       ## List of logic names of transcripts to return...

###_ Part 2: parse the DSN to work out what we want to display
### Relevant part of DSN is stored in $ENV{'ENSEMBL_DAS_SUBTYPE'}
###
### For transcripts -the format is:
###
###> {species}.ASSEMBLY[-{coordinate_system}]/[enhanced_]transcript[-{database}[-{logicname}]*]
###
### If database is missing assumes core, if logicname is missing assumes all
### transcript features
###
### e.g.
###
###* /das/Homo_sapiens.NCBI36-toplevel.transcript-core-ensembl
###
###* /das/Homo_sapiens.NCBI36-toplevel.transcript-vega
###

  my @dbs = ();
  if( $ENV{'ENSEMBL_DAS_SUBTYPE'} ) {
    my( $db, @logic_names ) = split /-/, $ENV{'ENSEMBL_DAS_SUBTYPE'};
    push @dbs, $db;
  } else {
    @dbs = ('core');  ## default = core...;
  }
  foreach (@dbs) {
    my $T = $self->{data}->{_databases}->get_DBAdaptor($_,$self->real_species);
    $dba_hashref->{$_}=$T if $T;
  }
  @logic_names = (undef) unless @logic_names;  ## default is all features of this type

###_ Part 3: parse CGI parameters to get out feature types, group ids and feature ids
###* FeatureTypes - Currently ignored...
###* Group IDs    - filter in this case transcripts
###* Feature IDs  - filter in ths case exons
  my @segments = $self->Locations;
  my %fts      = map { $_=>1 } grep { $_ } @{$self->FeatureTypes  || []};
  my @groups   =               grep { $_ } @{$self->GroupIDs      || []};
  my @ftids    =               grep { $_ } @{$self->FeatureIDs    || []};

  my $filters    = {
    map( { ( $_, 'exon'       ) } @ftids  ),  ## Filter for exon features...
    map( { ( $_, 'transcript' ) } @groups )   ## Filter for transcript features...
  };
  my $no_filters = {};

## First let us look at feature IDs - these prediction transcript exons...
## Prediction transcript exons have form 
##   {prediction_transcript.display_xref}.{prediction_exon.exon_rank}
## Second let us look at groups IDs - these are either transcript ids' / gene ids'

## The following are exons ids'

###_ Part 4: Fetch features on the segments requested...

  foreach my $segment (@segments) {
    if( ref($segment) eq 'HASH' && ($segment->{'TYPE'} eq 'ERROR' || $segment->{'TYPE'} eq 'UNKNOWN') ) {
      push @features, $segment;
      next;
    }
    my $slice_name = $segment->slice->seq_region_name.':'.$segment->slice->start.','.$segment->slice->end.':'.$segment->slice->strand;
## Each slice is added irrespective of whether there is any data, so we "push"
## on an empty slice entry...
    $features{$slice_name}= {
      'REGION'   => $segment->slice->seq_region_name,
      'START'    => $segment->slice->start,
      'STOP'     => $segment->slice->end,
      'FEATURES' => [],
    };

    foreach my $db_key ( keys %$dba_hashref ) {
      foreach my $logic_name (@logic_names) {
        foreach my $gene ( @{$segment->slice->get_all_Genes($logic_name,$db_key) } ) {
          my $gsi = $gene->stable_id;
          $genes{ $gsi } = { 'db' => $db_key, 'obj' => $gene, 'transcripts' => [] };
          delete $filters->{$gsi}; # This comes off a segment so make sure it isn't filtered!
          $no_filters->{$gsi} = 1;
          foreach my $transcript ( @{$gene->get_all_Transcripts} ) {
            my $tsi = $transcript->stable_id;
            my $transobj = { 'obj' => $transcript, 'exons' => [] };
            delete $filters->{$tsi}; # This comes off a segment so make sure it isn't filtered!
            $no_filters->{$tsi} = 1;
            my $start = 1;
            foreach my $exon ( @{$transcript->get_all_Exons} ) {
              my $esi = $exon->stable_id;
              delete $filters->{$esi}; # This comes off a segment so make sure it isn't filtered!
              push @{ $transobj->{'exons'} }, [ $exon , $start, $start+$exon->length-1 ];
              $start += $exon->length;
              $no_filters->{$esi} = 1;
            }
            push @{ $genes{$gsi}->{'transcripts'} },$transobj;
          }
        }
      }
    }
  } ## end of segment loop....

###_ Part 5: Fetch features based on group_id and filter_id

  my $ga_hashref = {};

  my %logic_name_filter = map { ($_,1) } @logic_names;
  foreach my $id ( keys %$filters ) {
    next unless $filters->{$id};
    my $gene;
    my $filter;
    my $db_key;
    foreach my $db ( keys %$dba_hashref ) {
#      foreach my $logic_name (@logic_names) { // should probably filter here - but have to do it post fetch!?!
      $db_key = $db;
      $ga_hashref->{$db} ||= $dba_hashref->{$db}->get_GeneAdaptor;
      if( $filters->{$id} eq 'exon' ) {
        $gene = $ga_hashref->{$db}->fetch_by_exon_stable_id( $id );
        $filter = 'exon';
      } elsif( $gene = $ga_hashref->{$db}->fetch_by_stable_id( $id ) ) {
        $filter = 'gene';
      } else {
        $gene = $ga_hashref->{$db}->fetch_by_transcript_stable_id( $id );
        $filter = 'transcript';
      }
      $gene = undef if $gene
                    && defined $logic_names[0]
                    && ! $logic_name_filter{$gene->analysis->logic_name};
      last if $gene;
    }
    next unless $gene;
    my $gsi = $gene->stable_id;
    unless( exists $genes{$gsi} ) { ## Gene doesn't exist so we have to store it and grab transcripts and exons...
      $genes{ $gsi } = { 'obj' => $gene, 'transcripts' => [] };
      foreach my $transcript ( @{$gene->get_all_Transcripts} ) {
        my $tsi = $transcript->stable_id;
        my $transobj = { 'obj' => $transcript, 'exons' => [] };
        my $start = 1;
        foreach my $exon ( @{$transcript->get_all_Exons} ) {
          my $esi = $exon->stable_id;
          push @{ $transobj->{'exons'} }, [ $exon , $start, $start+$exon->length-1 ];
          $start += $exon->length;
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
          $no_filters->{$exon->[0]->stable_id} = 1;
          delete $filters->{$exon->[0]->stable_id};
        }
      }
    } elsif( $filter eq 'transcript' ) { ## Delete filter on Transcript...
      foreach my $transobj ( @{ $genes{$gsi}{'transcripts'} } ) {
        my $transcript = $transobj->{'obj'}; 
        next unless $transcript->stable_id eq $id;
        foreach my $exon ( @{$transobj->{'exons'}} ) {
          $no_filters->{$exon->[0]->stable_id} = 1;
          delete $filters->{$exon->[0]->stable_id};
        }
      }
    }
  } ## end of segment loop....


## Transview template...
  $self->{'templates'} ||= {};
  $self->{'templates'}{'transview_URL'} = sprintf( '%s/%s/transview?transcript=%%s;db=%%s', $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );
  $self->{'templates'}{'geneview_URL'}  = sprintf( '%s/%s/geneview?gene=%%s;db=%%s',        $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );
  $self->{'templates'}{'protview_URL'}  = sprintf( '%s/%s/protview?peptide=%%s;db=%%s',     $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );
  $self->{'templates'}{'r_URL'}         = sprintf( '%s/%s/r?d=%%s;ID=%%s',                  $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );

### Part 6: Grab and return features
### Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my %slice_hack;
  foreach my $gene_stable_id ( keys %genes ) {
    my $gene = $genes{$gene_stable_id}{'obj'};
    my $db   = $genes{$gene_stable_id}{'db'};
    foreach my $transobj ( @{ $genes{$gene_stable_id}{'transcripts'} } ) {
      my $transcript = $transobj->{'obj'};
      my $transcript_stable_id = $transcript->stable_id;
      my $transcript_group = {
        'ID'    => $transcript_stable_id, 
        'TYPE'  => 'transcript:'.$transcript->analysis->logic_name,
        'LABEL' =>  sprintf( '%s (%s)', $transcript_stable_id, $transcript->external_name || 'Novel' ),
        $self->_group_info( $transcript, $gene, $db ) ## Over-riden in enhnced transcripts...
      };
      my $coding_region_start = $transcript->coding_region_start; ## Need this in "chr" coords
      my $coding_region_end   = $transcript->coding_region_end;   ## Need this in "chr" coords
      if( $transobj->{'exons'}[0][0]->slice->strand > 0 ) {
        $coding_region_start += $transobj->{'exons'}[0][0]->slice->start - 1;
        $coding_region_end   += $transobj->{'exons'}[0][0]->slice->start - 1;
      } else {
        $coding_region_start *= -1;
        $coding_region_end   *= -1;
        $coding_region_start += $transobj->{'exons'}[0][0]->slice->end + 1;
        $coding_region_end   += $transobj->{'exons'}[0][0]->slice->end + 1;
      }
      foreach my $exon_ref ( @{$transobj->{'exons'}}) {
        my $exon = $exon_ref->[0];
        my $exon_stable_id = $exon->stable_id;
        my $slice_name = $exon->slice->seq_region_name.':'.$exon->slice->start.','.$exon->slice->end.':'.$exon->slice->strand;
        unless( exists $features{$slice_name} ) {
          $features{$slice_name} = {
            'REGION' => $exon->slice->seq_region_name,
            'START'  => $exon->slice->start,
            'STOP'   => $exon->slice->end,
            'FEATURES' => [],
          };
        }
        
        unless( exists $no_filters->{$gene_stable_id} || exists $no_filters->{$transcript_stable_id } || exists $no_filters->{$gene_stable_id} ) { ## WE WILL DRAW THIS!!
          unless( exists $filters->{$exon_stable_id} || exists $filters->{$transcript_stable_id} ) {
            next;
          }
        }
## Push the features on to the slice specific array
## Now we have to work out the overlap with coding sequence...
        my $exon_start = $exon->seq_region_start;
        my $exon_end   = $exon->seq_region_end;
        my @sub_exons  = ();
        if( defined $coding_region_start ) { ## Translatable genes...
          my $exon_coding_start;
          my $exon_coding_end;
          my $target_start;
          my $target_end;
          if( $exon->strand > 0 ) { ## Forward strand...
            if( $exon_start < $coding_region_end && $exon_end > $coding_region_start ) {
              $exon_coding_start = $exon_start < $coding_region_start ? $coding_region_start : $exon_start;
              $exon_coding_end   = $exon_end   > $coding_region_end   ? $coding_region_end   : $exon_end;
              $target_start      = $exon_start < $coding_region_start ? $coding_region_start - $exon_start + $exon_ref->[1] : $exon_ref->[1];
              $target_end        = $exon_end   > $coding_region_end   ? $coding_region_end   - $exon_start + $exon_ref->[1] : $exon_ref->[2];
              if( $exon_end > $exon_coding_end ) {
                push @sub_exons, [ "3'UTR", $exon_coding_end+1, $exon_end      , $target_end +1, $exon_ref->[2]  ];
              }
              push @sub_exons, [ "coding", $exon_coding_start, $exon_coding_end, $target_start, $target_end ];
              if( $exon_start < $exon_coding_start ) {
                push @sub_exons, [ "5'UTR", $exon_start, $exon_coding_start - 1, $exon_ref->[1], $target_start - 1 ];
              }
            } elsif( $exon_end < $coding_region_start ) {
              push @sub_exons, [ "5'UTR", $exon_start, $exon_end,                $exon_ref->[1], $exon_ref->[2] ];
            } else {
              push @sub_exons, [ "3'UTR", $exon_start, $exon_end,                $exon_ref->[1], $exon_ref->[2] ];
            }
          } else {  ## Reverse strand...
            if( $exon_start < $coding_region_end && $exon_end > $coding_region_start ) {
              $exon_coding_start = $exon_start < $coding_region_start ? $coding_region_start : $exon_start;
              $exon_coding_end   = $exon_end   > $coding_region_end   ? $coding_region_end   : $exon_end;
              $target_start      = $exon_start < $coding_region_start ? $coding_region_start - $exon_start + $exon_ref->[1] : $exon_ref->[1];
              $target_end        = $exon_end   > $coding_region_end   ? $coding_region_end   - $exon_start + $exon_ref->[1] : $exon_ref->[2];
              if( $exon_end > $exon_coding_end ) {
                push @sub_exons, [ "3'UTR", $exon_coding_end+1, $exon_end      , $exon_ref->[1], $target_start - 1  ];
              }
              push @sub_exons, [ "coding", $exon_coding_start, $exon_coding_end, $target_start, $target_end ];
              if( $exon_start < $exon_coding_start ) {
                push @sub_exons, [ "5'UTR", $exon_start, $exon_coding_start - 1, $target_end+1, $exon_ref->[2] ];
              }
            } elsif( $exon_end < $coding_region_start ) {
              push @sub_exons, [ "5'UTR", $exon_start, $exon_end,                $exon_ref->[1], $exon_ref->[2] ];
            } else {
              push @sub_exons, [ "3'UTR", $exon_start, $exon_end,                $exon_ref->[1], $exon_ref->[2] ];
            }
          }
        } else {  ## Easier one... non-translatable genes...
          @sub_exons = ( [ 'non_coding', $exon_start, $exon_end ] );
        }
        foreach my $se (@sub_exons ) {
          push @{$features{$slice_name}{'FEATURES'}}, {
           'ID'          => $exon_stable_id,
            'TYPE'        => 'exon:'.$se->[0].':'.$transcript->analysis->logic_name,
            'METHOD'      => $transcript->analysis->logic_name,
            'CATEGORY'    => 'transcription',
            'START'       => $se->[1],
            'END'         => $se->[2],
            'ORIENTATION' => $self->ori($exon->strand),
            'GROUP'       => [$transcript_group],
            'TARGET'      => {
              'ID'    => $transcript_stable_id,
              'START' => $se->[3], 
              'STOP'  => $se->[4]
            }
          };
        }
      }
    }
  }
### Part 7: Return the reference to an array of the slice specific hashes.
  push @features, values %features;
  return \@features;
}

sub _group_info {
## Return the links... note main difference between two tracks is the "enhanced transcript" returns more links (GV/PV) and external entries...
  my( $self, $transcript, $gene, $db ) = @_;
  return
    'LINK' => [ { 'text' => 'e! TransView '.$transcript->stable_id ,
                  'href' => sprintf( $self->{'templates'}{'transview_URL'}, $transcript->stable_id, $db ) }
    ];
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
    my $colour = $colour_hash->{$key};
    $stylesheet_structure->{"transcription"}{$key ne 'default' ? "exon:3'UTR:$key" : 'default'}=
    $stylesheet_structure->{"transcription"}{$key ne 'default' ? "exon:5'UTR:$key" : 'default'}=
    $stylesheet_structure->{"transcription"}{$key ne 'default' ? "exon:non_coding:$key" : 'default'}=
      [{ 'type' => 'box', 'attrs' => { 'FGCOLOR' => $colour, 'BGCOLOR' => 'white', 'HEIGHT' => 6  } },
      ];
    $stylesheet_structure->{'transcription'}{$key ne 'default' ? "exon:coding:$key" : 'default'} =
      [{ 'type' => 'box', 'attrs' => { 'BGCOLOR' => $colour, 'FGCOLOR' => $colour, 'HEIGHT' => 10  } }];
    $stylesheet_structure->{"group"}{$key ne 'default' ? "transcript:$key" : 'default'} =
      [{ 'type' => 'line', 'attrs' => { 'STYLE' => 'intron', 'HEIGHT' => 10, 'FGCOLOR' => $colour, 'POINT' => 1 } }];
  }
  return $self->_Stylesheet( $stylesheet_structure );
}
1;
