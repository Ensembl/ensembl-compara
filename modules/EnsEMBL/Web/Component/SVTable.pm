=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::SVTable;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use parent qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $object  = $self->object;  
  my $slice   = $object->slice;
  my $html    = $self->structural_variation_table($slice, 'Structural variants',        'sv',  ['fetch_all_by_Slice','fetch_all_somatic_by_Slice'], 1);
     $html   .= $self->structural_variation_table($slice, 'Copy number variant probes', 'cnv', ['fetch_all_cnv_probe_by_Slice']);
  
  return $html;
}

sub structural_variation_table {
  my ($self, $slice, $title, $table_id, $functions, $open) = @_;
  my $hub = $self->hub;
  my $svf_adaptor = $hub->database('variation')->get_StructuralVariationFeatureAdaptor;
  my $rows;

  my $columns = [
     { key => 'id',          sort => 'string',         title => 'Name'   },
     { key => 'location',    sort => 'position_html',  title => 'Chr:bp' },
     { key => 'size',        sort => 'numeric_hidden', title => 'Genomic size (bp)' },
     { key => 'class',       sort => 'string',         title => 'Class'  },
     { key => 'source',      sort => 'string',         title => 'Source Study' },
     { key => 'description', sort => 'string',         title => 'Study description', width => '50%' },
  ];

  my $svfs;
  foreach my $func (@{$functions}) {
    push(@$svfs, @{$svf_adaptor->$func($slice)});
  }

  if ( !$svfs || scalar(@{$svfs}) < 1 ) {
    my $my_title = lc($title);
    return "<p>No $my_title associated with this variant.</p>";
  }

  foreach my $svf (@{$svfs}) {
    my $name        = $svf->variation_name;
    my $description = $svf->source_description;
    my $sv_class    = $svf->var_class;
    my $source      = $svf->source->name;

    if ($svf->study) {
      my $ext_ref    = $svf->study->external_reference;
      my $study_name = $svf->study->name;
      my $study_url  = $svf->study->url;

      if ($study_name) {
        $source      .= ":$study_name";
        $source       = qq{<a rel="external" href="$study_url">$source</a>} if $study_url;
        $description .= ': ' . $svf->study->description;
      }

      if ($ext_ref =~ /pubmed\/(.+)/) {
        my $pubmed_id   = $1;
        my $pubmed_link = $hub->get_ExtURL('PUBMED', $pubmed_id);
           $description =~ s/$pubmed_id/<a href="$pubmed_link" target="_blank">$pubmed_id<\/a>/g;
      }
    }

    # SV size (format the size with comma separations, e.g: 10000 to 10,000)
    my $sv_size = $svf->length;
       $sv_size ||= '-';

    my $hidden_size  = sprintf(qq{<span class="hidden">%s</span>},($sv_size eq '-') ? 0 : $sv_size);

    my $int_length = length $sv_size;

    if ($int_length > 3) {
      my $nb         = 0;
      my $int_string = '';

      while (length $sv_size > 3) {
        $sv_size    =~ /(\d{3})$/;
        $int_string = ",$int_string" if $int_string ne '';
        $int_string = "$1$int_string";
        $sv_size    = substr $sv_size, 0, (length($sv_size) - 3);
      }

      $sv_size = "$sv_size,$int_string";
    }

    my $sv_link = $hub->url({
      type   => 'StructuralVariation',
      action => 'Explore',
      sv     => $name
    });
    my $loc_string = $svf->seq_region_name . ':' . $svf->seq_region_start . '-' . $svf->seq_region_end;

    my $loc_link = $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $loc_string,
    });

    my %row = (
      id          => qq{<a href="$sv_link">$name</a>},
      location    => qq{<a href="$loc_link">$loc_string</a>},
      size        => $hidden_size.$sv_size,
      class       => $sv_class,
      source      => $source,
      description => $description,
    );

    push @$rows, \%row;
  }

  return $self->toggleable_table($title, $table_id, $self->new_table($columns, $rows, { data_table => 1, sorting => [ 'location asc' ], data_table_config => {iDisplayLength => 25} }), $open);
}


1;
