package EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments;

use strict;
use warnings;
no warnings 'uninitialized';
use EnsEMBL::Web::Constants;

sub init {
  my $view_config = shift;
  
  $view_config->title = 'Genomic Alignments';
  $view_config->_set_defaults(qw(
    flank5_display        600
    flank3_display        600
    exon_display          core
    exon_ori              all
    snp_display           off
    line_numbering        off
    display_width         120
    conservation_display  off
    region_change_display off
    codons_display        off
    title_display         off
  ));
  $view_config->storable = 1;
  
  my $hash = $view_config->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};
  
  foreach my $row_key (grep { $hash->{$_}{'class'} !~ /pairwise/ } keys %$hash) {
    $view_config->_set_defaults(map {( lc("species_$row_key"."_$_"), 'yes' )} grep { $_ !~ /Ancestral/ } keys %{$hash->{$row_key}{'species'}});
  }
}

sub form {
  my ($view_config, $object, $species_only) = @_;
  
  if (!$species_only) {
    my %gene_markup_options    = EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS; # options shared with marked-up sequence
    my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS; # options shared with resequencing and marked-up sequence
    my %other_markup_options   = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS; # options shared with resequencing

    if (!$view_config->{'no_flanking'}) {
      $view_config->add_form_element($gene_markup_options{'flank5_display'});
      $view_config->add_form_element($gene_markup_options{'flank3_display'});
    }
    
    $view_config->add_form_element($other_markup_options{'display_width'});

    if ($object->species_defs->databases->{'DATABASE_VEGA'}) {
      push @{$gene_markup_options{'exon_display'}{'values'}}, { 'value' => 'vega', 'name' => 'Vega exons' };
    }
    
    if ($object->species_defs->databases->{'DATABASE_OTHERFEATURES'}) {
      push @{$gene_markup_options{'exon_display'}{'values'}}, { 'value' => 'otherfeatures', 'name' => 'EST gene exons' };
    }
    
    $view_config->add_form_element($gene_markup_options{'exon_display'});
    $view_config->add_form_element($general_markup_options{'exon_ori'});
    
    if ($object->species_defs->databases->{'DATABASE_VARIATION'}) {
      $view_config->add_form_element($general_markup_options{'snp_display'});
    }
    
    $view_config->add_form_element($general_markup_options{'line_numbering'});
    $view_config->add_form_element($other_markup_options{'codons_display'});

    $view_config->add_form_element({
      'required' => 'yes',
      'name' => 'conservation_display',
      'values' => [{
        'value' => 'all',
        'name' => 'All conserved regions'
      }, {
        'value' => 'off',
        'name' => 'None'
      }],
      'label' => 'Conservation regions',
      'type' => 'DropDown',
      'select' => 'select'
    });
    $view_config->add_form_element({
      'required' => 'yes',
      'name' => 'region_change_display',
      'values' => [{
        'value' => 'yes',
        'name' => 'Yes'
      }, {
        'value' => 'off',
        'name' => 'No'
      }],
     'label' => 'Mark alignment start/end',
     'type' => 'DropDown',
     'select' => 'select'
    });
    
    $view_config->add_form_element($other_markup_options{'title_display'});
  }
    
  my $species = $view_config->species;
  my $hash = $view_config->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};

  # From release to release the alignment ids change so we need to check that the passed id is still valid.
  foreach my $row_key (grep { $hash->{$_}{'class'} !~ /pairwise/ } keys %$hash) {
    my $row = $hash->{$row_key};
    
    next unless $row->{'species'}{$species};
    
    $view_config->add_fieldset("Options for $row->{'name'}");
    
    foreach (sort keys %{$row->{'species'}}) {
      next if /merged/;
      
      my $name = 'species_'.$row_key.'_'.lc($_);
      
      if ($_ eq $species) {
        $view_config->add_form_element({
          'type' => 'Hidden',
          'name' => $name
        });
      } else {
        $view_config->add_form_element({
          'type'  => 'CheckBox', 
          'label' => $view_config->_species_label($_),
          'name'  => $name,
          'value' => 'yes',
          'raw'   => 1
        });
      }
    }
  }
}

1;

