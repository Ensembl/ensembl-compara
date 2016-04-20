=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
    my $tree = {1 => {}, -1 => {}};
    foreach my $strand (keys %{$content->{'features'}}) {
      foreach my $f (@{$content->{'features'}{$strand}}) {
        if (scalar @{$f->{'parents'}||[]}) {
          $self->_add_to_parent($tree->{$strand}, $f, $_) for @{$f->{'parents'}};
        }
        else {
          $tree->{$strand}{$f->{'id'}} = $f;
        }
      }
    }
    #warn Dumper($tree);

    ## Convert tree into structured features
    foreach my $strand (1, -1) {
      my @ok_features;
      while (my($id, $f) = each(%{$tree->{$strand}})) {
        ## Add to array (though we don't normally draw genes except in collapsed view)
        $f->{'href'} = $self->href($f->{'href_params'});
        push @ok_features, $self->_drawable_feature($f);

        foreach my $child_id (sort {$f->{'children'}{$a}{'start'} <=> $f->{'children'}{$b}{'start'}} keys %{$f->{'children'}||{}}) {
          my $child = $f->{'children'}{$child_id};
          ## Feature ID is inherited from parent
          my $child_href_params       = $child->{'href_params'};
          $child->{'href'}            = $self->href($child_href_params);

          if (scalar keys (%{$child->{'children'}||{}})) {
            ## Object has grandchildren - probably a transcript
            my $args = {'seen' => {}, 'no_separate_transcript' => 0};
            ## Create a new transcript from the current feature
            my %transcript = %$child;
            $transcript{'type'} = 'transcript';
            foreach my $sub_id (sort {$child->{'children'}{$a}{'start'} <=> $child->{'children'}{$b}{'start'}} keys %{$child->{'children'}||{}}) {
              my $grandchild        = $child->{'children'}{$sub_id};
              ($args, %transcript)  = $self->add_to_transcript($grandchild, $args, %transcript);  
            }
            push @ok_features, $self->_drawable_feature(\%transcript);
          }
          else {
            push @ok_features, $self->_drawable_feature($child);
          }
        }
      }
      $content->{'features'}{$strand} = \@ok_features;
    }
  }
  #warn '################# PROCESSED DATA '.Dumper($data);
}

sub _drawable_feature {
### Simplify feature hash for drawing 
### (Note that we can't delete hash keys unless we dereference the hashref first, 
### because we need the children for building the complete feature)
  my ($self, $f) = @_;
  return {
          'seq_region'    => $f->{'seq_region'},
          'start'         => $f->{'start'},
          'end'           => $f->{'end'},
          'strand'        => $f->{'strand'},
          'type'          => $f->{'type'},
          'label'         => $f->{'label'},
          'score'         => $f->{'score'},
          'colour'        => $f->{'colour'},
          'join_colour'   => $f->{'join_colour'},
          'label_colour'  => $f->{'label_colour'},
          'href'          => $f->{'href'},
          'structure'     => $f->{'structure'},
          'extra'         => $f->{'extra'},
          };
}

sub _add_to_parent {
### Recurse into feature tree
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
### @param slice - Bio::EnsEMBL::Slice object
### @param metadata - Hashref of information about this track
### @return Hashref
  my ($self, $slice, $metadata) = @_;
  return unless $slice;

  ## Start and end need to be relative to slice,
  ## as that is how the API returns coordinates
  my $feature_start = $self->parser->get_start;
  my $feature_end   = $self->parser->get_end;
  my $start         = $feature_start - $slice->start;
  my $end           = $feature_end - $slice->start;
  return if $end < 0 || $start > $slice->length;

  my $seqname       = $self->parser->get_seqname;
  my $strand        = $self->parser->get_strand || 0;
  my $score         = $self->parser->get_score;

  $metadata ||= {};
  my $feature_strand = $strand || $metadata->{'default_strand'};

  my $id    = $self->parser->get_attribute_by_name('ID');
  my $name = $self->parser->get_attribute_by_name('Name'); 
  my $alias = $self->parser->get_attribute_by_name('Alias');
  my $label;
  if ($name && $alias) {
    $label = sprintf('%s (%s)', $name, $alias);
  }
  else {
    $label = $name || $alias || $id;
  }

  ## Don't turn these into a URL yet, as we need to manipulate them later
  my $href_params = {
                      'id'          => $label,
                      'seq_region'  => $seqname,
                      'start'       => $feature_start,
                      'end'         => $feature_end,
                      'strand'      => $feature_strand,
                      };
  #use Data::Dumper; warn ">>> HREF PARAMS ".Dumper($href_params);

  my @parents = split(',', $self->parser->get_attribute_by_name('Parent'));

  my $type = $self->parser->get_type;
  my $feature = {
    'id'            => $id,
    'type'          => $type,
    'parents'       => \@parents,
    'seq_region'    => $seqname,
    'strand'        => $strand,
    'score'         => $score,
    'colour'        => $metadata->{'colour'},
    'join_colour'   => $metadata->{'join_colour'},
    'label_colour'  => $metadata->{'label_colour'},
    'label'         => $label,
    'href_params'   => $href_params,
  };

  if ($metadata->{'display'} eq 'text') {
    $feature->{'start'} = $feature_start;
    $feature->{'end'}   = $feature_end;
    $feature->{'extra'} = [
                        {'name' => 'Source',  'value' => $self->parser->get_source },
                        {'name' => 'Type',    'value' => $type },
                        ];
  }
  else {
    $feature->{'start'} = $start;
    $feature->{'end'}   = $end;
  }
  return $feature;
}


1;
