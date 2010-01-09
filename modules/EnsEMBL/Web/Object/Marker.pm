package EnsEMBL::Web::Object::Marker;

### NAME: EnsEMBL::Web::Object::Marker
### Wrapper around a Bio::EnsEMBL::Marker object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### It is not clear if this module is in use any more, though its
### functionality may be worth reviving!

### DESCRIPTION


use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);

sub marker { 
  my $self = shift;
  return $self->Obj;
}

sub markerSynonym {
  my $self = shift;
  my $obj  = $self->Obj;
  if( $obj ) {
    my $dms = $self->Obj->display_MarkerSynonym;
    return $dms if $dms;
  }
  my $temp = $self->markerSynonyms;
  return $temp->{'main'}[0]  if @{$temp->{'main'}};
  return $temp->{'other'}[0] if @{$temp->{'other'}};
  return undef; 
}

sub name{ 
  my $self = shift;
  my $dms = $self->markerSynonym;
  return $dms ? $dms->name : '';
}

sub source{ 
  my $self = shift;
  my $dms = $self->markerSynonym;
  return $dms ? $dms->source : '';
}

sub dbID {
  my $self = shift;
  return $self->Obj->dbID;
}


sub markerFeatures {
  my $self = shift;
  unless ($self->__data->{'_markerFeatures'}){
    my $db =  $self->database('core');
    my $feats = $self->Obj->get_all_MarkerFeatures;
    my $count = scalar(@$feats);
    my $MAX_MAP_WEIGHT = 4;
    if($count <= $MAX_MAP_WEIGHT) {
      $self->__data->{'_markerFeatures'} = [ map { $_->transform('toplevel')||() } @$feats ];
    }
  }
  return $self->__data->{'_markerFeatures'} ;
}

sub markerSynonyms {
  my $self = shift;
  my @synonyms;
  my $return = { 'main' => [], 'other' => [] };
  my %IS_IMPORTANT = map { $_, 1 } qw( rgd oxford unists mgi:markersymbol );

  unless( $self->__data->{'_markerSynonyms'} ){
#pick out the important synonyms
    foreach my $ms ( @{ $self->Obj->get_all_MarkerSynonyms } ) {
      push @{ $return->{ $IS_IMPORTANT{ lc($ms->source) } ? 'main' : 'other' } }, $ms;
    }        
    $self->__data->{'_markerSynonyms'} = $return;
  }
  return $self->__data->{'_markerSynonyms'} ;
}

sub markerMapLocations {
  my $self = shift;
  unless( $self->__data->{'_markerLocations'} ) {
    my $marker_obj = $self->Obj;
    my @mlocs = @{$marker_obj->get_all_MapLocations};
    $self->__data->{'_markerLocations'} = \@mlocs
  }
  return $self->__data->{'_markerLocations'};
}

sub _seq_region_ {
  my $self = shift;
  unless( $self->{'_region_array_'} ) { 
    my $ML = $self->markerFeatures;
    if( $ML && @$ML ) {
      $self->{'_region_array_'} = [ $ML->[0]->slice->coord_system->name, $ML->[0]->seq_region_name, $ML->[0]->start, $ML->[0]->end, $ML->[0]->strand ];
    } else {
      $self->{'_region_array_'} = [];
    }
  }
  return @{$self->{'_region_array_'}};
}

sub location_string {
  my( $type, $sr,$st,$en) = $_[0]->_seq_region_;
  if( $type ) {
    return "$sr:@{[$st-1000]}-@{[$en+1000]}";
  } else {
    return undef;
  }
}
sub seq_region_type   { return [$_[0]->_seq_region_]->[0]; }
sub seq_region_name   { return [$_[0]->_seq_region_]->[1]; }
sub seq_region_start  { return [$_[0]->_seq_region_]->[2]; }
sub seq_region_end    { return [$_[0]->_seq_region_]->[3]; }
sub seq_region_strand { return [$_[0]->_seq_region_]->[4]; }

sub chromosome {
  my $self = shift;
  my $ML = $self->markerFeatures;
  return undef unless @$ML;
  return undef if $ML->[0]->slice->coord_system->name ne 'chromosome';
  return $ML->[0]->seq_region_name;
}

sub spreadsheet_markerMapLocations{
  my $self = shift;
  my $mlocs = $self->markerMapLocations( $self );
  my @map_locs;
  foreach my $ml (@$mlocs) {
    push @map_locs, {
      'map' => $ml->map_name, 
      'syn' => $ml->name || '-', 
      'chr' => $ml->chromosome_name || '&nbsp;' , 
      'pos' => $ml->position || '-', 
      'lod' => $ml->lod_score || '-',
    }
  }
  return \@map_locs;
}

1;
