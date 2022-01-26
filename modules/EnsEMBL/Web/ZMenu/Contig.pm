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

package EnsEMBL::Web::ZMenu::Contig;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $threshold       = 1000100 * ($hub->species_defs->ENSEMBL_GENOME_SIZE||1);
  my $slice_name      = $hub->param('region');
  my $db_adaptor      = $hub->database('core');
  my $slice           = $db_adaptor->get_SliceAdaptor->fetch_by_region('seqlevel', $slice_name);
  my $slice_type      = $slice->coord_system_name;
  my $top_level_slice = $slice->project('toplevel')->[0]->to_Slice;
  my $action          = $slice->length > $threshold ? 'Overview' : 'View';

  $self->caption($slice_name);
  
  $self->add_entry({
    label => "Centre on $slice_type $slice_name",
    link  => $hub->url({ 
      type   => 'Location', 
      action => $action, 
      region => $slice_name,
      r => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
    })
  });

  $self->add_entry({
    label      => "Export $slice_type sequence/features",
    link_class => 'modal_link',
    link       => $hub->url({ 
      type     => 'Export',
      action   => 'Configure',
      function => 'Location',
      r        => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
    })
  });

  foreach my $cs (@{$db_adaptor->get_CoordSystemAdaptor->fetch_all || []}) {
    next if $cs->name eq $slice_type;  # don't show the slice coord system twice
    next if $cs->name eq 'chromosome'; # don't allow breaking of site by exporting all chromosome features
    
    my $path;
    eval { $path = $slice->project($cs->name); };
    
    next unless $path && scalar @$path == 1;

    my $new_slice        = $path->[0]->to_Slice->seq_region_Slice;
    my $new_slice_type   = $new_slice->coord_system_name;
    my $new_slice_name   = $new_slice->seq_region_name;
    my $new_slice_length = $new_slice->seq_region_length;

    $action = $new_slice_length > $threshold ? 'Overview' : 'View';
    
    $self->add_entry({
      label => "Centre on $new_slice_type $new_slice_name",
      link  => $hub->url({
        type   => 'Location', 
        action => $action, 
        region => $new_slice_name,
        r => sprintf '%s:%s-%s', map $new_slice->$_, qw(seq_region_name start end)

      })
    });

    # would be nice if exportview could work with the region parameter, either in the referer or in the real URL
    # since it doesn't we have to explicitly calculate the locations of all regions on top level
    $top_level_slice = $new_slice->project('toplevel')->[0]->to_Slice;

    $self->add_entry({
      label      => "Export $new_slice_type sequence/features",
      link_class => 'modal_link',
      link       => $hub->url({
        type     => 'Export',
        action   => 'Configure',
        function => 'Location',
        r        => sprintf '%s:%s-%s', map $top_level_slice->$_, qw(seq_region_name start end)
      })
    });
  }

  if ($slice_type eq 'contig' &&  $slice_name !~ /^contig_/) {

    (my $short_name = $slice_name) =~ s/\.\d+$//;
    
    $self->add_entry({
      type     => 'EMBL',
      label    => $slice_name,
      link     => $hub->get_ExtURL('EMBL', $slice_name),
      external => 1
    });
      
    $self->add_entry({
      type     => 'EMBL (latest version)',
      label    => $short_name,
      link     => $hub->get_ExtURL('EMBL', $short_name),
      external => 1
    });
  }
}

1;
