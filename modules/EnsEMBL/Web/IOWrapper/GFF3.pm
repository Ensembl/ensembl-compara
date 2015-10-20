=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::IOWrapper::GFF3;

### Wrapper for Bio::EnsEMBL::IO::Parser::GFF3, which builds
### simple hash features suitable for use in the drawing code 

use strict;
use warnings;
no warnings 'uninitialized';

use Data::Dumper;

use parent qw(EnsEMBL::Web::IOWrapper::GXF);

sub post_process {
### Reassemble sub-features back into features
  my ($self, $data) = @_;
  #warn '>>> ORIGINAL DATA '.Dumper($data);

  while (my ($track_key, $content) = each (%$data)) {
    ## Build a tree of features
    my $tree = {};
    foreach my $f (@{$content->{'features'}}) {
      if (scalar @{$f->{'parents'}||[]}) {
        $self->_add_to_parent($tree, $f, $_) for @{$f->{'parents'}};
      }
      else {
        $tree->{$f->{'id'}} = $f;
      }
    }
    #warn Dumper($tree);

    ## Convert tree into structured features
    my @ok_features;
    while (my($id, $f) = each(%$tree)) {
      ## Add to array (though we don't normally draw genes except in collapsed view)
      push @ok_features, $f;

      foreach my $id (keys %{$f->{'children'}||{}}) {
        my $child = $f->{'children'}{$id};
        if (scalar keys (%{$child->{'children'}||{}})) {
          ## Object has grandchildren - probably a transcript
          my $args = {'seen' => {}, 'no_separate_transcript' => 0};
          ## Create a new transcript from the current feature
          my %transcript = %$child;
          foreach my $sub_id (keys %{$child->{'children'}||{}}) {
            my $grandchild = $child->{'children'}{$sub_id};
            ($args, %transcript) = $self->add_to_transcript($grandchild, $args, %transcript);  
          }
          push @ok_features, \%transcript;
        }
        else {
          push @ok_features, $child;
        }
      }
    }
    $content->{'features'} = \@ok_features;
  }
  #warn '################# PROCESSED DATA '.Dumper($data);
}

sub _add_to_parent {
  my ($self, $node, $feature, $parent) = @_;
  ## Is this a child of the current level?
  if ($node->{$parent}) {
    $node->{$parent}{'children'}{$feature->{'id'}} = $feature;
    return;
  }
  else {
    while (my($k, $v) = each(%$node)) {
      next unless $k && ref $v eq 'HASH';
      $self->_add_to_parent($v, $feature, $parent);
    }
  }
}


sub create_hash {
### Create a hash of feature information in a format that
### can be used by the drawing code
### @param metadata - Hashref of information about this track
### @param slice - Bio::EnsEMBL::Slice object
### @return Hashref
  my ($self, $metadata, $slice) = @_;
  $metadata ||= {};
  return unless $slice;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $seqname       = $self->parser->get_seqname;
  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $strand        = $self->parser->get_strand;
  my $score         = $self->parser->get_score;

  my $id    = $self->parser->get_attribute_by_name('ID');
  my $label = $self->parser->get_attribute_by_name('Name') || $id; 
  my $alias = $self->parser->get_attribute_by_name('Alias');
  $label .= sprintf(' (%s)', $alias) if $alias; 

  my $href = $self->href({
                        'id'          => $id,
                        'seq_region'  => $seqname,
                        'start'       => $feature_start,
                        'end'         => $feature_end,
                        });

  my @parents = split(',', $self->parser->get_attribute_by_name('Parent'));

  return {
    'id'            => $id,
    'type'          => $self->parser->get_type,
    'parents'       => \@parents,
    'start'         => $feature_start - $slice->start,
    'end'           => $feature_end - $slice->start,
    'seq_region'    => $seqname,
    'strand'        => $strand,
    'score'         => $score,
    'label'         => $label,
    'href'          => $href,
  };
}


1;
