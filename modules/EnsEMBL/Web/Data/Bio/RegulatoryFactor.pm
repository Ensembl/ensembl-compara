package EnsEMBL::Web::Data::Bio::RegulatoryFactor;

### NAME: EnsEMBL::Web::Data::Bio::RegulatoryFactor
### Base class - wrapper around a Bio::EnsEMBL::ExternalFeature API object 

### STATUS: Under Development

### DESCRIPTION:
### This module provides additional data-handling
### capabilities on top of those provided by the API

use strict;
use warnings;
no warnings qw(uninitialized);

use base qw(EnsEMBL::Web::Data::Bio);

sub convert_to_drawing_parameters {
### Converts a set of API objects into simple parameters 
### for use by drawing code and HTML components
  my $self = shift; warn $self;
  my $data = $self->data_objects;
  my $results = [];

  foreach my $reg (@$data) {
    my @stable_ids;
    my $gene_links;
    my $db_ent = $reg->get_all_DBEntries;
    foreach ( @{ $db_ent} ) {
      push @stable_ids, $_->primary_id;
      my $url = $self->hub->url({'type' => 'Gene', 'action' => 'Summary', 'g' => $stable_ids[-1] });
      $gene_links  .= qq(<a href="$url">$stable_ids[-1]</a>);
    }

    my @extra_results = $reg->analysis->description;
    ## Sort out any links/URLs
    if ($extra_results[0] =~ /a href/i) {
      $extra_results[0] =~ s/a href/a rel="external" href/ig;
    }
    else {
      $extra_results[0] =~ s/(https?:\/\/\S+[\w\/])/<a rel="external" href="$1">$1<\/a>/ig;
    }

    push @$results, {
      'region'   => $reg->seq_region_name,
      'start'    => $reg->start,
      'end'      => $reg->end,
      'strand'   => $reg->strand,
      'length'   => $reg->end-$reg->start+1,
      'label'    => $reg->display_label,
      'gene_id'  => \@stable_ids,
      'extra'    => {
                    'gene'      => $gene_links,
                    'analysis'  => \@extra_results,
      },
    }
  }
  my $extra_columns = [
                    {'key' => 'gene',     'title' => 'Associated gene'},
                    {'key' => 'analysis', 'title' => 'Feature analysis', 'sort' => 'html'},
  ];
  return [$results, $extra_columns];
}

1;
