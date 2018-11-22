=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::fg_motif_features;

### Draw regulatory motif features track 

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::bigbed);

sub get_data {
  my $self    = shift;
  my $slice   = $self->{'container'};
  return [] if $slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice');

  my $db_type = $self->my_config('db_type') || 'funcgen';
  my $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);

  if(!$fg_db) {
    warn "Cannot connect to $db_type db";
    return [];
  }

  ## Force features onto reverse strand
  $self->{'my_config'}->set('strand', 'r');

  my $db_type = $self->my_config('db_type') || 'funcgen';
  my $mfa = $self->{'config'}->hub->get_adaptor('get_MotifFeatureFileAdaptor', $db_type);

  ## Set zmenu options before we parse the file
  $self->{'my_config'}->set('zmenu_action', 'MotifFeature');
  ## FIXME - there is a typo in one of the bigBed AutoSQL column names!
  $self->{'my_config'}->set('custom_fields', [qw(binding_matrix_stable_id transcriprion_factors epigenomes)]);

  my $bigbed_file = $mfa->fetch_file;
  my $file_path = join('/',$self->species_defs->DATAFILE_BASE_PATH,
                           lc $self->species,
                           $self->species_defs->ASSEMBLY_VERSION,
                           $bigbed_file->path);
  $file_path =~ s/\s//g;

  my $out = $self->SUPER::get_data($file_path) || [];

=pod
  ## Create legend
  my $legend_entries = $self->{'legend'}{'fg_motif_features_legend'}{'entries'};
  foreach (@$out) {
    foreach my $f (@{$_->{'features'}||[]}) {
      $f->{'label'} =~ /_(\w+)_/;
      my $colour_key = $1;
      push @$legend_entries, [$colour_key, $f->{'colour'}];
    }
  }
  $self->{'legend'}{'fg_motif_features_legend'} = { priority => 1020, legend => [], entries => $legend_entries };
=cut

  return $out;
}

sub href { return undef; }

sub bg_link { return undef;}

sub colour_key {
  my ($self, $f) = @_;
  my $type; 

}

sub render {
  my ($self) = @_;

  $self->{'my_config'}->set('link_on_bgd', 1);
  $self->render_compact;
}

1;
