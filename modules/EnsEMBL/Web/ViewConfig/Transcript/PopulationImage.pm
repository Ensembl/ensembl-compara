# $Id$

package EnsEMBL::Web::ViewConfig::Transcript::PopulationImage;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self       = shift;
  my $variations = $self->species_defs->databases->{'DATABASE_VARIATION'} || {};
  my %options    = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my $defaults   = {
    context            => 100,
    consequence_format => 'label'
  };

  $defaults->{"opt_pop_$_"} = 'off' for @{$variations->{'DISPLAY_STRAINS'}};
  $defaults->{"opt_pop_$_"} = 'on'  for @{$variations->{'DEFAULT_STRAINS'}};

  # Add source information if we have a variation database
  foreach (keys %{$variations->{'tables'}{'source'}{'counts'} || {}}){
    my $name = 'opt_' . lc($_);
    $name    =~ s/\s+/_/g;
    $defaults->{$name} = 'on';
  }

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    
    foreach my $key (keys %hash){
      $defaults->{lc $key} = $hash{$key}[0];
    }
  }
  
  $self->set_defaults($defaults);
  $self->code  = 'Transcript::SNPView';
  $self->title = 'Population comparison';
}

sub form {
  my $self       = shift;
  my $variations = $self->species_defs->databases->{'DATABASE_VARIATION'};
  my %options    = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my %validation = %{$options{'variation'}};
  my %class      = %{$options{'class'}};
  my %type       = %{$options{'type'}};

  # Add Individual selection
  $self->add_fieldset('Selected individuals');

  my @strains = (@{$variations->{'DEFAULT_STRAINS'}}, @{$variations->{'DISPLAY_STRAINS'}});
  my %seen;

  foreach (sort @strains) {
    if (!exists $seen{$_}) {
      $self->add_form_element({
        type  => 'CheckBox',
        label => $_,
        name  => "opt_pop_$_",
        value => 'on',
        raw   => 1
      });

      $seen{$_} = 1;
    }
  }

  # Add source selection
  $self->add_fieldset('Variation source');
  
  foreach (sort keys %{$self->hub->table_info('variation', 'source')->{'counts'}}) {
    my $name = 'opt_' . lc $_;
    $name    =~ s/\s+/_/g;
    
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
  
  # Add type selection
  $self->add_fieldset('Consequence type');
  
  foreach (keys %type) {
    $self->add_form_element({
      type  => 'CheckBox',
      label => $type{$_}[1],
      name  => lc $_,
      value => 'on',
      raw   => 1
    });
  }

  # Add selection
  $self->add_fieldset('Consequence options');
  
  $self->add_form_element({
    type   => 'DropDown',
    select =>, 'select',
    label  => 'Type of consequences to display',
    name   => 'consequence_format',
    values => [
      { value => 'label',   name => 'Sequence Ontology terms' },
      { value => 'display', name => 'Old Ensembl terms'       },
    ]
  });  
  
  # Add context selection
  $self->add_fieldset('Intron Context');

  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Intron Context',
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
}

1;
