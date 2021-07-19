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

package EnsEMBL::Web::TmpFile::Image;

## EnsEMBL::Web::TmpFile::Image - module for dealing with temporary png images
## see base module for more information

use strict;
use Image::Size;
use EnsEMBL::Web::SpeciesDefs;
use base 'EnsEMBL::Web::TmpFile';

## Some extra accessors specific for png images
__PACKAGE__->mk_accessors(qw(height width size mtime));

sub new {
  my $class = shift;
  my %args  = @_;
  
  my $species_defs = delete $args{species_defs} || EnsEMBL::Web::SpeciesDefs->new();
  my $self = $class->SUPER::new(
    species_defs => $species_defs,
    extension    => 'png',
    tmp_dir      => $species_defs->ENSEMBL_TMP_DIR_IMG,
    URL_root     => $species_defs->ENSEMBL_STATIC_SERVER . $species_defs->ENSEMBL_TMP_URL_IMG,
    %args,
  );

  return $self;
}

sub content {
  my $self = shift; 

  if (@_ && defined $_[0]) {
    my ($x, $y, $z) = Image::Size::imgsize(\$_[0]);
      die "imgsize failed: $z" unless defined $x;
    $self->width($x);
    $self->height($y);
    $self->size(length($_[0]));
    $self->mtime(time);
  }

  return $self->SUPER::content(@_);
}

sub save {
  my $self    = shift;
  my $content = $self->content(shift);
  my $params  = shift || {};

  $params = {
    %$params,
    width  => $self->width,
    height => $self->height,
    size   => length($content),
    mtime  => time,
  };

  return $self->SUPER::save(undef, $params);
}

1;
