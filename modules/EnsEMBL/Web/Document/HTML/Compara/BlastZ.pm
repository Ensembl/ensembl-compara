package EnsEMBL::Web::Document::HTML::Compara::BlastZ;

use strict;

use EnsEMBL::Web::Hub;

use base qw(EnsEMBL::Web::Document::HTML::Compara);

sub render { 
  my $self = shift;
  my $hub = EnsEMBL::Web::Hub->new;
  my $html;
  
  my $compara_db = $hub->database('compara');
  if ($compara_db) {
    my $mlss_adaptor    = $compara_db->get_adaptor('MethodLinkSpeciesSet');
    my $genome_adaptor  = $compara_db->get_adaptor('GenomeDB');
    my @methods = ('BLASTZ_NET', 'LASTZ_NET');
    my $data = {};
    my (@ref_species, %seen);

    foreach my $method (@methods) {
      my $mls_sets      = $mlss_adaptor->fetch_all_by_method_link_type($method);

      foreach my $mlss (@$mls_sets) {

        my $full_ref_name = $mlss->name();

        if(my ($short_ref_name) = $full_ref_name =~ /\(on (.+)\)/) {
          my $ref_genome_db   = $self->get_genome_db($genome_adaptor, $short_ref_name);
          my $ref_genome_name = ucfirst($ref_genome_db->name);
          my $ref_common_name = $hub->species_defs->get_config($ref_genome_name, 'SPECIES_COMMON_NAME');
          $ref_genome_name =~ s/_/ /g;

          foreach my $species (@{$mlss->species_set_obj->genome_dbs}) {
            if ($species->dbID != $ref_genome_db->dbID) {
              my $species_name = ucfirst($species->name);
              my $sp_common_name = $hub->species_defs->get_config($species_name, 'SPECIES_COMMON_NAME');
              $species_name =~ s/_/ /g;
              push @ref_species, $ref_common_name.' ('.$ref_genome_name.')' unless $seen{$ref_genome_name};
              $seen{$ref_genome_name} = 1;
              $data->{$ref_common_name.' ('.$ref_genome_name.')'}->{$sp_common_name.' ('.$species_name.')'} 
                  = [$method, $mlss->dbID];
            }
          }
        }
      }
    }
     
    foreach my $ref_sp (@ref_species) { 
      my $v = $data->{$ref_sp};
      $html .= "<h4>$ref_sp</h4><ul>";
      foreach my $sp (sort keys %$v) {
        my $method  = $v->{$sp}->[0];
        my $mlss_id = $v->{$sp}->[1];
        my $url = '/info/docs/compara/mlss.html?method='.$method.';mlss='.$mlss_id;
        $html .= sprintf '<li><a href="%s">%s</a></li>', $url, $sp;
      }
      $html .= '</ul>';
    }
  }
  return $html;
}

sub get_genome_db {
  my ($self, $adaptor, $short_name) = @_;

  my $all_genome_dbs = $adaptor->fetch_all;
  $short_name =~ tr/\.//d;
  foreach my $genome_db (@$all_genome_dbs) {
    if ($genome_db->short_name eq $short_name) {
      return $genome_db;
    }
  }
}


1;
