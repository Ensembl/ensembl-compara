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

package EnsEMBL::Web::Component::Info::ExpressionTable;

use strict;

use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $html;
  my %glossary = $hub->species_defs->multiX('ENSEMBL_GLOSSARY');
  my $common   = $hub->species_defs->SPECIES_COMMON_NAME;

  $html .= "<p>$common gene expression data is available for the following tissues:</p>";

  my @track_order = ('rnaseq', 'dna_align', 'data_file'); 
  my $columns = [
    { key => 'tissue',    'title' => 'Tissue',                align => 'left', width => '10%'},
    { key => 'all',       'title' => 'All data',              align => 'center', width => '15%'},
    { key => 'rnaseq',    'title' => 'RNASeq gene models',    align => 'center', width => '25%',
      help => $glossary{'RNASeq gene models'}},
    { key => 'dna_align', 'title' => 'Intron-spanning reads', align => 'center', width => '25%',
      help => $glossary{'Intron-spanning reads'}},
    { key => 'data_file', 'title' => 'RNASeq alignments',     align => 'center', width => '25%',
      help => $glossary{'RNASeq gene alignments'}},
  ];

  my $rows = [];
  my $previous;

  my $rnaseq_tracks = [];
  my $rnaseq_db = $self->hub->database('rnaseq');
  if ($rnaseq_db) {
    my $aa = $self->hub->get_adaptor('get_AnalysisAdaptor', 'rnaseq');
    $rnaseq_tracks = [ grep { $_->displayable } @{$aa->fetch_all} ];
  }

  ## Munge the data first, or the logic becomes hideous!
  my $track_info = {};
  my $tissue_order = [];
  foreach my $track (sort {lc($a->display_label) cmp lc($b->display_label)} @$rnaseq_tracks) {
    my $tissue = ucfirst($track->display_label);
    $tissue =~ s/ rna(-*)seq//i;

    my $key = $tissue =~ /alignments/ ? 'data_file' : 
                $tissue =~ 'intron' ? 'dna_align' : 'rnaseq';
    my $config = $key.'_rnaseq_'.$track->logic_name.'=default';
    ## Clean up tissue name, as it's not currently stored independently of track type
    $tissue =~ s/ (alignments|intron-spanning reads|introns|species proteins)//;
    # Add option_key for regulation matrix cell
    my $webdata = $track->web_data();
    if($webdata and $webdata->{'matrix'}) {
      my $m = $webdata->{'matrix'};
      my $cell = "$m->{'menu'}_$m->{'column'}_$m->{'row'}";
      $config .= ",$cell=on";
    }

    $track_info->{$tissue}{$key} = [$config, $track->description];

    if ($tissue ne $previous) {
      push @$tissue_order, $tissue;
    }
    $previous = $tissue;
  }
  
  ## Now build the rows
  foreach my $tissue (@$tissue_order) {
    my $data = $track_info->{$tissue};
    my $row = {'tissue' => $tissue};
    my @configs = ();

    foreach (@track_order) {
      my $track = $track_info->{$tissue}{$_};
      if ($track) {
        push @configs, $track->[0];
        my $desc = $_ eq 'rnaseq' ? $track->[1] 
                    : sprintf('<span class="_ht" title="%s">Y</span>', $self->strip_HTML($track->[1]));
        $row->{$_} = $desc;
      }
      else {
        $row->{$_} = '-';
      }
    }

    my $url = $hub->url({
                            'type'    => 'Location',
                            'action'  => 'View',
                            'r'       => $hub->species_defs->SAMPLE_DATA->{'LOCATION_PARAM'},
                            'contigviewbottom' => join(',', @configs)});
    $row->{'all'} = sprintf('<a href="%s">View in example location</a>', $url);
    push @$rows, $row;            
  }
 
  my $table = EnsEMBL::Web::Document::Table->new($columns, $rows, {});
  $html .= $table->render;

  return $html;
}

1;
