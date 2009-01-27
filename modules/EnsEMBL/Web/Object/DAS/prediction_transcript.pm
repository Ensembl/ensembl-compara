package EnsEMBL::Web::Object::DAS::prediction_transcript;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;

  my $features = [
    { 'id' => 'exon:Genscan',    'method' => 'Genscan',    'text' => "Ab initio prediction of protein coding genes by Genscan (C. Burge et. al., J. Mol. Biol. 1997 268:78-94). The splice site models used are described in more detail in C. Burge, Modelling dependencies in pre-mRNA splicing signals. 1998 In Salzberg, S., Searls, D. and Kasif, S., eds. Computational Methods in Molecular Biology, Elsevier Science, Amsterdam, 127-163." },
    { 'id' => 'exon:SNAP',       'method' => 'SNAP',       'text' => "Ab initio gene prediction by SNAP (I. Korf, BMC Bioinformatics 2004 5:59)" },
    { 'id' => 'exon:GeneFinder', 'method' => 'GeneFinder', 'text' => "Ab initio prediction of protein coding genes by Genefinder (C. Wilson, L. Hilyer, and P. Green, unpublished)." },
    { 'id' => 'exon:Fgenesh',    'method' => 'Fgenesh',    'text' => "Ab initio prediction of protein coding genes (AA Salamov et al., Genome Res. 2000 4:516-22)" },
    { 'id' => 'exon:GSC',        'method' => 'GSC',        'text' => "Ab initio prediction of protein coding genes by Genscan (C. Burge et al., J. Mol. Biol. 1997 268:78-94), with parameters customised for accuracy in Tetraodon sequences" },
    { 'id' => 'exon:GID',        'method' => 'GID',        'text' => "Ab initio prediction of protein coding genes by geneid (http://www1.imim.es/software/geneid/), with parameters customised for accuracy in Tetraodon sequences." },
    { 'id' => 'exon:GWS_H',      'method' => 'GWS_H',      'text' => "Alignment of a human protein to the genome by GeneWise (E. Birney et al., Genome Res. 2004 14:988-95)" },
    { 'id' => 'exon:GWS_S',      'method' => 'GWS_S',      'text' => "Alignment of a mouse protein to the genome by GeneWise (E. Birney et al., Genome Res. 2004 14:988-95)" },
  ];

  return [
	  {
	      'REGION' => '*',
	      'FEATURES' => $features
	      }
	  ];
}

sub Stylesheet {
  my $self = shift;
  my $stylesheet_structure = {};
  my $colour_hash = { 
    'default'    => 'black',
    'Genscan'    => 'lightseagreen',
    'Fgenesh'    => 'darkkhaki',
    'SNAP'       => 'darkseagreen4',
    'GeneFinder' => 'black',
    'GSC'        => 'black',
    'GID'        => 'black',
    'GWS_H'      => 'black',
    'GWS_S'      => 'black',
  };
  foreach my $key ( keys %$colour_hash ) {
    my $colour = $colour_hash->{$key};
    $stylesheet_structure->{'transcription'}{$key ne 'default' ? "exon:$key" : 'default'} =
      [{ 'type' => 'box', 'attrs' => { 'BGCOLOR' => $colour, 'FGCOLOR' => $colour, 'HEIGHT' => 10  } }];
    $stylesheet_structure->{"group"}{$key ne 'default' ? "transcript:$key" : 'default'} =
      [{ 'type' => 'line', 'attrs' => { 'STYLE' => 'intron', 'HEIGHT' => 10, 'FGCOLOR' => $colour, 'POINT' => 1 } }];
  }
  return $self->_Stylesheet( $stylesheet_structure );
}

sub Features {
### Return das features...
  my $self = shift;

  my @segments = $self->Locations;
  my @features;
  my %fts    = map { $_=>1 } grep { $_ } @{$self->FeatureTypes  || []};
  my @groups = grep { $_ } @{$self->GroupIDs      || []};
  my @ftids  = grep { $_ } @{$self->FeatureIDs    || []};

  my $dba_hashref = { map {
    ( $_ => $self->{data}->{_databases}->{_dbs}->{ $self->real_species }->{$_} )
  } qw(core) };
  my %transcripts_to_grab;

## First let us look at feature IDs - these prediction transcript exons...
## Prediction transcript exons have form 
##   {prediction_transcript.display_label}.{prediction_exon.exon_rank}
  foreach my $id (@ftids) {
    if( $id =~ /^(.*)\.(\d+)/) {
      $transcripts_to_grab{ $1  }{ 'FILTER' }{ $2 } = 1;
    }
  }

## Second let us look at groups IDs - these are prediction transcript ids'
  foreach my $id (@groups) {
    $transcripts_to_grab{ $id }{ 'NO_FILTER' } = 1 ;
  }

## Finally let us loop through all the segments and retrieve all the
## Prediction transcripts...
  foreach my $segment (@segments) {
    if( ref($segment) eq 'HASH' && $segment->{'TYPE'} eq 'ERROR' ) {
      push @features, $segment;
      next;
    }
    foreach my $prediction_transcript ( @{$segment->slice->get_all_PredictionTranscripts} ) {
      $transcripts_to_grab{ $prediction_transcript->display_label }{ 'NO_FILTER' } = 1;
      $transcripts_to_grab{ $prediction_transcript->display_label }{ 'TRANS' } = $prediction_transcript;
    }
  }

## Now we have grabbed all these features on segments we can go back and see if
## we need to grab any more of the group_id / filter_id features...
  my $pta_hashref = {};
  foreach my $display_label ( keys %transcripts_to_grab ) {
    next if exists $transcripts_to_grab{ $display_label }{'TRANS'};
    foreach my $db ( keys %$dba_hashref ) {
      $pta_hashref->{$db} ||= $dba_hashref->{$db}->get_PredictionTranscriptAdaptor;
      last if $transcripts_to_grab{ $display_label }{'TRANS'} = $pta_hashref->{$db}->fetch_by_stable_id( $display_label );
    }
  }

## Transview template...
  my $transview_url = sprintf( '%s/%s/Transcript/Summary?t=%%s',
    $self->species_defs->ENSEMBL_BASE_URL, $self->real_species
  );

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my %features = ();
  my %slice_hack = ();
  foreach my $display_label ( keys %transcripts_to_grab ) {
    my $pt = $transcripts_to_grab{ $display_label }{ 'TRANS' };
    my $exons = $pt->get_all_Exons();
    my $rank = 0;
    my $end = 1;
    foreach my $exon (@$exons) {
      $rank++;
      my $start = $end;
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
      }
      $end += $exon->length;
## If we have an exon filter for this transcript... check that the rank is in the
## list if not skip the rest of this loop
      if( !exists( $transcripts_to_grab{$display_label}{'NO_FILTER'} ) ) {
        my $flag = 0;
        foreach( keys %{$transcripts_to_grab{$display_label}{'FILTER'}} ) {
          $flag = 1 if $rank == $_;
        }
        next unless $flag;
      }
## Push the features on to the slice specific array
      push @{$features{$slice_name}{'FEATURES'}}, {
        'ID'          => $display_label.'.'.$rank, 
        'TYPE'        => 'exon:'.$pt->analysis->logic_name,
        'METHOD'      => $pt->analysis->logic_name,
        'CATEGORY'    => 'transcription',
        'START'       => $exon->seq_region_start,
        'END'         => $exon->seq_region_end,
        'ORIENTATION' => $self->ori($exon->seq_region_strand),
        'TARGET'      => {
          'ID'          => $display_label,
          'START'       => $start,
          'STOP'        => $end-1,
          'ORIENTATION' => '+',
        },
        'GROUP'       => [{
          'ID'        => $display_label,
          'TYPE'      => 'transcript:'.$pt->analysis->logic_name,
          'LABEL'     => $display_label,
          'LINK'      => [{
            'href'    => sprintf( $transview_url, $display_label ),
            'text'    => 'View Transcript Summary'
          }]
        }]
      };
    }
    warn "$display_label\n";
  }
## Return the reference to an array of the slice specific hashes.
  push @features, values %features;
  return \@features;
}

1;
