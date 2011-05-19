# $Id$

package EnsEMBL::Web::ViewConfig::LRG::LRGSNPTable;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self       = shift;
  my $variations = $self->species_defs->databases->{'DATABASE_VARIATION'};
  my %options    = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my $defaults   = {
    consequence_format => 'ensembl',
    context            => 'FULL'
  };
  
  $defaults->{"opt_pop_$_"} = 'off' for @{$variations->{'DISPLAY_STRAINS'}}, $variations->{'REFERENCE_STRAIN'};
  $defaults->{"opt_pop_$_"} = 'on'  for @{$variations->{'DEFAULT_STRAINS'}};

  # Add source information if we have a variation database
  if ($variations) {
    foreach (keys %{$variations->{'tables'}{'source'}{'counts'} || {}}){
      my $name = 'opt_' . lc $_;
      $name    =~ s/\s+/_/g;
      $defaults->{$name} = 'on';
    }
  }
  
  foreach (keys %options) {
    my %hash = %{$options{$_}};
    $defaults->{lc $_} = $hash{$_}[0] for keys %hash;
  }
  
  $self->set_defaults($defaults);
}

sub form {
  my $self       = shift;
  my %options    = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my %validation = %{$options{'variation'}};
  my %class      = %{$options{'class'}};
  my %type       = %{$options{'type'}};

  # Add context selection
	$self->add_fieldset('Context');
	$self->add_form_element({
	  type   => 'DropDown',
    select => 'select',
    name   => 'context',
	  label  => 'Context',
	  values => [
	    { value => '20',   name => '20bp'         },
	    { value => '50',   name => '50bp'         },
	    { value => '100',  name => '100bp'        },
	    { value => '200',  name => '200bp'        },
	    { value => '500',  name => '500bp'        },
	    { value => '1000', name => '1000bp'       },
	    { value => '2000', name => '2000bp'       },
	    { value => '5000', name => '5000bp'       },
	    { value => 'FULL', name => 'Full Introns' }
	  ]
  });
  
  # Add source selection
  $self->add_fieldset('Variation source');
  
  foreach (sort keys %{$self->hub->table_info('variation', 'source')->{'counts'}}) {
    my $name = 'opt_' . lc($_);
    $name =~ s/\s+/_/g;
    
    $self->add_form_element({
      type  => 'CheckBox', 
      label => $_,
      name  => $name,
      value => 'on',
      raw   => 1
    });
  }
  
  # Add class selection
  $self->add_fieldset('Variation class');
  
  foreach (keys %class) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => $class{$_}[1],
      name  => lc $_,
      value => 'on',
      raw   => 1
    });
  }
  
  # Add Validation selection
  $self->add_fieldset('Validation');
  
  foreach (keys %validation) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => $validation{$_}[1],
      name  =>  lc $_,
      value => 'on',
      raw   => 1
    });
  }
  
  # Add type selection
  $self->add_fieldset('Consequence type');
  
  $self->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Type of consequences to display',
    name   => 'consequence_format',
    values => [
      { value => 'ensembl', name => 'Ensembl terms'           },
      { value => 'so',      name => 'Sequence Ontology terms' },
      { value => 'ncbi',    name => 'NCBI terms'              },
    ]
  });
  
  foreach (sort { $type{$a}->[2] <=> $type{$b}->[2] } keys %type) { 
    next if $_ eq 'opt_sara';
    
    $self->add_form_element({
      type  => 'CheckBox',
      label => $type{$_}[1],
      name  => lc($_),
      value => 'on',
      raw   => 1
    });
  }
}

1;
