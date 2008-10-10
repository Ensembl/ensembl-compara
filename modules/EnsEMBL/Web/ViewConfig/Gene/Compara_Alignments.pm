package EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments;

use strict;
use warnings;
no warnings 'uninitialized';

sub init {
  my ($view_config) = @_;
  $view_config->title = 'Genomic Alignments';
  $view_config->_set_defaults(qw(
    flank5_display          600
    flank3_display          600
    exon_display            core
    exon_ori                all
    snp_display             off
    line_numbering          off
    display_width           120
    conservation            all
    codons_display          off
    title_display           off
  ));
  $view_config->storable = 1;
}

sub form {
  my( $view_config, $object ) = @_;

  #options shared with marked-up sequence
  $view_config->add_form_element({
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "5' Flanking sequence",  'name' => 'flank5_display',
  });
  $view_config->add_form_element({
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "3' Flanking sequence",  'name' => 'flank3_display',
  });
  my $values = [
    { 'value' => 'off',           'name' => 'No exon markup' },
    { 'value' => 'Ab-initio',     'name' => 'Ab-initio exons' },
    { 'value' => 'core',          'name' => "Core exons" }
  ];
  push @$values, { 'value' => 'vega', 'name' => 'Vega exons' }
    if $object->species_defs->databases->{'DATABASE_VEGA'};
  push @$values, { 'value' => 'otherfeatures', 'name' => 'EST gene exons' }
    if $object->species_defs->databases->{'DATABASE_OTHERFEATURES'};

  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_display',
    'label'    => 'Additional exons to display',
    'values'   => $values
  });
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'exon_ori',
    'label'    => "Orientation of additional exons",
    'values'   => [
      { 'value' =>'fwd' , 'name' => 'Display same orientation exons only' },
      { 'value' =>'rev' , 'name' => 'Display reverse orientation exons only' },
      { 'value' =>'all' , 'name' => 'Display exons in both orientations' }
    ]
  });
  if( $object->species_defs->databases->{'DATABASE_VARIATION'} ) {
    $view_config->add_form_element({
      'type'     => 'DropDown', 'select'   => 'select',
      'required' => 'yes',      'name'     => 'snp_display',
      'label'    => 'Show variations',
      'values'   => [
        { 'value' =>'off',       'name' => 'No' },
        { 'value' =>'snp',       'name' => 'Yes' },
        { 'value' =>'snp_link' , 'name' => 'Yes and show links' },
      ]
    });
  }
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'line_numbering',
    'label'    => 'Line numbering',
    'values'   => [
      { 'value' =>'sequence' , 'name' => 'Relative to this sequence' },
      { 'value' =>'slice'    , 'name' => 'Relative to coordinate systems' },
      { 'value' =>'off'      , 'name' => 'None' },
    ]
  });

  #specific options
  $view_config->add_form_element({
    'type' => 'NonNegInt', 'required' => 'yes',
    'label' => "Alignment width",  'name' => 'display_width',
  });
  my $conservation = [
    { 'value' =>'all' , 'name' => 'All conserved regions' },
    { 'value' =>'off' , 'name' => 'None' },
  ];
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'conservation',
    'label'    => 'Conservation regions',
    'values'   => $conservation,
  });
  my $codons_display = [
    { 'value' =>'all' , 'name' => 'START/STOP codons' },
    { 'value' =>'off' , 'name' => "Do not show codons" },
  ];
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'codons_display',
    'label'    => 'Codons',
    'values'   => $codons_display,
  });
  my $title_display = [
    { 'value' =>'all' , 'name' => 'Include `title` tags' },
    { 'value' =>'off' , 'name' => 'None' },
  ];
  $view_config->add_form_element({
    'type'     => 'DropDown', 'select'   => 'select',
    'required' => 'yes',      'name'     => 'title_display',
    'label'    => 'Title display',
    'values'   => $title_display,
  });

  my $species = $view_config->species;
  my $hash = $view_config->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}||{};

#  $object->param("RGselect",'171'); #hack to get script working
  $object->param("RGselect",'NONE'); #hack to get script working


# From release to release the alignment ids change so we need to check that the passed id is still valid.

# Need to collapse these panels


  foreach my $row_key (
#    sort { scalar(@{$hash->{$a}{'species'}})<=> scalar(@{$hash->{$b}{'species'}}) }
    grep { $hash->{$_}{'class'} !~ /pairwise/ }
    keys %$hash
  ) {
    my $row = $hash->{$row_key};
    next unless $row->{'species'}{$species};
    $view_config->add_fieldset( "Options for ".$row->{'name'} );
    foreach( sort keys %{$row->{'species'}} ) {
      my $name = 'species_'.$row_key.'_'.lc($_);
      if( $_ eq $species ) {
        $view_config->add_form_element({
          'type'     => 'Hidden',   'name' => $name
        });
      } else {
        $view_config->add_form_element({
          'type'     => 'CheckBox', 'label' => $view_config->_species_label($_),
          'name'     => $name,
          'value'    => 'yes', 'raw' => 1
        });
      }
    }
  }

  $view_config->add_fieldset( "Options for pairwise alignments" );
  foreach my $row_key (
#    sort { scalar(@{$hash->{$a}{'species'}})<=> scalar(@{$hash->{$b}{'species'}}) }
    grep { $hash->{$_}{'class'} =~ /pairwise/ }
    keys %$hash
  ) {
    my $row = $hash->{$row_key};
    next unless $row->{'species'}{$species};
    foreach( sort keys %{$row->{'species'}} ) {
      my $name = 'species_'.$row_key.'_'.lc($_);
      warn $name;
      if( $_ ne $species ) {
        $view_config->add_form_element({
          'type'     => 'CheckBox', 'label' => $view_config->_species_label($_),
          'name'     => $name,
          'value'    => 'yes', 'raw' => 1
        });
      }
    }
  }
}
1;

