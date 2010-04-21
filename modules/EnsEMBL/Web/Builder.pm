package EnsEMBL::Web::Builder;

### NAME: EnsEMBL::Web::Builder
### Contains the business logic for creating sets of domain objects 

### STATUS: Under development
### Currently being developed as a replacement for CoreObjects code

### DESCRIPTION 
### In order to make it easier to add new data types (and navigation tabs)
### to Ensembl pages, all of the logic involved in deciding which objects
### to create is being moved to this module. Thus adding a new data type
### will only require editing (or overriding) of this one module, instead
### of having to poke around in various factories! 

### Note that Builder is only used on page startup - additional domain objects
### can still be created on-the-fly by calling create_domain_object on the Model

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Root);

## EDIT THESE METHODS AS NEEDED

sub new {
  my ($class, $model) = @_;

  ## Edit these next two lines if you add more core objects 
  my %core_types  = (
    'Location'    => 'r',
    'Gene'        => 'g',
    'Transcript'  => 't',
    'Variation'   => 'v',
    'Regulation'  => 'rf',
    'Marker'      => 'm',
    'LRG'         => 'lrg',
  );
  
  my @core_order   = qw(r g t v rf m);
  my @extra_params = qw(h db pt vf fdb vdb domain family protein);

  $model->hub->set_core_types(keys %core_types);
  $model->hub->set_core_params(values %core_types, @extra_params);

  my $self = {
    '_model'        => $model,
    '_core_types'   => \%core_types,
    '_core_order'   => \@core_order,
    '_param_names'  => \@extra_params,
  };
  
  bless $self, $class;
  return $self;
}

## Put any object generation logic into these methods (and add more methods as needed)

sub _chain_Location {
  my $self = shift;
  
  ### Set coordinates in CGI parameters
  my $model    = $self->model;
  my $location = shift || $model->data('Location');
  
  if ($location && $location->seq_region_name && !$model->hub->param('r')) {
    my $r = $location->seq_region_name;
    $r   .= ':' . $location->start if $location->start;
    $r   .= '-' . $location->end   if $location->end;
    
    $model->hub->core_param('r', $r);
    
    return $self->_generic_create('Location', 'previous');
  }
}

sub _chain_Gene {
  my $self  = shift;
  my $model = $self->model;
  my $hub   = $model->hub;
  my $gene  = $model->api_object('Gene');
  my @problems;
  
  ## Do we need to create any other objects?
  if ($gene) {
    ## NEXT TAB
    if (!$model->data('Transcript')) {
      my @transcripts = @{$gene->get_all_Transcripts};
      
      if (scalar @transcripts == 1) {
        ## Add transcript if there's only one
        $hub->core_param('t', $transcripts[0]->stable_id);
        
        push @problems, $self->_generic_create('Transcript', 'next');
      }
    }
    
    push @problems, $self->_chain_Location($gene->feature_Slice) unless $model->data('Location'); ## PREVIOUS TAB
    
    $hub->core_param('g', $gene->stable_id);
  }

  return \@problems;
}

sub _chain_Transcript {
  my $self = shift;
  return $self->_generic_create('Gene', 'previous'); ## PREVIOUS TAB
}

sub _chain_Variation {
  my $self  = shift;
  my $model = $self->model;
  my $vf    = $model->hub->param('vf');
  
  ## Have come straight in on a Variation, so choose a location for it
  my $vari_features = $vf ? [ $model->data('Variation')->Obj->get_VariationFeature_by_dbID($vf) ] : $model->data('Variation')->get_variation_features;

  return unless @$vari_features;
  
  if (scalar @$vari_features == 1) {
    my $slice = $vari_features->[0]->feature_Slice;
    
    $model->hub->core_param('vf', $vari_features->[0]->dbID) unless $vf;
    
    return $self->_chain_Location($slice->expand(500, 500)) if $slice && !$model->data('Location'); ## PREVIOUS TAB
  } else {
    return $self->_generic_create('Location', 'previous'); ## PREVIOUS TAB - Genome tab
  }
}

sub _chain_Regulation {
  my $self  = shift;
  my $model = $self->model;
  my $slice = $model->data('Regulation')->Obj->feature_Slice;
  return $self->_chain_Location($slice) if $slice && !$model->data('Location'); ## PREVIOUS TAB
}

sub _chain_Marker {
  my $self    = shift;
  my $model   = $self->model;
  my $hub     = $model->hub;
  my $adaptor = $hub->database($hub->param('db') || 'core')->get_adaptor('Marker');
  my $markers = $adaptor->fetch_all_by_synonym($hub->param('m')); # FIXME: make a way to get the marker features straight from the object
  my @mfs     = map @{$_->get_all_MarkerFeatures}, @{$markers||[]};
  
  return unless @mfs;

# FIXME: Should be using this code, but marker views still require a location object to exist
#  if (scalar @mfs == 1) {
#    my $slice = $mfs[0]->feature_Slice;    
#    return $self->_chain_Location($slice) if $slice && !$model->data('Location'); ## PREVIOUS TAB
#  } else {
#    return $self->_generic_create('Location', 'previous'); ## PREVIOUS TAB - Genome tab
#  }
  
  my $slice = $mfs[0]->feature_Slice;
  return $self->_chain_Location($slice) if $slice && !$model->data('Location'); ## PREVIOUS TAB
}

sub _chain_LRG {
  my $self = shift;
  my $problems;
}

## -------- TABS --------------

sub _create_tab {
  my $self = shift;
  my $type = shift;
  my $object = $self->model->api_object($type);
  
  return if $type ne 'Location' && !$object;

  ## Set some default values that can be overridden as needed
  my $info = { 'type' => $type, 'action' => 'Summary' };

  if ($object && $object->isa('Bio::EnsEMBL::ArchiveStableId')) {
    $info->{'action'} = 'idhistory';
  }
  
  if ($type eq 'Gene' || $type eq 'Transcript' || $type eq 'Regulation') {
    $info->{'stable_id'} = $object->stable_id;
  } elsif ($type eq 'Variation') {
    $info->{'stable_id'} = $object->name; 
  }
  
  $info->{'long_caption'} = '';

  my $tab_method = "_tab_$type";
  
  if ($self->can($tab_method)) {
    return $self->$tab_method($object, $info);
  } else {
    warn "!!! CANNOT ADD TAB $type - NO METHOD DEFINED";
  }
}

sub _long_caption {
  my ($self, $object) = @_;
  my $dxr   = $object->can('display_xref') ? $object->display_xref : undef;
  my $label = $dxr ? ' (' . $dxr->display_id . ')' : '';
  return $object->stable_id . $label;
}

sub _tab_Location {
  my ($self, $slice, $info) = @_;

  my $coords;
  
  if (!$slice) {
    $info->{'action'}        = 'Genome';
    $info->{'short_caption'} = 'Genome';
  } else {
    $info->{'action'} = 'View';
    $coords = $slice->seq_region_name . ':' .$self->thousandify($slice->start) . '-' . $self->thousandify($slice->end);
    $info->{'short_caption'} = "Location: $coords";
  }
  
  $info->{'url'} = $self->model->hub->url({
    'type'   => 'Location',
    'action' => $info->{'action'},
    'r'      => $coords
  });

  return $info;
}

sub _tab_Gene {
  my ($self, $gene, $info) = @_;

  if ($gene->isa('EnsEMBL::Web::Fake')) {
    $info->{'short_caption'} = ucfirst $gene->type . ': ' . $gene->stable_id;
  } else {
    my $dxr   = $gene->can('display_xref') ? $gene->display_xref : undef;
    my $label = $dxr ? $dxr->display_id : $gene->stable_id;
    $info->{'short_caption'} =  "Gene: $label";
  }
  
  $info->{'long_caption'} = $self->_long_caption($gene);

  return $info;
}

sub _tab_Transcript {
  my ($self, $transcript, $info) = @_;

  if ($transcript->isa('EnsEMBL::Web::Fake')) {
    $info->{'short_caption'} = ucfirst $transcript->type . ': ' . $transcript->stable_id;
  } else {
    my $dxr   = $transcript->can('display_xref') ? $transcript->display_xref : undef;
    my $label = $dxr ? $dxr->display_id : $transcript->stable_id;
    $info->{'short_caption'} = length $label < 15 ? "Transcript: $label" : "Trans: $label";
  }
  
  $info->{'long_caption'} = $self->_long_caption($transcript);

  return $info;
}

sub _tab_Variation {
  my ($self, $variation, $info) = @_;
  my $label = $variation->name;
  $info->{'short_caption'} = (length $label > 30 ? 'Var: ' : 'Variation: ') . $label;
  return $info;
}

sub _tab_Regulation {
  my ($self, $regulation, $info) = @_;
  $info->{'short_caption'} = 'Regulation: ' . $regulation->stable_id;
  return $info;
}

sub _tab_Marker {
  my ($self, $marker, $info) = @_;
  $info->{'short_caption'} = 'Marker: ' . $self->model->hub->param('m');
  return $info;
}

sub _tab_LRG {
  my ($self, $slice, $info) = @_;

  my $hub    = $self->model->hub;
  my $coords = $slice->seq_region_name . ':' . $self->thousandify($slice->start) . '-' . $self->thousandify($slice->end);
  
  $info->{'action'}        = 'Summary';
  $info->{'short_caption'} = "Location: $coords";
  
  $info->{'url'} = $hub->url({
    'type'   => 'LRG',
    'action' => $info->{'action'},
    'lrg'    => $hub->param('lrg')
  });

  return $info;
}

## DO NOT EDIT BELOW THIS POINT (unless you do something very drastic to the constructor!)

### Getters for preset properties
sub model       { return $_[0]->{'_model'}; }
sub core_types  { return $_[0]->{'_core_types'}; }
sub core_order  { return $_[0]->{'_core_order'}; }
sub param_names { return $_[0]->{'_param_names'}; }

sub create_objects {
### Creates one or more domain objects, as required by the current page
### and adds them to the Model. Note that the Builder does not contain
### any direct object creation code - this is encapsulated in the Model.
  my ($self, $type, $request) = @_;
  
  ## Deal with funky zmenus!
  if ($request eq 'menu') {
    $self->model->create_domain_object($type);
    $self->model->create_domain_object($self->model->hub->action);
    return;
  }

  return if $self->model->data($type); ## No thanks, I've already got one!
  
  my @problems;
  my %core_types  = %{$self->core_types};
  my %core_params = reverse %core_types;
  my @core_order  = @{$self->core_order};
  my $hub         = $self->model->hub;
  
  foreach (map $core_params{$_}, grep $hub->param($_), @core_order) {
    my $problem = $self->_generic_create($_);
    
    if (ref $problem eq 'ARRAY') {
      push @problems, grep $_, @$problem;
    } elsif ($problem) {
      push @problems, $problem;
    }
  }
  
  return \@problems;
}

sub _generic_create {
  my $self      = shift;
  my $type      = shift;
  my $direction = shift;
  my $model     = $self->model;
  my $hub       = $model->hub;
  my $problems;
  
  ## Create this object unless it already exists
  if (!$model->data($type)) {
    $problems = $model->create_domain_object($type, @_);
    
    if ($problems && $hub->has_fatal_problem) {
      return $problems;
    } else {  
      my $tab_info = $self->_create_tab($type);
      $hub->add_tab($tab_info, $direction);
      
      ## Do we need to create any other objects?
      my $chain_method = "_chain_$type";
      
      if ($self->can($chain_method)) {
        $problems = $self->$chain_method;
      } else {
        warn "!!! CANNOT CREATE ADDITIONAL TAB(S) - NO METHOD $chain_method";
      }
    }
  }
  
  return $problems;
}

1;
