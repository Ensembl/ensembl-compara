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

package EnsEMBL::Web::Utils::UnitTest;

## Create dummy objects for use in web unit tests

use Bio::EnsEMBL::CoordSystem;
use Bio::EnsEMBL::Slice;
use EnsEMBL::Web::Tree;
use EnsEMBL::Web::Hub;
use EnsEMBL::Web::ImageConfig;

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(create_hub create_slice create_imageconfig create_trackconfig);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);


sub create_hub {
  my ($args) = @_;
  ## Prevent webcode from spewing out its progress during Hub creation
  local $SIG{__WARN__} = sub {};
  my $hub   = EnsEMBL::Web::Hub->new_for_test($args);
  ## Turn warnings back on
  local $SIG{__WARN__} = sub {
                              my $message = shift;
                              print "$message\n";
                              };
  return $hub;
}

sub create_slice {
### @param hub - EnsEMBL::Web::Hub object
### @param args - Hashref containing the following key/value pairs
###                species          - species to query
###                db               - type of database (optional)
###                cs_name          - coordinate system name
###                cs_rank          - coordinate system rank
###                assembly         - assembly name
###                seq_region_name  - name of slice
###                start            - slice start position
###                end              - slice end position
###                strand           - strand of slice
### @return Bio::EnsEMBL::Slice object
  my ($hub, $args) = @_;
  return unless ($hub && $args->{'species'} && $args->{'cs_name'} && $args->{'cs_rank'} 
                  && $args->{'assembly'} && $args->{'seq_region_name'} && $args->{'start'});

  $hub->species($args->{'species'});

  my $db = $args->{'db'} || 'core';

  my $cs = Bio::EnsEMBL::CoordSystem->new(-NAME    => $args->{'cs_name'},
                                          -VERSION => $args->{'assembly'},
                                          -RANK    => $args->{'cs_rank'},
                                          -ADAPTOR => $adaptor,
                                          ); 
  return unless $cs;
  my $slice =  Bio::EnsEMBL::Slice->new(-coord_system     => $cs,
                                        -seq_region_name  => $args->{'seq_region_name'},
                                        -start            => $args->{'start'},
                                        -end              => $args->{'end'} || $args->{'start'},
                                        -strand           => $args->{'strand'} || 1,
                                      );
  return $slice;
}

sub create_imageconfig {
### @param slice - Bio::EnsEMBL::Slice
### @param hub - EnsEMBL::Web::Hub
### @param args - Hashref containing the following key/value pairs
###                 margin      - margin for image
###                 label_width - width for labels
###                 image_width - width of test image
### @return ImageConfig object
  my ($slice, $hub, $args) = @_;
  return unless ($slice && $hub);
  $args ||= {};

  my $image_config = EnsEMBL::Web::ImageConfig->new($hub, $hub->species, $hub->type);
  return unless $image_config;

  ## Set up some sample values for our test image
  my $margin      = $args->{'margin'} || 5;
  my $label_start = $margin;
  my $label_width = $args->{'label_width'} || 100;
  my $image_width = $args->{'image_width'} || 1000;

  my $panel_start = $label_start + $label_width + $margin;
  my $panel_width = $image_width - $panel_start - $margin;
  my $x_scale     = $panel_width / $slice->length;

  $image_config->{'transform'}->{'scalex'}         = $x_scale;
  $image_config->{'transform'}->{'absolutescalex'} = 1;
  $image_config->{'transform'}->{'translatex'}     = $panel_start;
  
  return $image_config;
}

sub create_trackconfig {
### @param args - Hashref containing optional key/value pairs 
###                 (as used in ImageConfig to configure tracks) 
### @return Node object
  my $args = shift;

  ## Set some defaults
  $args->{'style'}    ||= 'normal';
  $args->{'colour'}   ||= 'black';
  $args->{'caption'}  ||= 'Test';

  my $tree = EnsEMBL::Web::Tree->new;
  return unless $tree;

  my $node = $tree->create_node('test', $args);
  return $node;
}

1;
