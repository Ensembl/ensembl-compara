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
    my @peptides = map { $_->stable_id } @{$family->get_Member_by_source($sources{$key}{'key'})};
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
  my @genomedbs     = @{$family->get_all_GenomeDBs_by_member_source_name('ENSEMBLPEP')}; ## Ensembl proteins
  my $count         = 0;
  my %data;
  my $html;

  foreach my $genomedb (@genomedbs) { 
    my @peptides  = map $_->stable_id, @{$family->get_Member_by_source_GenomeDB('ENSEMBLPEP', $genomedb) || []};
    $data{$genomedb->dbID} = \@peptides; 
    $count       += scalar(@peptides);
  }

  my $member_skipped_count = 0;
  my @member_skipped_species;

  my $table     = $self->new_twocol;
  my $stable_id = $family->stable_id;
  my $desc      = $family->description;
  $table->add_row("$sitename Family ID",   $stable_id);
  $table->add_row('Description'        , $desc);
  $html .= $table->render;
  
  if ($count > 0) {
    ## No point in exporting alignment if only one peptide!
    $html .= $self->content_buttons if $count > 1;

    my $ens_table = $self->new_table([], [], { margin  => '1em 0px' });
    
    $ens_table->add_columns(
      { key => 'species',  title => 'Species',  width => '20%', align => 'left' },
      { key => 'peptides', title => 'Proteins', width => '80%', align => 'left' },
    );
    
    foreach my $genomedb (sort { $a->name cmp $b->name } @genomedbs) {
      my $species_key = $genomedb->name; 

      if ($hub->param('species_' . lc $species_key) ne 'yes') {
        push @member_skipped_species, $species_defs->species_label($species_key);
        $member_skipped_count += @{$data{$genomedb->dbID}};
        next;
      }

      next unless $data{$genomedb->dbID};
      
      my $row = {
        species  => $species_defs->species_label($species_key),
        peptides => '<dl class="long_id_list">'
      };
      
      foreach (sort @{$data{$genomedb->dbID}}) {
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

sub export_options { return {'action' => 'Family'}; }

sub get_export_data {
## Get data for export
  my $self    = shift;
  ## Need to explicitly create Family, as it's not a standard core object
  $self->hub->{'_builder'}->create_objects('Family', 'lazy');
  my $family = $self->hub->core_object('family');
  if ($family) {
    return $family->Obj->get_SimpleAlign(-APPEND_SP_SHORT_NAME => 1);
  }
}

sub buttons {
  my $self    = shift;
  my $hub     = $self->hub;

  my $params  = {
                  'type'        => 'DataExport',
                  'action'      => 'Family',
                  'data_type'   => 'Gene',
                  'component'   => 'FamilyProteins',
                  'fm'          => $hub->param('fm'),
                  'align'       => 'family',
                };
  return {
    'url'     => $hub->url($params),
    'caption' => 'Download family alignment',
    'class'   => 'export',
    'modal'   => 1
  };
}

1;
