package EnsEMBL::Web::Component::Gene::ExpressionTable;

use strict;

use EnsEMBL::Web::Document::Table;

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $html;
  my %glossary = $self->hub->species_defs->multiX('ENSEMBL_GLOSSARY');

  $html .= '<p>Expression data is available for the following tissues:</p>';

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

  my $rnaseq_tracks = $self->object->get_rnaseq_tracks;

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

    my $url = $hub->url({'type'=>'Location','action'=>'View', 'contigviewbottom' => join(',', @configs)});
    $row->{'all'} = sprintf('<a href="%s">View in location</a>', $url);
    push @$rows, $row;            
  }
 
  my $table = EnsEMBL::Web::Document::Table->new($columns, $rows, {});
  $html .= $table->render;

  return $html;
}

1;
