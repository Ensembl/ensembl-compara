=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::SequenceAlignment;

use strict;

use Bio::EnsEMBL::MappedSliceContainer;
use Bio::EnsEMBL::Variation::DBSQL::StrainSliceAdaptor;
use EnsEMBL::Web::TextSequence::View::SequenceAlignment;

use base qw(EnsEMBL::Web::Component::TextSequence EnsEMBL::Web::Component::Location);

sub content_key { return shift->SUPER::content_key({ resequencing => 1 }); }

sub content {
  my $self      = shift;
  my $object    = $self->object;
  my $threshold = 50001;
  
  return $self->_warning('Region too large', '<p>The region selected is too large to display in this view - use the navigation above to zoom in...</p>') if $object->length > $threshold;
  
  my $hub            = $self->hub;
  my $species_defs   = $hub->species_defs;
  my $original_slice = $object->slice;
     $original_slice = $original_slice->invert if $hub->param('strand') == -1;
  my $ref_slice      = $self->new_object('Slice', $original_slice, $object->__data); # Get reference slice
  my $var_db         = $species_defs->databases->{'DATABASE_VARIATION'};
  my $strain         = $species_defs->STRAIN_TYPE || 'strain';
  my (@samples, $html);

  my $config = {
    display_width  => $hub->param('display_width') || 60,
    site_type      => ucfirst(lc $species_defs->ENSEMBL_SITETYPE) || 'Ensembl',
    species        => $hub->species,
    comparison     => 1,
    resequencing   => 1,
    ref_slice_name => $ref_slice->get_samples('reference')
  };
  
  foreach (qw(exon_ori match_display snp_display line_numbering codons_display title_display)) {
    $config->{$_} = $hub->param($_) unless $hub->param($_) eq 'off';
  }
  my $adorn = $hub->param('adorn') || 'none';
 
  # FIXME: Nasty hack to allow the parameter to be defined, but false. Used when getting variations.
  # Can be deleted once we get the correct set of variations from the API 
  # (there are currently variations returned when the resequenced samples match the reference)
  $config->{'match_display'} ||= 0;  
  $config->{'exon_display'}    = 'selected' if $config->{'exon_ori'};
  $config->{'number'} = 1 if $config->{'line_numbering'};
  
  foreach (qw(DEFAULT_STRAINS DISPLAY_STRAINS)) {
    foreach my $sample (@{$var_db->{$_}}) {
      push @samples, $sample if $hub->param($sample) eq 'on';
    }
  }
  
  if (scalar @samples) {
    $config->{'slices'} = $self->get_slices($ref_slice->Obj, \@samples, $config);
    
    my ($sequence, $markup) = $self->get_sequence_data($config->{'slices'}, $config, $adorn);
    
    my $view = $self->view;
    my @s2 = @{$view->sequences};
    foreach my $slice (@{$config->{'slices'}}) {
      my $seq = shift @s2;
      $seq->name($slice->{'display_name'} || $slice->{'name'});
    }

    $self->view->markup($sequence,$markup,$config);

    my $slice_name = $original_slice->name;
    
    my (undef, undef, $region, $start, $end) = split ':', $slice_name;
    my $url = $hub->url({ action => 'View', r => "$region:$start-$end" });

    $self->view->output->template(qq(<p><b>$config->{'species'}</b>&nbsp;&gt;&nbsp;<a href="$url">$slice_name</a></p><pre>%s</pre>));
    
    $html  = $self->build_sequence($sequence, $config);
    $html .= $self->_hint(
      'strain_config', 
      ucfirst "$strain configuration",
      qq(<p>You can choose which ${strain}s to display from the "<b>Resequenced ${strain}s</b>" section of the configuration panel, accessible via the "<b>Configure this page</b>" link to the left.</p>)
    );
  } else {
    $strain .= 's';
    
    if ($ref_slice->get_samples('reseq')) {
      $html = $self->_info(
        "No $strain specified", 
        qq(<p>Please select $strain to display from the "<b>Resequenced $strain</b>" section of the configuration panel, accessible via "<b>Configure this page</b>" link to the left.</p>)
      );
    } else {
      $html = $self->_warning("No $strain available", "<p>No resequenced $strain available for this species</p>");
    }
  }
  
  my $view = $self->view($config);
  $view->legend->expect('variants') if ($config->{'snp_display'}||'off') ne 'off';
  $html = $self->describe_filter($config).$html;
  return $html;
}

sub get_slices {
  my ($self, $ref_slice_obj, $samples, $config) = @_;
  my $hub = $self->hub;
  my $vdb = $hub->database('variation');
  # Chunked request
  if (!defined $samples) {
    my $var_db = $hub->species_defs->databases->{'DATABASE_VARIATION'};
    
    foreach (qw(DEFAULT_STRAINS DISPLAY_STRAINS DISPLAYBLE)) {
      foreach my $sample (@{$var_db->{$_}}) {
        push @$samples, $sample if $hub->param($sample) eq 'on';
      }
    }
  }
  
  my $msc = Bio::EnsEMBL::MappedSliceContainer->new(-SLICE => $ref_slice_obj, -EXPANDED => 1);
  
  $msc->set_StrainSliceAdaptor(Bio::EnsEMBL::Variation::DBSQL::StrainSliceAdaptor->new($vdb));

  $msc->attach_StrainSlice($_) for @$samples;
  
  my @slices = ({ 
    name  => $config->{'ref_slice_name'},
    slice => $ref_slice_obj
  });
  
  foreach (@{$msc->get_all_MappedSlices}) {
    my $slice = $_->get_all_Slice_Mapper_pairs->[0][0];
    
    push @slices, { 
      name  => $slice->can('display_Slice_name') ? $slice->display_Slice_name : $config->{'species'}, 
      slice => $slice,
      seq   => $_->seq(1)
    };
  }
  
  $config->{'ref_slice_start'} = $ref_slice_obj->start;
  $config->{'ref_slice_end'}   = $ref_slice_obj->end;
  $config->{'ref_slice_seq'}   = [ split '', $msc->seq(1) ];
  $config->{'mapper'}          = $msc->mapper;
  
  return \@slices;
}

sub make_view {
  my ($self) = @_;

  return EnsEMBL::Web::TextSequence::View::SequenceAlignment->new(
    $self->hub
  );
}

1;
