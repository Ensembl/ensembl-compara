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
  my @extra_params = qw/h db pt vf fdb vdb domain family protein/;

  $model->hub->set_core_types(keys %core_types);
  $model->hub->set_core_params(values %core_types, @extra_params);

  my $self = {
    '_model'        => $model,
    '_core_types'   => \%core_types,
    '_param_names'  => \@extra_params,
  };
  
  bless $self, $class;
  return $self;
}

## Put any object generation logic into these methods (and add more methods as needed)

sub _chain_Location {
  my $self = shift;
  my $problems;

  ## Do we need to create any other objects?
  ## NEXT TAB
  if (!$self->model->data('Gene') && $self->model->hub->param('g')) {
    $self->_generic_create('Gene', 'next');
  }

  ### Set coordinates in CGI parameters
  my $location = $self->model->data('Location');
  if ($location && $location->seq_region_name) {
    my $r = $location->seq_region_name;
    $r .= ':'.$location->seq_region_start if $location->seq_region_start;
    $r .= '-'.$location->seq_region_end   if $location->seq_region_end;
    $self->model->hub->param('r', $r);
  }

  return $problems;
}

sub _chain_Gene {
  my $self = shift;
  my $problems;

  ## Do we need to create any other objects?
  ## NEXT TAB
  if (!$self->model->data('Transcript')) {
    my $gene = $self->model->api_object('Gene');
    if ($gene) {
      my @transcripts = @{$gene->get_all_Transcripts};
      if (scalar @transcripts == 1) {
        ## Add transcript if there's only one
        my $trans_id = $transcripts[0]->stable_id;
        $self->model->hub->param('t', $trans_id);
      }
    }
    if ($self->model->hub->param('t')) {
      $self->_generic_create('Transcript', 'next');
    }
  }
  elsif (!$self->model->data('Variation') && $self->model->hub->param('v')) {
    $self->_generic_create('Variation', 'next');
  }
  ## PREVIOUS TAB
  unless ($self->model->data('Location')) {
    $problems = $self->_previous_tab_Location;
  }  

  return $problems;
}

sub _chain_Transcript {
  my $self = shift;
  my $problems;

  ## Do we need to create any other objects?
  ## NEXT TAB
  if ($self->model->hub->param('v')) {
    $self->_generic_create('Variation', 'next');
  }
  ## PREVIOUS TAB
  $self->_generic_create('Gene', 'previous');

  return $problems;
}

sub _chain_Variation {
  my $self = shift;
  my $problems;

  ## Do we need to create any other objects?
  ## PREVIOUS TAB
  if ($self->model->hub->param('t')) {
    $self->_generic_create('Transcript', 'previous');
  }
  elsif ($self->model->hub->param('g')) {
    $self->_generic_create('Gene', 'previous');
  }
  else {
    ## Have come straight in on a Variation, so choose a location for it
    my $var_obj = $self->model->data('Variation');
    my $db_adaptor  = $self->model->hub->database('variation');

    my $vari_features = $db_adaptor->get_VariationFeatureAdaptor->fetch_all_by_Variation($var_obj->Obj);

    return unless @$vari_features;

    my $feature = $vari_features->[0];
    my $slice = $feature->slice;
    if ($slice) {
      my $region = $slice->seq_region_name;
      if ($region) {
        my $s = $feature->start;
        my $coords = {'seq_region' => $region, 'start' => $s - 500, 'end' => $s + 500};
        $self->_generic_create('Location', 'previous', $coords);
      }
    }
  }

  return $problems;
}

sub _chain_Regulation {
  my $self = shift;
  my $problems;

  ## Do we need to create any other objects?
  ## PREVIOUS TAB
  if ($self->model->hub->param('t')) {
    $self->_generic_create('Transcript', 'previous');
  }
  elsif ($self->model->hub->param('g')) {
    $self->_generic_create('Gene', 'previous');
  }
  else {
    my $coords = {};
    my $data = $self->model->data;
    ## Create a location based on object coordinates
    if ($data) {
      $coords = {
        'seq_region' => $data->seq_region_name,
        'start'      => $data->seq_region_start,
        'end'        => $data->seq_region_end,
      };
    }
    $self->_generic_create('Location', 'previous', $coords);
  }

  return $problems;
}

sub _chain_Marker {
  my $self = shift;
  my $problems;
  unless ($self->model->data('Location')) {
    $problems = $self->_previous_tab_Location;
    return $problems;
  }  
}

sub _chain_LRG {
  my $self = shift;
  my $problems;
}

sub _previous_tab_Location {
  my $self = shift;
  my $problems;

  my $coords;
  if ($self->model->hub->type ne 'Location') {
    my $data = $self->model->data;
    ## Create a location based on object coordinates
    if ($data) {
      $coords = {
        'seq_region' => $data->seq_region_name,
        'start'      => $data->seq_region_start,
        'end'        => $data->seq_region_end,
      };
    }
  }
 
  if ($coords) {
    ## Feed these back into CGI params, for use in links
    my $r = $coords->{'seq_region'}.':'.$coords->{'start'}.'-'.$coords->{'end'};
    $self->model->hub->param('r', $r);
  }
  $self->_generic_create('Location', 'previous', $coords);

  return $problems;
}

## -------- TABS --------------

sub _create_tab {
  my $self = shift;
  my $type = shift;
  my $object = $self->model->api_object($type);
  return if $type ne 'Location' && !$object;

  ## Set some default values that can be overridden as needed
  my $info = {'type' => $type, 'action' => 'Summary'};

  if ($object && $object->isa('Bio::EnsEMBL::ArchiveStableId')) {
    $info->{'action'} = 'idhistory';
  }
  if ($type eq 'Gene' || $type eq 'Transcript' || $type eq 'Regulation') {
    $info->{'stable_id'} = $object->stable_id;
  }
  elsif ($type eq 'Variation') {
    $info->{'stable_id'} = $object->name; 
  }
  $info->{'long_caption'} = '';

  my $tab_method = "_tab_$type";
  if ($self->can($tab_method)) {
    return $self->$tab_method($object, $info);
  }
  else {
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
    $info->{'action'} = 'Genome';
    $info->{'short_caption'}  = 'Genome';
  }
  else {
    $info->{'action'} = 'View';
    $coords = $slice->seq_region_name.':'
                  .$self->thousandify($slice->start).'-'.$self->thousandify($slice->end);
    $info->{'short_caption'} = "Location: $coords";
  }
  $info->{'parameters'} = ['r'];
  $info->{'url'} = $self->model->hub->url({
    'type'   => 'Location',
    'action' => $info->{'action'},
    'r'      => $coords,
  });

  return $info;
}

sub _tab_Gene {
  my ($self, $gene, $info) = @_;

  if ($gene->isa('EnsEMBL::Web::Fake')) {
    $info->{'short_caption'} = ucfirst($gene->type) . ': ' . $gene->stable_id;
  }
  else {
    my $dxr   = $gene->can('display_xref') ? $gene->display_xref : undef;
    my $label = $dxr ? $dxr->display_id : $gene->stable_id;
    $info->{'short_caption'} =  "Gene: $label";
  }
  $info->{'long_caption'} = $self->_long_caption($gene);
  $info->{'parameters'} = ['r', 'g'];

  return $info;
}

sub _tab_Transcript {
  my ($self, $transcript, $info) = @_;

  if ($transcript->isa('EnsEMBL::Web::Fake')) {
    $info->{'short_caption'} = ucfirst($transcript->type) . ': ' . $transcript->stable_id;
  }
  else {
    my $dxr   = $transcript->can('display_xref') ? $transcript->display_xref : undef;
    my $label = $dxr ? $dxr->display_id : $transcript->stable_id;
    $info->{'short_caption'} = length $label < 15 ? "Transcript: $label" : "Trans: $label";
  }
  $info->{'long_caption'} = $self->_long_caption($transcript);
  $info->{'parameters'} = ['r', 'g', 't'];

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

  $info->{'short_caption'}  = 'Regulation: '.$regulation->stable_id;

  return $info;
}

sub _tab_Marker {
  my ($self, $marker, $info) = @_;
  $info->{'short_caption'}  = 'Marker: '.$self->model->hub->param('m');
  return $info;
}

sub _tab_LRG {
  my ($self, $slice, $info) = @_;

  $info->{'action'} = 'Summary';
  my $coords = $slice->seq_region_name.':'
                  .$self->thousandify($slice->start).'-'.$self->thousandify($slice->end);
  $info->{'short_caption'} = "Location: $coords";
  $info->{'url'} = $self->model->hub->url({
    'type'   => 'LRG',
    'action' => $info->{'action'},
    'lrg'      => $self->model->hub->param('lrg'),
  });

  return $info;
}

## DO NOT EDIT BELOW THIS POINT (unless you do something very drastic to the constructor!)

### Getters for preset properties
sub model       { return $_[0]->{'_model'}; }
sub core_types  { return $_[0]->{'_core_types'}; }
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
  my $problems;
  my %core_types = %{$self->core_types};

  if (grep /^$type$/, keys %core_types) {
    ## start with the current object, which will create others as necessary
    $problems = $self->_generic_create($type);

    ## Add any non-tab core objects (e.g. variation on Location/LD page)
    while (my($type, $param) = each (%core_types)) {
      if ($self->model->hub->param($param) && !$self->model->data($type)) {
        $problems = $self->model->create_domain_object($type);
        my $tab_info = $self->_create_tab($type);
        $self->model->add_tab($tab_info);
      }
    }
  }
  else {
    ## Not core, so just generate a single object
    $problems = $self->model->create_domain_object($type);
  } 
  return $problems;
}

sub _generic_create {
  my $self      = shift;
  my $type      = shift;
  my $direction = shift;
  my $problem;

  ## Create this object unless it already exists
  unless ($self->model->data($type)) {
    $problem = $self->model->create_domain_object($type, @_);
    if ($problem && $self->model->hub->has_fatal_problem) {
      return $problem;
    }
    else {  
      my $tab_info = $self->_create_tab($type);
      $self->model->add_tab($tab_info, $direction);
      ## Do we need to create any other objects?
      my $chain_method = "_chain_$type";
      if ($self->can($chain_method)) {
        $problem = $self->$chain_method;
      }
      else {
        warn "!!! CANNOT CREATE ADDITIONAL TAB(S) - NO METHOD $chain_method";
      }
    }
  }
  return $problem;
}

1;
