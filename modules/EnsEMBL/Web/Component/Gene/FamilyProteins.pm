package EnsEMBL::Web::Component::Gene::FamilyProteins;

### Displays information about all peptides belonging to a protein family

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Constants;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub content_other {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;
  my $family = $object->create_family($object->param('family'));
  return '' unless $family;
  my $html;
  
  ## External protein IDs
  my %sources = EnsEMBL::Web::Constants::FAMILY_EXTERNAL();
  my $count = 0;
  
  my $member_skipped_count   = 0;
  my @member_skipped_species = ();

  foreach my $key ( sort keys %sources ) {
    my @peptides = map { $_->[0]->stable_id } @{$object->member_by_source($family, $sources{$key}{'key'} )};
    if( @peptides ) {
      $count += @peptides; 
      unless( $object->param( "opt_$key" ) eq 'yes' ) {
        push @member_skipped_species, $sources{$key}{'name'};
        $member_skipped_count += @peptides;
        next;
      }
      my $pep_table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px','header'=>'no'} );
      $pep_table->add_columns(
        {'key' => '',   'title' => '', 'align' => 'center' },
        {'key' => '',   'title' => '', 'align' => 'center' },
        {'key' => '',   'title' => '', 'align' => 'center' },
        {'key' => '',   'title' => '', 'align' => 'center' },
        {'key' => '',   'title' => '', 'align' => 'center' },
        {'key' => '',   'title' => '', 'align' => 'center' }
      );
      my @table_data = ();
      foreach ( sort @peptides ) {
        push @table_data, $object->get_ExtURL_link( $_, uc($sources{$key}{'key'} ), $_ );
        next unless @table_data == 6;
        $pep_table->add_row( [@table_data] );
        @table_data = ();
      }
      $html .= sprintf( '<h3>%s proteins in this family</h3>', $sources{$key}{'name'} ). $pep_table->render;
    }
  }
  unless( $count ) {
    $html .= '<p>No other proteins from this family were found in the following sources:'.join(', ', map { $sources{$_}{'name'} } sort keys %sources).'</p>';
  }

  if( $member_skipped_count ) {
    $html .= $self->_warning( 'Members hidden by configuration', sprintf '
  <p>
    %d members not shown in the tables above from the following databases: %s. Use the "<strong>Configure this page</strong>" on the left to show them.
  </p>%s', $member_skipped_count, join (', ',sort @member_skipped_species )
    )
  }

  return $html;
}

sub content_ensembl {
  my $self = shift;
  my $object = $self->object;
  my $species = $object->species;
  my $family = $object->create_family($object->param('family'));
  return '' unless $family;
  my $html = '';
  ## Ensembl proteins
  my %data = ();
  my $count = 0;
  my $current_taxon = $object->database('core')->get_MetaContainer->get_taxonomy_id();
  my @taxa = @{ $family->get_all_taxa_by_member_source_name('ENSEMBLPEP') };
  foreach my $taxon (@taxa) {
    my $id   = $taxon->ncbi_taxid;
    my @peptides = map { $_->[0]->stable_id } @{ $family->get_Member_Attribute_by_source_taxon('ENSEMBLPEP', $id) || [] };
    $data{$taxon} = \@peptides;
    $count += scalar(@peptides);
  }

  my $member_skipped_count   = 0;
  my @member_skipped_species = ();

  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;
  $html .= "<h3>$sitename proteins in this family</h3>";
  if( $count > 0 ) {
    my $ens_table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
    $ens_table->add_columns(
      {'key' => 'species',   'title' => 'Species',  'width' => '20%', 'align' => 'left'},
      {'key' => 'peptides', 'title' => 'Proteins', 'width' => '80%', 'align' => 'left'},
    );
    foreach my $species (sort {$a->binomial cmp $b->binomial} @taxa ){
      my $display_species = $species->binomial;
      (my $species_key = $display_species) =~ s/\s+/_/;
       
      unless( $object->param( "species_".lc($species_key) ) eq 'yes' ) {
        push @member_skipped_species, $display_species;
        $member_skipped_count += @{$data{$species}};
        next;
      }

      my $row = {};
      $row->{'species'} = $object->species_defs->species_label( $species_key );
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
  else {
    $html .= "<p>No proteins from this family were found in any other $sitename species</p>";
  }

  if( $member_skipped_count ) {
    $html .= $self->_warning( 'Members hidden by configuration', sprintf '
  <p>
    %d members not shown in the table above from the following species: %s. Use the "<strong>Configure this page</strong>" on the left to show them.
  </p>%s', $member_skipped_count, join (', ',map { "<i>$_</i>" } sort @member_skipped_species )
    )
  }

  return $html;
}

1;
