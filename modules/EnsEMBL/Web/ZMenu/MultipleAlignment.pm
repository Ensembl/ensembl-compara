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

package EnsEMBL::Web::ZMenu::MultipleAlignment;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $id          = $hub->param('id');
  my $object_type = $hub->param('ftype');
  my $align       = $hub->param('align');
  my $caption     = $hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$align}{'name'};
  my $region      = $hub->param('r');  #Current location of region
  my $block       = $hub->param('n0'); #Location of the block on 'this' species
  my $sp          = $hub->species;     #Name of 'this' species

  my $url = $hub->url({
    type   => 'Location',
    action => 'Compara_Alignments',
    align  => "$align--$sp"
  });

  my ($block_chr, $block_start, $block_end) = split /[:-]/, $block;
  my ($chr, $start, $end) = split /[:-]/, $region;
  
  
  my ($p_value, $score);

  # if there's a score than show it and also change the name of the track (hacky)
  if ($object_type && $id &&$object_type eq 'ConstrainedElement' ) {
    my $db_adaptor   = $hub->database('compara');
    my $adaptor_name = "get_${object_type}Adaptor";
    my $feat_adap    = $db_adaptor->$adaptor_name;
    my $feature      = $feat_adap->fetch_by_dbID($id);
    
    $p_value = $feature->p_value if ($feature->p_value);
      
    $score = $feature->score if ($feature->score);
      
    $caption = "Constrained el. $1 way" if $caption =~ /^(\d+)/;
    $self->create_subheader_menu($caption, $start, $end, $url, $p_value, $score);
  }

  #Add "This region" subheader for GenomicAlignBlocks (not Constrained Elements) if the region
  #is not the same as the block
  if ($object_type eq 'GenomicAlignBlock' && $start != $block_start || $end != $block_end) {
      $self->add_subheader("This region:");
      $self->caption($caption);
      $self->create_subheader_menu($caption, $start, $end, $url);
  } 

  if ($object_type eq 'GenomicAlignBlock') {
      $self->add_subheader("This block:");
      $self->caption($caption);

      my $url = $hub->url({
                           type   => 'Location',
                           action => 'Compara_Alignments',
                           align  => "$align--$sp",
                           r      => $block
                          });

      $self->create_subheader_menu($caption, $block_start, $block_end, $url);
  }
}

sub create_subheader_menu {
  my ($self, $caption, $start, $end, $url, $p_value, $score) = @_;

  $self->caption($caption);

  if ($p_value) {
      $self->add_entry({
        type  => 'p-value',
        label => sprintf('%.2e', $p_value)
      });
  }
  if ($score) {
      $self->add_entry({
        type  => 'Score',
        label => sprintf('%.2f', $score)
      });
  }

  $self->add_entry({
    type  => 'start',
    label => $start
  });
  
  $self->add_entry({
    type  => 'end',
    label => $end
  });
  
  $self->add_entry({
    type  => 'length',
    label => ($end - $start + 1) . ' bp'
  });
  
  $self->add_entry({
    label => 'View alignments (text)',
    link  => $url
  });
  
  $url =~ s/Compara_Alignments/Compara_Alignments\/Image/;
  
  $self->add_entry({
    label => 'View alignments (image)',
    link  => $url
  });
}

1;
