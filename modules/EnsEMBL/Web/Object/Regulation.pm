#$Id$
package EnsEMBL::Web::Object::Regulation;

### NAME: EnsEMBL::Web::Object::Regulation
### Wrapper around a Bio::EnsEMBL::Funcgen::RegulatoryFeature object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION


use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Object);
use Bio::EnsEMBL::Utils::Exception qw( throw );

sub short_caption {
  my $self = shift;
  
  return "Regulation-based displays" unless shift eq 'global';
  return 'Regulation: ' . $self->Obj->stable_id;
}

sub caption {
  my $self = shift;
  my $caption = 'Regulatory Feature: '. $self->Obj->stable_id;
  return $caption;    
}

sub default_action {
  my $self         = shift;
  my $availability = $self->availability;
  return $availability->{'regulation'} ? 'Cell_line' : 'Summary';
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

sub fetch_all_objs {
  my $self = shift;
  my $db = $self->get_fg_db;
  my $reg_feature_adaptor = $db->get_RegulatoryFeatureAdaptor;
  my $reg_objs = $reg_feature_adaptor->fetch_all_by_stable_ID($self->stable_id);
  return $reg_objs;
}

sub fetch_all_objs_by_slice {
  my ($self, $slice) = @_;
  my $db = $self->get_fg_db;
  my $reg_feature_adaptor  = $db->get_RegulatoryFeatureAdaptor;
  my $objects_on_slice = $reg_feature_adaptor->fetch_all_by_Slice($slice);
  my @all_objects;
  foreach my $rf (@$objects_on_slice){
    my $all_cell_type_objs = $reg_feature_adaptor->fetch_all_by_stable_ID($rf->stable_id);
    foreach (@$all_cell_type_objs) {
      push @all_objects, $_;
    }
  }  

  return \@all_objects;
}

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
  my $spp = $self->species;
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
    'action' => 'View',
    'rf'    => $self->stable_id,
    'fdb'   => 'funcgen',
    'r'     => $self->location_string,
  });
  return $url;
}

sub get_bound_location_url {
  my $self= shift;
  my $url = $self->_url({
    'type'  => 'Location',
    'action'  => 'View',
    'rf'    => $self->stable_id,
    'fdb'   => 'funcgen',
    'r'     => $self->bound_location_string,
  });
  return $url;
}

sub get_regulation_slice {
  my $self = shift;
  my $slice = $self->Obj->feature_Slice;
  return 1 unless $slice;
  my $T = $self->new_object( 'Slice', $slice, $self->__data );
  return $T;  
}

sub get_seq {
  my ($self, $strand) = @_;
  $self->Obj->{'strand'} = $strand;
  return $self->Obj->seq; 
}

sub get_details_page_url {
  my $self = shift; 
  my $url = $self->_url({
    'type'   => 'Regulation',
    'action' => 'Cell_line',
    'rf'     => $self->stable_id,
    'fdb'    => 'funcgen',
  });
  return $url;
}

sub get_bound_context_slice {
  my $self = shift;
  my $padding = shift || 1000; 
  my $slice = $self->Obj->feature_Slice;
  my $offset_start = $self->bound_start -$padding;
  my $offset_end = $self->bound_end + $padding;
  
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
  my $T = $self->new_object( 'Slice', $slice, $self->__data );
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
  my $offset = shift || 0;
  my $start =  $self->seq_region_start + $offset;
  my $end =  $self->seq_region_end  + $offset;

  return sprintf( "%s:%s-%s", $self->seq_region_name, $start, $end );
}

sub bound_location_string {
  my $self = shift;
  my $start =  $self->bound_start;
  my $end =  $self->bound_end;

  return sprintf( "%s:%s-%s", $self->seq_region_name, $start, $end );
}

################ Calls for Feature in Detail Cell line view ###########################
sub get_configured_tracks {
  my $self = shift;
  my %available_feature_sets;  

  my %cell_lines        =  %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  my %evidence_features = %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'feature_type'}{'ids'}};
  my %focus_set_ids     = %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'meta'}{'focus_feature_set_ids'}};
  my %feature_type_ids  = %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'meta'}{'feature_type_ids'}};

  $cell_lines{'MultiCell'} =1;
  
  foreach my $cell_line (keys %cell_lines){
    $cell_line =~s/\:\d*//; 
    my $cell = $cell_line;
    if ($cell_line eq 'MultiCell'){ $cell = 'core';}
    $available_feature_sets{$cell_line} = {};
    foreach my $evidence_feature (keys %evidence_features){
      my ($feature_name, $feature_id ) = split (/\:/, $evidence_feature); 
      if (exists $feature_type_ids{$cell}{$feature_id}) {
        unless (exists $available_feature_sets{$cell_line}{'available'}){ 
           $available_feature_sets{$cell_line}{'available'}{'focus'} = []; 
           $available_feature_sets{$cell_line}{'available'}{'non_focus'} = [];
           $available_feature_sets{$cell_line}{'configured'}{'focus'} = [];
           $available_feature_sets{$cell_line}{'configured'}{'non_focus'} = [];  
        }
        my $focus_flag = 'non_focus';
        if ($cell eq 'core' || exists $focus_set_ids{$cell}{$feature_id}){
          $focus_flag = 'focus';
        }                                                            
        push @{$available_feature_sets{$cell_line}{'available'}{$focus_flag}}, $feature_name;  
        # add to configured features if turned on
        if ( $self->param('opt_cft_'.$cell_line.':'.$feature_name) eq 'on') {
          push @{$available_feature_sets{$cell_line}{'configured'}{$focus_flag}}, $feature_name;
        }

      }
    }
  }
  return \%available_feature_sets;
}

sub get_multicell_evidence_data {
  my ($self, $slice, $param_all_on ) = @_;
  my $fset_a = $self->database('funcgen')->get_FeatureSetAdaptor;
  my $dset_a = $self->database('funcgen')->get_DataSetAdaptor;
  my %data;

  foreach my $regf_fset(@{$fset_a->fetch_all_by_type('regulatory')}){
    next unless $regf_fset->cell_type->name =~/MultiCell/i;

    my $regf_data_set = $dset_a->fetch_by_product_FeatureSet($regf_fset);
    foreach my $reg_attr_fset(@{$regf_data_set->get_supporting_sets}){
      my $reg_attr_dset = $dset_a->fetch_by_product_FeatureSet($reg_attr_fset);
      my @sset = @{$reg_attr_dset->get_displayable_supporting_sets('result')};
      if(scalar(@sset) >> 1){#There should only be one
        throw ("There should only be one DISPLAYABLE supporting ResultSet to display a wiggle track for DataSet:\t".$reg_attr_dset->name);  }

      my $reg_attr_rset = $sset[0];


      my $focus_flag = 'non_focus';
      if  ($reg_attr_fset->is_focus_set){
        $focus_flag = 'focus';
      }
      my @block_features = @{$reg_attr_fset->get_Features_by_Slice($slice)};
      my $unique_feature_set_id =  'MultiCell' .':'.$reg_attr_fset->feature_type->name;
      my $name = 'opt_cft_' .$unique_feature_set_id;
      $unique_feature_set_id .= ':'. $reg_attr_fset->cell_type->name;
      if ( ( $self->param($name) eq 'on')  || $param_all_on ){
        if (@block_features){
          $data{'MultiCell'}{$focus_flag}{'block_features'}{$unique_feature_set_id} = \@block_features;
          $reg_attr_fset->get_Features_by_Slice($slice);
         }
## Disable for release 58
#        $data{'MultiCell'}{$focus_flag}{'wiggle_features'}{$unique_feature_set_id} = $reg_attr_rset;
      } 
    }
  }
  return \%data;
}

sub get_evidence_data {
  my ($self, $slice, $param_all_on) = @_;
 
  my $fset_a = $self->database('funcgen')->get_FeatureSetAdaptor;
  my $dset_a = $self->database('funcgen')->get_DataSetAdaptor;

  my %data;

  foreach my $regf_fset(@{$fset_a->fetch_all_by_type('regulatory')}){
    my $regf_data_set = $dset_a->fetch_by_product_FeatureSet($regf_fset);
    foreach my $reg_attr_fset(@{$regf_data_set->get_supporting_sets}){
      my $reg_attr_dset = $dset_a->fetch_by_product_FeatureSet($reg_attr_fset);
      my @sset = @{$reg_attr_dset->get_displayable_supporting_sets('result')};

      if(scalar(@sset) >> 1){#There should only be one
        throw ("There should only be one DISPLAYABLE supporting ResultSet to display a wiggle track for DataSet:\t".$reg_attr_dset->name);    }

      my $reg_attr_rset = $sset[0];

      # save_data
      my $cell_type = $reg_attr_fset->cell_type->name;

      unless (exists $data{$cell_type}){
        $data{$cell_type} = {};
      }

      my $focus_flag = 'non_focus';    
      if  ($reg_attr_fset->is_focus_set){
        $focus_flag = 'focus'; 
      }
      my @block_features = @{$reg_attr_fset->get_Features_by_Slice($slice)};
      my $unique_feature_set_id =  $reg_attr_fset->cell_type->name .':'.$reg_attr_fset->feature_type->name; 
      my $name = 'opt_cft_' .$unique_feature_set_id;

      if ( ($self->param($name) eq 'on')  || $param_all_on){
        if (@block_features){
          $data{$cell_type}{$focus_flag}{'block_features'}{$unique_feature_set_id} = \@block_features
        } unless (scalar @sset  == 0){ 
          $data{$cell_type}{$focus_flag}{'wiggle_features'}{$unique_feature_set_id} = $reg_attr_rset; 
        }
      }
    }
  }

return \%data;
}

sub get_all_cell_line_features {
  my ($self) = @_;
  my %all_cell_feature_combinations;

  my %cell_lines =  %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  my %evidence_features = %{$self->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'feature_type'}{'ids'}};

  foreach my $cell_type (keys %cell_lines){
    $cell_type =~s/\:\d+//;
    foreach my $feature_type (keys %evidence_features){
      $feature_type =~s/\:\d+//;
      my $key = $feature_type .':'. $cell_type;
      $all_cell_feature_combinations{$key} = 1;
    }
  }
  
  return  \%all_cell_feature_combinations;
}

################ Calls for Feature in Detail view ###########################

sub get_focus_set_block_features {
  my ($self, $slice) = @_;
  return unless $self->param('opt_focus') eq 'yes';
  
  my %data;
  my @annotated_features = @{$self->Obj->get_focus_attributes};
  foreach (@annotated_features ){ 
   my $unique_feature_set_id =  $_->feature_set->cell_type->name .':'.$_->feature_set->feature_type->name;
    $data{$unique_feature_set_id} = $_->feature_set->get_Features_by_Slice($slice); 
  } 
  return \%data;
}

1;
