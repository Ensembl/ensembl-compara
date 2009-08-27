package EnsEMBL::Web::Object::Regulation;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::Object;
our @ISA = qw(EnsEMBL::Web::Object);

sub short_caption {
  my $self = shift;
  return "Regulation-based displays";
}

sub caption {
  my $self = shift;
  my $caption = 'Regulatory Feature: '. $self->Obj->stable_id;
  return $caption;    
}

sub availability {
  my $self = shift;
  my $hash = $self->_availability;
  if ($self->Obj->isa('Bio::EnsEMBL::Funcgen::RegulatoryFeature')){
    $hash->{'regulation'} =1;
  }
  return $hash;
}

sub counts {
  my $self = shift;
  my $obj = $self->Obj;
  return {} unless $obj->isa('Bio::EnsEMBL::Funcgen::RegulatoryFeature');
  return {};  
}

sub _adaptor {
  my $self = shift;
  return $self->database('funcgen')->get_RegulatoryFeatureAdaptor;
}

sub regulation           { my $self = shift; return $self->Obj;                            }
sub display_label         { my $self = shift; return $self->Obj->display_label;             }
sub stable_id             { my $self = shift; return $self->Obj->stable_id;                 }
sub analysis              { my $self = shift; return $self->Obj->analysis;                  }
sub attributes            { my $self = shift; return $self->Obj->regulatory_attributes;     }
sub bound_start           { my $self = shift; return $self->Obj->bound_start;               }
sub bound_end             { my $self = shift; return $self->Obj->bound_end;                 }
sub coord_system          { my $self = shift; return $self->Obj->slice->coord_system->name; }
sub seq_region_type       { my $self = shift; return $self->coord_system;                   }
sub seq_region_name       { my $self = shift; return $self->Obj->slice->seq_region_name;    }
sub seq_region_start      { my $self = shift; return $self->Obj->start;                     }
sub seq_region_end        { my $self = shift; return $self->Obj->end;                       }
sub seq_region_strand     { my $self = shift; return $self->Obj->strand;                    }
sub feature_set           { my $self = shift; return $self->Obj->feature_set;               }   
sub feature_type          { my $self = shift; return $self->Obj->feature_type;              }
sub slice                 { my $self = shift; return $self->Obj->slice;                     }           
sub seq_region_length     { my $self = shift; return $self->Obj->slice->seq_region_length;  }


sub get_attribute_list {
  my $self = shift;
  my @attrib_feats = @{$self->attributes};
  return '-' unless @attrib_feats; 
  my @temp = map $_->feature_type->name(), @attrib_feats;
  my %att_label;
  my $c = 1;
  foreach my $k (@temp){ 
    if (exists  $att_label{$k}) {
      my $old = $att_label{$k};
      $old++;
      $att_label{$k} = $old;
    } else {
        $att_label{$k} = $c;
    }
  }
  my $attrib_list = "";
  foreach my $k (keys %att_label){
    my $v = $att_label{$k};
    $attrib_list .= "$k($v), ";
  }
  $attrib_list =~s/\,\s$//;

  return $attrib_list;
}

sub get_fg_db {
  my $self = shift;
  return $self->database('funcgen');
}

sub get_feature_sets {
  my $self = shift;  
  my $fg_db = $self->get_fg_db;
  my @fsets;
  my $feature_set_adaptor = $fg_db->get_FeatureSetAdaptor;

  my @sources;
  my $spp = $ENV{'ENSEMBL_SPECIES'};
  if ($spp eq 'Homo_sapiens'){
   @sources = ('RegulatoryFeatures', 'miRanda miRNA targets', 'cisRED search regions', 'cisRED motifs', 'VISTA enhancer set');
  } elsif ($spp eq 'Mus_musculus'){
   @sources = ('cisRED search regions', 'cisRED motifs');
  }
  elsif ($spp eq 'Drosophila_melanogaster'){
   @sources = ('BioTIFFIN motifs', 'REDfly CRMs', 'REDfly TFBSs');
  }

  foreach my $name ( @sources){
    push @fsets, $feature_set_adaptor->fetch_by_name($name);
  }
  return \@fsets;
}

sub get_location_url {
  my $self= shift;
  my $url = $self->_url({
    'type'  => 'Location',
    'view'  => 'View',
    'rf'    => $self->stable_id,
    'fdb'   => 'funcgen',
    'r'     => $self->location_string,
  });
  return $url;
}

sub get_regulation_slice {
  my $self = shift;
  my $slice = $self->Obj->feature_Slice;
  return 1 unless $slice;
  my $T = new EnsEMBL::Web::Proxy::Object( 'Slice', $slice, $self->__data );
  return $T;  
}

sub get_seq {
  my ($self, $strand) = @_;
  $self->Obj->{'strand'} = $strand;
  return $self->Obj->seq; 
}

sub get_summary_page_url {
  my $self = shift; 
  my $url = $self->_url({
    'type'  => 'Regulation',
    'view'  => 'Summary',
    'rf'    => $self->stable_id,
    'fdb'   => 'funcgen',
  });
  return $url;
}

sub get_bound_context_slice {
  my $self = shift;
  my $padding = shift || 1000;
  my $slice = $self->Obj->feature_Slice;
  my $offset_start = $self->bound_start -200;
  my $offset_end = $self->bound_end + 200;
  
  my $padding_start = $slice->start - $offset_start;
  my $padding_end = $offset_end - $slice->end;
  my $expanded_slice =  $slice->expand( $padding_start, $padding_end ); 

  return $expanded_slice;

}

sub get_context_slice {
  my $self = shift;
  my $padding = shift || 25000;
  my $slice = $self->Obj->feature_Slice->expand( $padding, $padding );
  return 1 unless $slice;
  my $T = new EnsEMBL::Web::Proxy::Object( 'Slice', $slice, $self->__data );
  return $slice;
}

sub chromosome {
  my $self = shift;
  return undef if lc($self->coord_system) ne 'chromosome';
  return $self->Obj->slice->seq_region_name;
}

sub length {
  my $self = shift;
  my $length = ($self->seq_region_end - $self->seq_region_start) +1;
  return $length;
}

sub location_string {
  my $self = shift;
  return sprintf( "%s:%s-%s", $self->seq_region_name, $self->seq_region_start, $self->seq_region_end );
}

################ Calls for Feature in Detail view ###########################

sub get_nonfocus_block_features {
  my ($self, $slice) = @_;
  my @attributes = @{$self->Obj->get_nonfocus_attributes};
  my %nonfocus_data;

  foreach (@attributes) {
    my $unique_feature_set_id =  $_->feature_set->feature_type->name .':'.$_->feature_set->cell_type->name;
    next if $self->param('opt_ft_' .$unique_feature_set_id) eq 'off';
    my $histone_mod = substr($unique_feature_set_id, 0, 2);
    unless ($histone_mod =~/H\d/){ $histone_mod = 'Other';}
    $nonfocus_data{$histone_mod} = {} unless exists $nonfocus_data{$histone_mod};
    $nonfocus_data{$histone_mod}{$unique_feature_set_id} = $_->feature_set->get_Features_by_Slice($slice);
  }
  return \%nonfocus_data;
}

sub get_nonfocus_wiggle_features {
  return;
}

sub get_focus_set_block_features {
  my ($self, $slice) = @_;
  return unless $self->param('opt_focus') eq 'yes';
  
  my %data;
  my @annotated_features = @{$self->Obj->get_focus_attributes};
  foreach (@annotated_features ){ 
   my $unique_feature_set_id =  $_->feature_set->feature_type->name .':'.$_->feature_set->cell_type->name;
    $data{$unique_feature_set_id} = $_->feature_set->get_Features_by_Slice($slice); 
  } 
  return \%data;
}

sub get_focus_set_wiggle_features {
  return;
}
