# $Id$

package EnsEMBL::Web::ViewConfig::Gene::ComparaTree;

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  
  # These data are read from the compara.species_set_tag table at startup time by the
  # ConfigPacker. We want to get the species_sets with a genetree_display tag only.
  # The other tags of interest are: name, genetree_fgcolour and genetree_bgcolour.
  # We also want to strip out 'genetree' from the tags.
  my $hash     = $self->species_defs->multi_hash->{'DATABASE_COMPARA'}{'SPECIES_SET'} || {};
  my $defaults = {
    collapsability => 'gene',
    colouring      => 'background',
    exons          => 'on',
    text_format    => 'msf',
    tree_format    => 'newick_mode',
    newick_mode    => 'full_web',
    nhx_mode       => 'full',
    scale          => 150,
  };
  
  foreach my $name (grep $hash->{$_}{'genetree_display'}, keys %$hash) {
    while (my ($key, $value) = each %{$hash->{$name}}) {
      $key   =~ s/^genetree_//;
      $value = join '_', @$value if ref $value eq 'ARRAY';
      $defaults->{"group_${name}_$key"} = $value;
    }
  }
  
  $self->set_defaults($defaults);
  
  $self->code = join '::', grep $_, 'Gene::ComparaTree', $self->hub->referer->{'ENSEMBL_FUNCTION'};
}

sub form {
  my $self = shift;
  
  # The groups are defined in the compara.species_set_tag tables. We want those that have
  # a genetree_display tag. The groups are sorted by size first and then by name.
  my $hash     = $self->species_defs->multi_hash->{'DATABASE_COMPARA'}{'SPECIES_SET'} || {};
  my @groups   = sort { @{$hash->{$b}->{'genome_db_ids'}} <=> @{$hash->{$a}->{'genome_db_ids'}} || $a cmp $b } grep { $hash->{$_}{'genetree_display'} } keys %$hash;
  my $function = $self->hub->referer->{'ENSEMBL_FUNCTION'};
  
  if ($function eq 'Align') {
    my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
    
    $self->add_fieldset('Aligment output');
    
    $self->add_form_element({
      type   => 'DropDown', 
      select => 'select',
      name   => 'text_format',
      label  => 'Output format for sequence alignment',
      values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
    });
  } elsif ($function eq 'Text') {
    my %formats = EnsEMBL::Web::Constants::TREE_FORMATS;
    
    $self->add_fieldset('Text tree output');
    
    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'tree_format',
      label  => 'Output format for tree',
      values => [ map {{ value => $_, name => $formats{$_}{'caption'} }} sort keys %formats ]
    });

    $self->add_form_element({
      type     => 'PosInt',
      required => 'yes',
      name     => 'scale',
      label    => 'Scale size for Tree text dump'
    });

    %formats = EnsEMBL::Web::Constants::NEWICK_OPTIONS;
    
    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'newick_mode',
      label  => 'Mode for Newick tree dumping',
      values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
    });

    %formats = EnsEMBL::Web::Constants::NHX_OPTIONS;
    
    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'nhx_mode',
      label  => 'Mode for NHX tree dumping',
      values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
    });
  } else {
    $self->add_fieldset('Image options');

    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'collapsability',
      label  => 'Viewing options for tree image',
      values => [ 
        { value => 'gene',         name => 'View current gene only' },
        { value => 'paralogs',     name => 'View paralogs of current gene' },
        { value => 'duplications', name => 'View all duplication nodes' },
        { value => 'all',          name => 'View fully expanded tree' }
      ]
    });

    $self->add_form_element({
      'type'  => 'CheckBox',
      'label' => 'Display exon boundaries',
      'name'  => 'exons',
      'value' => 'on',
      'raw'   => 1,
    });

    if (@groups) {
      $self->add_form_element({
        type   => 'DropDown', 
        select => 'select',
        name   => 'colouring',
        label  => 'Colour tree according to taxonomy',
        values => [ 
          { value => 'none',       name => 'No colouring' },
          { value => 'background', name => 'Background' },
          { value => 'foreground', name => 'Foreground' } 
        ]
      });
    }

    foreach my $group (@groups) {
      $self->add_form_element({
        type   => 'DropDown', 
        select => 'select',
        name   => "group_${group}_display",
        label  => "Display options for $group",
        values => [ 
          { value => 'default',  name => 'Default behaviour' },
          { value => 'hide',     name => 'Hide genes' },
          { value => 'collapse', name => 'Collapse genes' } 
        ]
      });
    }
  }
}


1;
