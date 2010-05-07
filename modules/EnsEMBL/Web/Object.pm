package EnsEMBL::Web::Object;

### NAME: EnsEMBL::Web::Object
### Base class - wrapper around a Bio::EnsEMBL API object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Contains a lot of functionality not directly related to
### manipulation of the underlying API object 

### DESCRIPTION
### All Ensembl web data objects are derived from this class,
### which is derived from Proxiable - as it is usually proxied 
### through an {{EnsEMBL::Web::Proxy}} object to handle the dynamic 
### multiple inheritance functionality.

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc qw(get_url_content);

use base qw(EnsEMBL::Web::Proxiable);

sub counts            { return {}; }
sub _counts           { return {}; }                             # Implemented in plugins
sub availability      { return {}; }
sub can_export        { return 0; }
sub hub               { return $_[0]{'data'}{'_hub'}; }          # Gets the underlying Ensembl object wrapped by the web object
sub Obj               { return $_[0]{'data'}{'_object'}; }       # Gets the underlying Ensembl object wrapped by the web object
sub highlights_string { return join '|', @{$_[0]->highlights}; } # Returns the highlights area as a | separated list for passing in URLs.
sub problem           { return shift->hub->problem(@_); }

sub count_alignments {
  my $self = shift;
  my $cdb = shift || 'DATABASE_COMPARA';

  my $species = $self->species;
  my %alignments = $self->species_defs->multi($cdb, 'ALIGNMENTS');
  my $c = { all => 0, pairwise => 0 };
  
  foreach (grep $_->{'species'}{$species}, values %alignments) {
    $c->{'all'}++ ;
    $c->{'pairwise'}++ if $_->{'class'} =~ /pairwise_alignment/;
  }
  
  $c->{'multi'} = $c->{'all'} - $c->{'pairwise'};
  
  return $c; 
}

sub _availability { 
  my $self = shift;
  
  my $hash = { map { ('database:'. lc(substr $_, 9) => 1) } keys %{$self->species_defs->databases} };
  map { my $key =lc(substr($_,9)); $hash->{"database:$key"} = 1} @{$self->species_defs->compara_like_databases || [] };
  $hash->{'logged_in'} = 1 if $self->user;
  
  return $hash;
}

sub core_params {
  my $self = shift;
  
  my $location     = $self->core_objects->location;
  my $gene         = $self->core_objects->gene;
  my $transcript   = $self->core_objects->transcript;
  my $params       = [];
  
  push @$params, sprintf 'r=%s:%s-%s', $location->seq_region_name, $location->start, $location->end if $location;
  push @$params, 'g=' . $gene->stable_id if $gene;
  push @$params, 't=' . $transcript->stable_id if $transcript;
  
  return $params;
}

sub prefix {
  my ($self, $value) = @_;
  $self->{'prefix'} = $value if $value;
  return $self->{'prefix'};
}

# Gets the database name used to create the object
sub get_db {
  my $self = shift;
  my $db = $self->param('db') || 'core';
  return $db eq 'est' ? 'otherfeatures' : $db;
}

# Data interface attached to object
sub interface {
  my $self = shift;
  $self->{'interface'} = shift if @_;
  return $self->{'interface'};
}

# Command object attached to proxy object
sub command {
  my $self = shift;
  $self->{'command'} = shift if (@_);
  return $self->{'command'};
}

sub get_adaptor {
  my ($self, $method, $db, $species) = @_;
  
  $db      = 'core' if !$db;
  $species = $self->species if !$species;
  
  my $adaptor;
  eval { $adaptor = $self->database($db, $species)->$method(); };

  if ($@) {
    warn $@;
    $self->problem('fatal', "Sorry, can't retrieve required information.", $@);
  }
  
  return $adaptor;
}

# The highlights array is passed between web-requests to highlight selected items (e.g. Gene around
# which contigview had been rendered. If any data is passed this is stored in the highlights array
# and an arrayref of (unique) elements is returned.
sub highlights {
  my $self = shift;
  
  if (!exists( $self->{'data'}{'_highlights'})) {
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc $_) => 1 } grep $_, map { split /\|/, $_ } $self->param('h'), $self->param('highlights');
    
    $self->{'data'}{'_highlights'} = [ grep $_, keys %highlights ];
  }
  
  if (@_) {
    my %highlights = map { ($_ =~ /^(URL|BLAST_NEW):/ ? $_ : lc $_) => 1 } @{$self->{'data'}{'_highlights'}||[]}, map { split /\|/, $_ } @_;
    
    $self->{'data'}{'_highlights'} = [ grep $_, keys %highlights ];
  }
  
  return $self->{'data'}{'_highlights'};
}

# Returns the type of seq_region in "human readable form" (in this case just first letter captialised)
sub seq_region_type_human_readable {
  my $self = shift;
  
  if (!$self->can('seq_region_type')) {
    $self->{'data'}->{'_drop_through_'} = 1;
    return;
  }
  
  return ucfirst $self->seq_region_type;
}

# Returns the type/name of seq_region in human readable form - if the coord system type is part of the name this is dropped.
sub seq_region_type_and_name {
  my $self = shift;
  
  if (!$self->can('seq_region_name')) {
    $self->{'data'}->{'_drop_through_'} = 1;
    return;
  }
  
  my $coord = $self->seq_region_type_human_readable;
  my $name  = $self->seq_region_name;
  
  if ($name =~ /^$coord/i) {
    return $name;
  } else {
    return "$coord $name";
  }
}

sub gene_description {
  my $self = shift;
  my $gene = shift || $self->gene;
  my %description_by_type = ('bacterial_contaminant' => 'Probable bacterial contaminant');
  
  if ($gene) {
    return $gene->description || $description_by_type{$gene->biotype} || 'No description';
  } else {
    return 'No description';
  }
}

sub fetch_userdata_by_id {
  my ($self, $record_id) = @_;
  
  return unless $record_id;
  
  my $user = $self->user;
  my $data = {};

  my ($status, $type, $id) = split '-', $record_id;

  if ($type eq 'url' || ($type eq 'upload' && $status eq 'temp')) {
    my ($content, $format);

    my $tempdata = {};
    if ($status eq 'temp') {
      $tempdata = $self->get_session->get_data('type' => $type, 'code' => $id);
    } else {
      my $record = $user->urls($id);
      $tempdata = { 'url' => $record->url };
    }
    
    my $parser = new EnsEMBL::Web::Text::FeatureParser($self->species_defs);
    
    if ($type eq 'url') {
      my $response = get_url_content($tempdata->{'url'});
      $content = $response->{'content'};
    } else {
      my $file = new EnsEMBL::Web::TmpFile::Text(filename => $tempdata->{'filename'});
      $content = $file->retrieve;
      return {} unless $content;
    }
    
    $parser->parse($content, $tempdata->{'format'});
    $data = { 'parser' => $parser };
  } else {
    my $fa = $self->database('userdata', $self->species)->get_DnaAlignFeatureAdaptor;
    my @records = $user->uploads($id);
    my $record = $records[0];
    
    if ($record) {
      my @analyses = ($record->analyses);
      
      foreach (@analyses) {
        next unless $_;
        $data->{$_} = {'features' => $fa->fetch_all_by_logic_name($_), 'config' => {}};
      }
    }
  }
  
  return $data;
}

# There may be occassions when a script needs to work with features of
# more than one type. in this case we create a new {{EnsEMBL::Web::Proxy::Factory}}
# object for the alternative data type and retrieves the data (based on the standard URL
# parameters for the new factory) attach it to the universal datahash {{__data}}
sub alternative_object_from_factory {
  my ($self, $type) = @_;
  
  my $t_fact = $self->new_factory($type, $self->__data);
  
  if ($t_fact->can('createObjects')) {
    $t_fact->createObjects;
    $self->__data->{lc $type}  = $t_fact->DataObjects;
    $self->__data->{'objects'} = $t_fact->__data->{'objects'};
  }
}

# Store default viewconfig so we don't have to keep getting it from session
sub viewconfig {
  my $self = shift;
  $self->__data->{'_viewconfig'} ||= $self->get_viewconfig;
  return $self->__data->{'_viewconfig'};
}

sub get_viewconfig {
  return shift->hub->get_viewconfig(@_);
}

1;

