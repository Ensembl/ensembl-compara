package EnsEMBL::Web::ViewConfig::Gene::Compara_Alignments;

use strict;
use warnings;
no warnings 'uninitialized';
use EnsEMBL::Web::Constants;

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
  my %gene_markup_options    =  EnsEMBL::Web::Constants::GENE_MARKUP_OPTIONS;
  #options shared with resequencing and marked-up sequence
  my %general_markup_options = EnsEMBL::Web::Constants::GENERAL_MARKUP_OPTIONS;
  #options shared with resequencing
  my %other_markup_options = EnsEMBL::Web::Constants::OTHER_MARKUP_OPTIONS;

  $view_config->add_form_element($gene_markup_options{'flank5_display'});
  $view_config->add_form_element($gene_markup_options{'flank3_display'});
  $view_config->add_form_element($other_markup_options{'display_width'});

  if ($object->species_defs->databases->{'DATABASE_VEGA'}) {
      push @{$gene_markup_options{'exon_display'}{'values'}}, { 'value' => 'vega', 'name' => 'Vega exons' };
  }
  if ($object->species_defs->databases->{'DATABASE_OTHERFEATURES'}) {
      push @{$gene_markup_options{'exon_display'}{'values'}},  { 'value' => 'otherfeatures', 'name' => 'EST gene exons' };
  }
  $view_config->add_form_element($gene_markup_options{'exon_display'});

  $view_config->add_form_element($general_markup_options{'exon_ori'});
  if( $object->species_defs->databases->{'DATABASE_VARIATION'} ) {
    $view_config->add_form_element( $general_markup_options{'snp_display'} );
  }
  $view_config->add_form_element($general_markup_options{'line_numbering'} );
  $view_config->add_form_element($other_markup_options{'codons_display'});
  $view_config->add_form_element($other_markup_options{'title_display'});

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
 #     warn $name;
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

