package EnsEMBL::Web::Component::Gene::FamilyProteins;

### Displays information about all peptides belonging to a protein family

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);
sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;
  my $family = $object->create_family($object->param('family'));
  my $html;
  

  ## External protein IDs
  my %sources = (
    'UniProt/Swiss-Prot' => 'Uniprot/SWISSPROT',
    'UniProt/TrEMBL'     => 'Uniprot/SPTREMBL'
  ); 
  my %data;
  my $count = 0;
  foreach my $key ( keys %sources ) {
    my @peptides = map { $_->[0]->stable_id } @{$object->member_by_source($family, $sources{$key} )};
    $data{$key} = \@peptides;
    $count .= scalar(@peptides);
  }
  if ($count > 0) {
    $html .= '<h3>Other proteins in this family</h3>';

    my $pep_table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
    $pep_table->add_columns(
      {'key' => 'source',   'title' => 'Source',    'width' => '20%', 'align' => 'left'},
      {'key' => 'peptides', 'title' => 'Proteins', 'width' => '80%', 'align' => 'left'},
    );
    while (my ($source, $peptides) = each(%data)) {
      my $row = {};
      $row->{'source'} = $source;
      $row->{'peptides'} = '<dl class="short_id_list">';
      foreach ( sort @$peptides ) {
        $row->{'peptides'} .= '<dt>'.$object->get_ExtURL_link($_, uc($sources{$source}) ,$_).'</dt>';
      }
      $row->{'peptides'} .= '</dl>';
      $pep_table->add_row($row);
    }
    $html .= $pep_table->render;
  }

  ## Ensembl proteins
  %data = ();
  $count = 0;
  my $current_taxon = $object->database('core')->get_MetaContainer->get_taxonomy_id();
  my @taxa = @{ $object->taxa($family) };
  foreach my $taxon (@taxa) {
    my $id   = $taxon->ncbi_taxid;
    next if $id == $current_taxon;
    my @peptides = map { $_->[0]->stable_id } @{ $family->get_Member_Attribute_by_source_taxon('ENSEMBLPEP', $id) || [] };
    $data{$taxon} = \@peptides;
    $count .= scalar(@peptides);
  }

  if ($count > 0) {
    $html .= '<h3>Ensembl proteins in this family</h3>';

    my $ens_table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
    $ens_table->add_columns(
      {'key' => 'species',   'title' => 'Species',  'width' => '20%', 'align' => 'left'},
      {'key' => 'peptides', 'title' => 'Proteins', 'width' => '80%', 'align' => 'left'},
    );
    foreach my $species (sort {$a->binomial cmp $b->binomial} @taxa ){
      my $row = {};
      my $display_species = $species->binomial;
      $row->{'species'} = $display_species;
      (my $species_key = $display_species) =~ s/\s+/_/;
      $row->{'peptides'} = '<dl class="long_id_list">';
      next unless $data{$species};
      foreach ( sort @{$data{$species}} ) {
        $row->{'peptides'} .= sprintf (qq(<dt><a href="/%s/Transcript/ProteinSummary?peptide=%s">%s</a> [<a href="/%s/Location/View?peptide=%s">location</a>]</dt>), $species_key, $_, $_, $species_key, $_);
      }
      $row->{'peptides'} .= '</dl>';
      $ens_table->add_row( $row );
    }
    $html .= $ens_table->render;
  }

  return $html;
}

1;
