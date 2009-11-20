package EnsEMBL::Web::ViewConfig::Gene::Compara_Tree;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Constants;

sub init {
  my ($view_config) = @_;
  $view_config->_set_defaults(qw(
    image_width          800
    width                800
    collapsability       gene
    colouring            background
    exons                on
    text_format          msf
    tree_format          newick_mode
    newick_mode          full_web
    nhx_mode             full
    scale                150
  ));


  # These data are read from the compara.species_set_tag table at startup time by the
  # ConfigPacker. We want to get the species_sets with a genetree_display tag only.
  # The other tags of interest are: name, genetree_fgcolour and genetree_bgcolour.
  # We also want to strip out 'genetree' from the tags.
  my $hash = $view_config->species_defs->multi_hash->{'DATABASE_COMPARA'}{'SPECIES_SET'}||{};
  foreach my $name (grep { $hash->{$_}{'genetree_display'} } keys %$hash) {
    while (my ($key, $value) = each %{$hash->{$name}}) {
      $key =~ s/^genetree_//;
      if (ref($value) eq "ARRAY") {
        $value = join("_", @$value);
      }
      $view_config->_set_defaults("group_${name}_$key", $value);
    }
  }

  $view_config->storable = 1;
  $view_config->nav_tree = 1;
}

sub form {
  my( $view_config, $object ) = @_;
  
  my @groups;
  # The groups are defined in the compara.species_set_tag tables. We want those that have
  # a genetree_display tag. The groups are sorted by size first and then by name.
  my $hash = $view_config->species_defs->multi_hash->{'DATABASE_COMPARA'}{'SPECIES_SET'}||{};
  foreach my $name (sort {
          @{$hash->{$b}->{genome_db_ids}} <=> @{$hash->{$a}->{genome_db_ids}} || $a cmp $b
      } grep { $hash->{$_}{'genetree_display'} } keys %$hash) {
    push(@groups, $name);
  }

  my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;

  my $function = $object->function;
  
  if ($function eq 'Align') {
    my %formats = EnsEMBL::Web::Constants::ALIGNMENT_FORMATS;
    
    $view_config->add_fieldset('Aligment output');
    
    $view_config->add_form_element({
      type   => 'DropDown', 
      select => 'select',
      name   => 'text_format',
      label  => 'Output format for sequence alignment',
      values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
    });
  } elsif ($function eq 'Text') {
    my %formats = EnsEMBL::Web::Constants::TREE_FORMATS;
    
    $view_config->add_fieldset('Text tree output');
    
    $view_config->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'tree_format',
      label  => 'Output format for tree',
      values => [ map {{ value => $_, name => $formats{$_}{'caption'} }} sort keys %formats ]
    });

    $view_config->add_form_element({
      type     => 'PosInt',
      required => 'yes',
      name     => 'scale',
      label    => 'Scale size for Tree text dump'
    });

    %formats = EnsEMBL::Web::Constants::NEWICK_OPTIONS;
    
    $view_config->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'newick_mode',
      label  => 'Mode for Newick tree dumping',
      values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
    });

    %formats = EnsEMBL::Web::Constants::NHX_OPTIONS;
    
    $view_config->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => 'nhx_mode',
      label  => 'Mode for NHX tree dumping',
      values => [ map {{ value => $_, name => $formats{$_} }} sort keys %formats ]
    });
  } else {
    $view_config->add_fieldset('Image options');

    $view_config->add_form_element({
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

    $view_config->add_form_element({
      'type'  => 'CheckBox',
      'label' => "Display exon boundaries",
      'name'  => 'exons',
      'value' => 'on',
      'raw'   => 1,
    });

    if (@groups) {
      $view_config->add_form_element({
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
      $view_config->add_form_element({
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
