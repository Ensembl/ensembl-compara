# $Id$

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
  
  my $width = (100 / scalar @cols) . '%';
  $_->{'width'} = $width for @cols;
  
  foreach my $transcript (keys %$evidence) {
    my $ev = $evidence->{$transcript}{'evidence'};
    
    my %url_params = (
      type   => 'Transcript',
      action => 'SupportingEvidence',
      t      => $transcript
    );
    
    my $row = { transcript => sprintf('%s [<a href="%s">view evidence</a>]', $transcript, $hub->url(\%url_params)) };
    $row->{'exon'} = scalar keys %{$evidence->{$transcript}{'extra_evidence'}} if $evidence->{$transcript}{'extra_evidence'};
    
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
