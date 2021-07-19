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

package EnsEMBL::Draw::GlyphSet::fg_segmentation_features;

### Draw regulatory segmentation features track (semi-continuous
### track of colour blocks)

use strict;

use EnsEMBL::Web::File::Utils::IO qw(file_exists);

use base qw(EnsEMBL::Draw::GlyphSet::bigbed);

sub get_data {
  my $self    = shift;
  my $slice   = $self->{'container'};
  my $db_type = $self->my_config('db_type') || 'funcgen';
  my $fg_db;

  if (!$slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    $fg_db = $slice->adaptor->db->get_db_adaptor($db_type);

    if(!$fg_db) {
      warn "Cannot connect to $db_type db";
      return [];
    }
  }

  my $f = $self->fetch_features_from_file($fg_db) || [];
  return $f; 
}

sub fetch_features_from_file {
  my ($self,$fgh) = @_;

  my $slice   = $self->{'container'};
  my $db_type = $self->my_config('db_type') || 'funcgen';
  return undef if $slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice');

  my $seg_name = $self->my_config('seg_name');
  return undef unless $seg_name;

  my $sfa = $self->{'config'}->hub->get_adaptor('get_SegmentationFileAdaptor', $db_type);
  my $seg = $sfa->fetch_by_name($seg_name);
  return undef unless $seg;

  ## Set zmenu options before we parse the file
  $self->{'my_config'}->set('zmenu_action', 'SegFeature');
  $self->{'my_config'}->set('zmenu_extras', {
                                              'celltype'  => $self->my_config('section'),
                                              'seg_name'  => $self->my_config('seg_name'),
                                            });

  my $bigbed_file = $seg->file;
  my $file_path = join('/',$self->species_defs->DATAFILE_BASE_PATH,
                           lc $self->species,
                           $self->species_defs->ASSEMBLY_VERSION);
  $bigbed_file = "$file_path/$bigbed_file" unless $bigbed_file =~ /^$file_path/;
  $bigbed_file =~ s/\s//g;

  my $out = $self->SUPER::get_data($bigbed_file);

  ## Create legend
  my $legend_entries = $self->{'legend'}{'fg_segmentation_features_legend'}{'entries'};
  foreach (@$out) {
    foreach my $f (@{$_->{'features'}||[]}) {
      $f->{'label'} =~ /_(\w+)_/;
      my $colour_key = $1;
      push @$legend_entries, [$colour_key, $f->{'colour'}];
    }
  }
  $self->{'legend'}{'fg_segmentation_features_legend'} = { priority => 1020, legend => [], entries => $legend_entries };

  return $out;
}

sub href { return undef; }

sub bg_link { return undef;}

sub colour_key {
  my ($self, $f) = @_;
  my $type = $f->feature_type->name;

  if ($type =~ /Repressed/ or $type =~ /low activity/) {
    $type = 'repressed';
  } elsif ($type =~ /CTCF/) {
    $type = 'ctcf';
  } elsif ($type =~ /Enhancer/) {
    $type = 'enhancer';
  } elsif ($type =~ /Flank/) {
    $type = 'promoter_flanking';
  } elsif ($type =~ /TSS/) {
    $type = 'promoter';
  } elsif ($type =~ /Transcribed/) {
    $type = 'region';
  } elsif ($type =~ /Weak/) {
    $type = 'weak';
  } elsif ($type =~ /Heterochr?omatin/i) { # ? = typo in e76
    $type = 'heterochromatin';
  } else {
    $type = 'default';
  }
  return lc $type;
}

=pod
sub colour_key {
  my ($self, $f) = @_;
  my $type = $f->feature_type->name;

  my $lookup = $self->colour_key_lookup;

  my $match = grep { $type =~ /$_/ } keys %$lookup;
  return $match ? lc $lookup->{$match} : 'default';
}

sub colour_key_lookup {
  return {
    'Repressed'       => 'repressed',
    'low activity'    => 'repressed', 
    'CTCF'            => 'ctcf',
    'Enhancer'        => 'enhancer',
    'Flank'           => 'promoter_flanking',
    'TSS'             => 'promoter',
    'Transcribed'     => 'region',
    'Weak'            => 'weak',
    'Heterochromatin' => 'heterochromatin',       
  };
} 
=cut

sub render {
  my ($self) = @_;

  $self->{'my_config'}->set('link_on_bgd', 1);
  $self->render_compact;
}

1;
