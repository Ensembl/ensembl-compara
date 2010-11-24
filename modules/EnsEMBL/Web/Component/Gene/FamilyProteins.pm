# $Id$

package EnsEMBL::Web::Component::Gene::FamilyProteins;

### Displays information about all peptides belonging to a protein family

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content_other {
  my $self    = shift;
  my $hub     = $self->hub;
  my $cdb     = shift || $hub->param('cdb') || 'compara';
  my $object  = $self->object;
  my $species = $hub->species;
  my $family  = $object->create_family($hub->param('family'), $cdb);
  
  return '' unless $family;
  
  ## External protein IDs
  my %sources                = EnsEMBL::Web::Constants::FAMILY_EXTERNAL;
  my $count                  = 0;
  my $member_skipped_count   = 0;
  my @member_skipped_species;
  my $html;

  foreach my $key (sort keys %sources) {
    my @peptides = map { $_->[0]->stable_id } @{$object->member_by_source($family, $sources{$key}{'key'})};
    my $row_count;
    
    if (@peptides) {
      $count += @peptides;
      
      if ($hub->param("opt_$key") ne'yes') {
        push @member_skipped_species, $sources{$key}{'name'};
        $member_skipped_count += @peptides;
        next;
      }
      
      my $pep_table = $self->new_table([], [], { margin => '1em 0px', header => 'no' });
      
      $pep_table->add_columns(
        { key => '', title => '', align => 'center' },
        { key => '', title => '', align => 'center' },
        { key => '', title => '', align => 'center' },
        { key => '', title => '', align => 'center' },
        { key => '', title => '', align => 'center' },
        { key => '', title => '', align => 'center' }
      );
      
      my @table_data;
      
      foreach (sort @peptides) {
        push @table_data, $hub->get_ExtURL_link($_, uc $sources{$key}{'key'}, $_);
        
        next unless @table_data == 6;
        
        $pep_table->add_row([@table_data]);
        $row_count++;
        @table_data = ();
      }

      if (@table_data) {
        $pep_table->add_row([@table_data]);
        $row_count++;
      }

      # don't render table unless we actually put something in it
      $html .= "<h3>$sources{$key}{'name'} proteins in this family</h3>" . $pep_table->render if $row_count;
    }
  }
  
  $html .= sprintf '<p>No other proteins from this family were found in the following sources:%s</p>', join(', ', map $sources{$_}{'name'}, sort keys %sources) unless $count;

  if ($member_skipped_count) {
    $html .= $self->_warning('Members hidden by configuration', sprintf('
      <p>%d members not shown in the tables above from the following databases: %s. Use the "<strong>Configure this page</strong>" on the left to show them.</p>%s',
      $member_skipped_count, join (', ', sort @member_skipped_species)
    ))
  }

  return $html;
}

sub content_ensembl {
  my $self    = shift;
  my $hub     = $self->hub;
  my $cdb     = shift || $hub->param('cdb') || 'compara';
  my $species = $hub->species;
  my $family  = $self->object->create_family($hub->param('family'), $cdb);
  
  return '' unless $family;
  
  my $species_defs  = $hub->species_defs;
  my $sitename      = $species_defs->ENSEMBL_SITETYPE;
  my $current_taxon = $hub->database('core')->get_MetaContainer->get_taxonomy_id;
  my @taxa          = @{$family->get_all_taxa_by_member_source_name('ENSEMBLPEP')}; ## Ensembl proteins
  my $count         = 0;
  my %data;
  my $html;
  
  foreach my $taxon (@taxa) {
    my $id        = $taxon->ncbi_taxid;
    my @peptides  = map $_->[0]->stable_id, @{$family->get_Member_Attribute_by_source_taxon('ENSEMBLPEP', $id) || []};
    $data{$taxon} = \@peptides;
    $count       += scalar(@peptides);
  }

  my $member_skipped_count = 0;
  my @member_skipped_species;
  
  $html .= "<h3>$sitename proteins in this family</h3>";
  
  if ($count > 0) {
    my $ens_table = $self->new_table([], [], { margin  => '1em 0px' });
    
    $ens_table->add_columns(
      { key => 'species',  title => 'Species',  width => '20%', align => 'left' },
      { key => 'peptides', title => 'Proteins', width => '80%', align => 'left' },
    );
    
    foreach my $species (sort { $a->binomial cmp $b->binomial } @taxa) {
      my $display_species = $species->binomial || $species->name;
      (my $species_key    = $display_species) =~ s/\s+/_/;
       
      if ($hub->param('species_' . lc $species_key) ne 'yes') {
        push @member_skipped_species, $display_species;
        $member_skipped_count += @{$data{$species}};
        next;
      }

      next unless $data{$species};
      
      my $row = {
        species  => $species_defs->species_label($species_key),
        peptides => '<dl class="long_id_list">'
      };
      
      foreach (sort @{$data{$species}}) {
        $row->{'peptides'} .= sprintf qq(<dt><a href="/%s/Transcript/ProteinSummary?peptide=%s">%s</a> [<a href="/%s/Location/View?peptide=%s">location</a>]</dt>), $species_key, $_, $_, $species_key, $_;
      }
      
      $row->{'peptides'} .= '</dl>';
      $ens_table->add_row($row);
    }
    
    $html .= $ens_table->render;
  } else {
    $html .= "<p>No proteins from this family were found in any other $sitename species</p>";
  }

  if ($member_skipped_count) {
    $html .= $self->_warning('Members hidden by configuration', sprintf(
      '<p>%d members not shown in the table above from the following species: %s. Use the "<strong>Configure this page</strong>" on the left to show them.</p>%s',
      $member_skipped_count, join(', ',map "<i>$_</i>", sort @member_skipped_species)
    ));
  }

  return $html;
}

1;
