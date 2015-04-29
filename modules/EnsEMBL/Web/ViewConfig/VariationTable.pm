=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::ViewConfig::VariationTable;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self       = shift;
  my $variations = $self->species_defs->databases->{'DATABASE_VARIATION'} || {};
  my %options    = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my $defaults   = {
    context            => 'FULL', 
    hgvs               => 'off',
  }; # Don't change context if you want the page to come back!!
  
  $defaults->{"opt_pop_$_"} = 'off' for @{$variations->{'DISPLAY_STRAINS'}};
  $defaults->{"opt_pop_$_"} = 'on'  for @{$variations->{'DEFAULT_STRAINS'}};
  $defaults->{"opt_pop_$variations->{'REFERENCE_STRAIN'}"} = 'off';

  # Add source information if we have a variation database
  foreach (keys %{$variations->{'tables'}{'source'}{'counts'} || {}}){
    my $name = 'opt_' . lc $_;
    $name    =~ s/\s+/_/g;
    $defaults->{$name} = 'on';
  }

  foreach (keys %options) {
    my %hash = %{$options{$_}};
    $defaults->{lc $_} = $hash{$_}[0] for keys %hash;
  }
  
  $self->set_defaults($defaults);

  $self->title = 'Variations';
}

sub form {
  my $self       = shift;
  my $hub        = $self->hub;
  my %options    = EnsEMBL::Web::Constants::VARIATION_OPTIONS;
  my %validation = %{$options{'variation'}};
  my %class      = %{$options{'class'}};
  my %type       = %{$options{'type'}};
  
  # Add source selection
  $self->add_fieldset('Variation source');
  
  foreach (sort keys %{$hub->table_info('variation', 'source')->{'counts'}}) {
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
      name  => lc($_),
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
      name  =>  lc($_),
      value => 'on',
      raw   => 1
    });
  }
  
  # Add type selection
  $self->add_fieldset('Consequence options');
  
  $self->add_form_element({
    type  => 'CheckBox',
    label => 'Show HGVS notations',
    name  => 'hgvs',
    value => 'on',
    raw   => 1
  });
  
  # Add type selection
  $self->add_fieldset('Consequence type');
  
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

  # Add context selection
  $self->add_fieldset('Intron Context');
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    name   => 'context',
    label  => 'Intron Context',
    values => [
      { value => '20',   caption => '20bp' },
      { value => '50',   caption => '50bp' },
      { value => '100',  caption => '100bp' },
      { value => '200',  caption => '200bp' },
      { value => '500',  caption => '500bp' },
      { value => '1000', caption => '1000bp' },
      { value => '2000', caption => '2000bp' },
      { value => '5000', caption => '5000bp' },
      { value => 'FULL', caption => 'Full Introns' }
    ]
  });
}

1;
