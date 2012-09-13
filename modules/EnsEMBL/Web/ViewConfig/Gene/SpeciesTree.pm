# $Id$

package EnsEMBL::Web::ViewConfig::Gene::SpeciesTree;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  my $hash = $self->species_defs->multi_hash->{'DATABASE_COMPARA'}{'SPECIES_SET'} || {}; 
  
  my $defaults = {
    collapsability => 'gene',
  };
     
  #getting the clade colour for each species type (tree background colour based on the species type)
  foreach my $name (grep $hash->{$_}{'genetree_display'}, keys %$hash) {
    while (my ($key, $value) = each %{$hash->{$name}}) {
      $key   =~ s/^genetree_//;
      $value = join '_', @$value if ref $value eq 'ARRAY';
      $defaults->{"group_${name}_$key"} = $value;
    }
  }
  
  $self->set_defaults($defaults);
  $self->add_image_config('speciestreeview', 'nodas');
  $self->code  = join '::', grep $_, 'Gene::SpeciesTree', $self->hub->referer->{'ENSEMBL_FUNCTION'};  
  $self->title = 'Species Tree';
}

sub form {
  my $self = shift;
  
    $self->add_fieldset('Display options');

    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'collapsability',
      label  => 'Viewing options for tree image',
      values => [ 
        { value => 'all',          name => 'View full species tree' },
        { value => 'part',         name => 'View minimal species tree' }
      ]
    });    
}

1;
