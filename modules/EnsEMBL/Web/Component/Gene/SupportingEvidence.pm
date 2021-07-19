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

package EnsEMBL::Web::Component::Gene::SupportingEvidence;

### Displays supporting evidence for all transcripts of a gene

use strict;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $object     = $self->object;
  my $logic_name = $object->logic_name;
  my $evidence   = $object->get_gene_supporting_evidence;
  my $db         = $self->object->get_db;

  if (!$evidence) {
    my $html = '<dt>No Evidence</dt><dd>';
    
    if ($logic_name =~ /otter/) {
      $html .= q{
        <p>Although this Vega gene has been manually annotated and it's structure is supported by experimental evidence, this evidence is currently missing from the database. 
        We are adding the evidence back to the database as time permits</p>
      };
    } else {
      $html .= '<p>No supporting evidence available for this gene</p>';
    }
    
    return $html;
  }
  
  my @rows;
  my @cols = (
    { key => 'transcript', title => 'Transcript',               sort => 'html'    },
    { key => 'CDS',        title => 'CDS support',              sort => 'html'    },
    { key => 'UTR',        title => 'UTR support',              sort => 'html'    },
    { key => 'UNKNOWN',    title => 'Other transcript support', sort => 'html'    },
    { key => 'exon',       title => 'Exon supporting features', sort => 'numeric' }
  );
  
  # label and space columns - number of these depends on the data
  # don't mention exon evidence for Vega
  if ($logic_name !~ /otter/) {
    splice @cols, 3, 1 unless grep { $evidence->{$_}{'evidence'} && $evidence->{$_}{'evidence'}->{'UNKNOWN'} } keys %$evidence; # remove Other transcript support column;
  } else {
    pop @cols; # remove Exon support column;
  }
  
  if ($db eq 'rnaseq') {
    @cols = (
      { key => 'transcript', title => 'Transcript',               sort => 'html'    },
      { key => 'CDS',        title => 'CDS support',              sort => 'html'    },
      { key => 'intron',     title => 'Intron Support',           sort => 'html'    },
    );
  }
  my $width = (100 / scalar @cols) . '%';
  $_->{'width'} = $width for @cols;
  
  foreach my $transcript (keys %$evidence) {
    my $ev = $evidence->{$transcript}{'evidence'};
    my $has_ev = ($ev || $evidence->{$transcript}{'extra_evidence'}) ? 1 : 0;
    my %url_params = (
      type   => 'Transcript',
      action => 'SupportingEvidence',
      t      => $transcript
    );
    my $row = $has_ev ? { transcript => sprintf('%s [<a href="%s">view evidence</a>]', $evidence->{$transcript}{version} ? $transcript . "." . $evidence->{$transcript}{version}: $transcript, $hub->url(\%url_params)) } : { transcript => $transcript };
    $row->{'exon'} = scalar keys %{$evidence->{$transcript}{'extra_evidence'}} if $evidence->{$transcript}{'extra_evidence'};
    $row->{'intron'} = scalar @{$evidence->{$transcript}{'intron_supporting_evidence'}} if $evidence->{$transcript}{'intron_supporting_evidence'};

    $url_params{'function'} = 'Alignment';

    if ($ev) {
      foreach my $type (grep $ev->{$_}, qw(CDS UTR UNKNOWN)) {
        $row->{$type} .= sprintf '<p>[<a href="%s">align</a>] %s</p>', $hub->url({ %url_params, sequence => $_->[1] }), $_->[0] for @{$object->add_evidence_links($ev->{$type})};
      }
    }

    push @rows, $row;
  }

  return $self->new_table(\@cols, \@rows, { data_table => 1, sorting => [ 'transcript asc' ] })->render;
}

1;
