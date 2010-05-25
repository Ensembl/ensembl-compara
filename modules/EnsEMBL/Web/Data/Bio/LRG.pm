package EnsEMBL::Web::Data::Bio::LRG;

### NAME: EnsEMBL::Web::Data::Bio::LRG
### Wrapper around a hashref containing two Bio::EnsEMBL:: objects, one on
### LRG coordinates and one on standard Ensembl chromosomal coordinates 

### STATUS: Under Development

### DESCRIPTION:
### This module and its children provide additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
  my $self = shift;
  my $data = $self->data_objects;
  my $results = [];

  foreach my $slice_pair (@$data) {
    my $lrg = $slice_pair->{'lrg'};
    my $chr = $slice_pair->{'chr'};
    
    # get the LRG's HGNC name
    my $lrg_sr_name = $lrg->seq_region_name;
    my $gene = (grep {$_->stable_id =~ /$lrg_sr_name\_/} @{$lrg->get_all_Genes_by_type('LRG_gene')})[0];
    my $hgnc_name = (grep {$_->dbname =~ /hgnc/i} @{$gene->get_all_DBEntries})[0]->display_id;
    
    if (ref($lrg) =~ /UnmappedObject/) {
      my $unmapped = $self->unmapped_object($lrg);
      push(@$results, $unmapped);
    }
    
    else {
      (my $lrg_number = $lrg_sr_name) =~ s/^LRG_//i; 
      push @$results, {
        'lrg_name'    => $lrg_sr_name,
        'lrg_number'  => $lrg_number,
        'lrg_start'   => $lrg->start,
        'lrg_end'     => $lrg->end,
        'region'      => $chr->seq_region_name,
        'start'       => $chr->start,
        'end'         => $chr->end,
        'strand'      => $lrg->strand,
        'length'      => $lrg->seq_region_length,
        'label'       => $chr->name,
        'hgnc_name'   => $hgnc_name,
      };
    }
  }

  return [$results, [], 'LRG'];
}

1;
