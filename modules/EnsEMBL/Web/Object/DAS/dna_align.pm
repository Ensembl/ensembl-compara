package EnsEMBL::Web::Object::DAS::dna_align;

use strict;
use warnings;

use EnsEMBL::Web::Object::DAS;
our @ISA = qw(EnsEMBL::Web::Object::DAS);

sub Types {
  my $self = shift;
  return [
    { 'id' => 'dna alignment'  }
  ];
}

sub Features {
### Return das features...
  my $self = shift;
  return $self->_features( 'DnaAlignFeature', 'dna alignment' );
}
sub _features {
### Return das features...
  my( $self, $feature_type, $feature_label ) = @_;

  $self->{_feature_label} = $feature_label;
  my @segments = $self->Locations;
  my %fts    = map { $_=>1 } grep { $_ } @{$self->FeatureTypes  || []};
  my @ftids  =               grep { $_ } @{$self->GroupIDs      || []}, @{$self->FeatureIDs    || []};

  my $dba_hashref;
  my @dbs = qw(core vega otherfeatures);
  my( $db, @logic_names ) = split /-/, $ENV{'ENSEMBL_DAS_SUBTYPE'};
  $db = 'core' unless $db;;
  my @features;
  foreach ($db) {
    my $T = $self->{data}->{_databases}->get_DBAdaptor($_,$self->real_species);
    warn "$_ $T";
    $dba_hashref->{$_}=$T if $T;
  }
  @logic_names = (undef) unless @logic_names;
  warn "restriction to db $db + logicnames (@logic_names)";
## First let us look at feature IDs - these prediction transcript exons...
## Prediction transcript exons have form 
##   {prediction_transcript.display_xref}.{prediction_exon.exon_rank}
## Second let us look at groups IDs - these are either transcript ids' / gene ids'

## The following are exons ids'
## Finally let us loop through all the segments and retrieve all the
## Prediction transcripts...
  $self->{'featureview_url'} = sprintf( '%s/%s/featureview?type=%s;id=%%s',
    $self->species_defs->ENSEMBL_BASE_URL, $self->real_species, $feature_type
  );
  $self->{'r_url'} = sprintf( '%s/%s/r?d=%%s;id=%%s',
    $self->species_defs->ENSEMBL_BASE_URL, $self->real_species
  );
  $self->{'_features'} = {};
  $self->{'_slice_hack'} = {};
  my $call         = "get_all_$feature_type".'s';
  my $adapter_call = "get_$feature_type".'Adaptor';
  foreach my $segment (@segments) {
    if( ref($segment) eq 'HASH' && $segment->{'TYPE'} eq 'ERROR' ) {
      push @features, $segment;
      next;
    }
    foreach my $db_key ( keys %$dba_hashref ) {
      foreach my $logic_name (@logic_names) { 
        foreach my $align ( @{$segment->slice->$call($logic_name,undef,$db_key) } ) {
warn "PUSHING FEATURE $align";
          $self->_feature( $align );
        }
      }
    }
  }
  my $dafa_hashref = {};
  foreach my $id ( @ftids ) {
warn "looking for $id ",keys(%$dba_hashref);
    foreach my $db ( keys %$dba_hashref ) {
warn "$db @logic_names";
      $dafa_hashref->{$db} ||= $dba_hashref->{$db}->$adapter_call;
      foreach my $logic_name (@logic_names) { 
        foreach my $align ( @{$dafa_hashref->{$db}->fetch_all_by_hit_name( $id, $logic_name )} ) {
          $self->_feature( $align );
        }
      }
    }
  }
  push @features, values %{ $self->{'_features'} };
  return \@features;
}

sub _feature {
  my( $self, $f ) = @_;

## Now we do all the nasty stuff of retrieving features and creating DAS objects for them...
  my $fid           = $f->hseqname;
  my $type          = $f->analysis->logic_name;
  my $display_label = $f->analysis->display_label;
  my $group = {
    'ID'    => $fid, 
    'TYPE'  => "$self->{_feature_label}:$type",
    'LABEL' =>  sprintf( '%s (%s)', $display_label, $fid ),
    'LINK'  => [{
      'href' => sprintf( $self->{'featureview_url'}, $fid ),
      'text' => "e! FeatureView $fid" 
    },{
      'href' => sprintf( $self->{'r_url'}, $type, $fid ),
      'text' => "$display_label $fid" 
    }]
  };
  my $slice_name = $f->slice->seq_region_name.':'.$f->slice->start.','.$f->slice->end.':'.$f->slice->strand;
  unless( exists $self->{_features}{$slice_name} ) {
    $self->{_features}{$slice_name} = {
      'REGION' => $f->slice->seq_region_name,
      'START'  => $f->slice->start,
      'STOP'   => $f->slice->end,
      'FEATURES' => [],
    };
    if( $f->slice->strand > 0 ) {
      $self->{_slice_hack}{$slice_name} = [  1, $self->{_features}{$slice_name}{'START'}-1 ];
    } else {
      $self->{_slice_hack}{$slice_name} = [ -1, $self->{_features}{$slice_name}{'STOP'} +1 ];
    }
  }
  push @{$self->{_features}{$slice_name}{'FEATURES'}}, {
   'ID'          => $fid.' ('.$f->hstart.'-'.$f->hend.':'.$f->hstrand.')',
   'TYPE'        => "$self->{_feature_label}:$type",
   'METHOD'      => $type,
   'CATEGORY'    => $type,
   'START'       => $self->{_slice_hack}{$slice_name}[0] * $f->start + $self->{_slice_hack}{$slice_name}[1],
   'END'         => $self->{_slice_hack}{$slice_name}[0] * $f->end   + $self->{_slice_hack}{$slice_name}[1],
   'ORIENTATION' => $self->{_slice_hack}{$slice_name}[0] * $f->strand > 0 ? '+' : '-',
   'GROUP'       => [$group]
  };
## Return the reference to an array of the slice specific hashes.
}

sub Stylesheet {
  my $self = shift;
  my $stylesheet_structure = {};
  return $self->_Stylesheet( $stylesheet_structure );
}
1;
