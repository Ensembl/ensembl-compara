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

sub can_export        { return 0; }
sub hub               { return $_[0]{'data'}{'_hub'}; }          # Gets the underlying Ensembl object wrapped by the web object
sub Obj               { return $_[0]{'data'}{'_object'}; }       # Gets the underlying Ensembl object wrapped by the web object
sub highlights_string { return join '|', @{$_[0]->highlights}; } # Returns the highlights area as a | separated list for passing in URLs.
sub problem           { return shift->hub->problem(@_); }

sub coords { return {} }

sub convert_to_drawing_parameters {
### Stub - individual object types probably need to implement this separately
  my $self = shift;
  my $hash = {};
  return $hash;
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
