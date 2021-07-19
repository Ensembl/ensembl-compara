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

package EnsEMBL::Web::TextSequence::Annotation::Sequence;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::Annotation);

sub prepare_ropes {
  my ($self,$config,$slices) = @_;

  my %vtypes;
  foreach my $sl (@$slices) {
    # XXX belongsin variation
    my $aux_rope;
    if($sl->{'use_aux'} && !$sl->{'no_variations'}) {
      $aux_rope = $self->add_rope;
    }
    my $pos = 'bottom';
    $pos = 'top' if $sl->{'vtype'} and $sl->{'vtype'} eq 'snp_display';
    my $main_rope = $self->add_rope($pos);
    # XXX plain string key names are not optimal
    $main_rope->relation('aux',$aux_rope) if $aux_rope;
    $main_rope->make_root;
    # XXX belongs elsewhere
    $vtypes{$sl->{'vtype'}} = $main_rope if $sl->{'vtype'};
  }
  if($vtypes{'main'}) {
    $vtypes{'main'}->relation('protein',$vtypes{'translation'});
    $vtypes{'main'}->relation('aux',$vtypes{'snp_display'});
  }
}

sub annotate {
  my ($self,$config,$slice_data,$markup,$seq,$ph,$sequence) = @_;

    if ($config->{'match_display'}) {
      if ($slice_data->{'name'} eq $config->{'ref_slice_name'}) {
        $sequence->legacy([ map {{ letter => $_ }} @{$config->{'ref_slice_seq'}} ]);
      } else {
        my $i       = 0;
        my @cmp_seq = map {{ letter => ($config->{'ref_slice_seq'}[$i++] eq $_ ? '|' : ($config->{'ref_slice_seq'}[$i-1] eq uc($_) ? '.' : $_)) }} split '', $seq;
        while ($seq =~ m/([^~]+)/g) {
          my $reseq_length = length $1;
          my $reseq_end    = pos $seq;
              
          $markup->{'comparisons'}{$reseq_end - $_}{'resequencing'} = 1 for 1..$reseq_length;
        }     
        $sequence->legacy(\@cmp_seq); 
      }
    } else {
      my $i = 0;
      $sequence->legacy([ map { { letter => $_, match => (uc($config->{'ref_slice_seq'}[$i++]||'') eq uc($_||'')) }} split '', $seq ]);
  }
}

1;
