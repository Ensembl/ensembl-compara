package EnsEMBL::Web::Object::DAS::prediction_transcripts;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;
  my $features = [
    ['exon', '', '', '']
  ];
  return $features;
}

sub Features {
### Return das features...
  my $self = shift;

  my @segments = $self->Locations;
  my @features;
  my %fts    = map { $_=>1 } grep { $_ } @{$self->FeatureTypes  || []};
  my @groups = grep { $_ } @{$self->GroupIDs      || []};
  my @ftids  = grep { $_ } @{$self->FeatureIDs    || []};

  my $dba = $self->{data}->{_databases}->{_dbs}->{ $self->real_species }->{'core'};

  my %transcripts_to_grab;

## First let us look at feature IDs - these prediction transcript exons...
## Prediction transcript exons have form 
##   {prediction_transcript.display_label}.{prediction_exon.exon_rank}
  foreach my $id (@groups) {
    $transcripts_to_grab{ $id }{ 'ID' } = 1;
    $transcripts_to_grab{ $id }{ 'NO_FILTER' } = 1 ;
  }

## Second let us look at groups IDs - these are prediction transcript ids'
  foreach my $id (@ftids) {
    if( $id =~ /^(.*)\.(\d+)/) {
      $transcripts_to_grab{ $1  }{ 'ID' }           = 1;
      $transcripts_to_grab{ $1  }{ 'FILTER' }{ $2 } = 1 
    }
  }

## Finally let us loop through all the segments and retrieve all the
## Prediction transcripts...
  foreach my $segment (@segments) {
    if( ref($segment) eq 'HASH' && $segment->{'TYPE'} eq 'ERROR' ) {
      push @features, $segment;
      next;
    }
    foreach my $prediction_transcript ( @{$segment->slice->get_all_PredictionTranscripts} ) {
      $transcripts_to_grab{ $prediction_transcript->display_label }{ 'NO_FILTER' } = 1 ;
      $transcripts_to_grab{ $prediction_transcript->display_label }{ 'TRANS' } = $prediction_transcript;
    }
  }

## Now we have grabbed all these features on segments we can go back and see if
## we need to grab any more of the group_id / filter_id features...
  my $pta = undef;
  foreach my $display_label ( keys %transcripts_to_grab ) {
    next if exists $transcripts_to_grab{ $display_label }{'TRANS'};
    $pta ||= $self->{data}->{_databases}->{_dbs}->{ $self->real_species }->{'core'}->get_PredictionTranscriptAdaptor;
    $transcripts_to_grab{ $display_label }{'TRANS'} = $pta->fetch_by_stable_id( $display_label );
  }

## Transview template...
  my $transview_url = sprintf( '%s/%s/transview?transcript=%%s', $self->species_defs->ENSEMBL_BASE_URL, $self->real_species );

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my %features = ();
  foreach my $display_label ( keys %transcripts_to_grab ) {
    my $pt = $transcripts_to_grab{ $display_label }{ 'TRANS' };
    my $exons = $pt->get_all_Exons();
    my $rank = 0;
    foreach my $exon (@$exons) {
      $rank++;
      my $slice_name = $exon->slice->seq_region_name.':'.$exon->slice->start.','.$exon->slice->end;
      unless( exists $features{$slice_name} ) {
        $features{$slice_name} = {
          'REGION' => $exon->slice->seq_region_name,
          'START'  => $exon->slice->start,
          'STOP'   => $exon->slice->end,
          'FEATURES' => [],
        };
      }
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
        'ID'     => $display_label.'.'.$rank,
        'TYPE'   => 'exon',
        'METHOD' => $pt->analysis->logic_name,
        'START'  => $exon->start + $features{$slice_name}{'START'}-1,
        'END'    => $exon->end   + $features{$slice_name}{'START'}-1,
        'ORIENTATION' => $exon->strand > 0 ? '+' : '-',
        'GROUP'  => [{
          'ID'   => $display_label,
          'TYPE' => 'prediction transcript',
          'LABEL' => $display_label,
          'LINK' => [{
            'href' => sprintf($transview_url, $display_label ),
            'text' => 'View feature in e! TransView'
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
