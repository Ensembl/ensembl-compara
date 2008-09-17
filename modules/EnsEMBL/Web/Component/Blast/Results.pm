package EnsEMBL::Web::Component::Blast::Results;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Blast);
use CGI qw(escapeHTML);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  my $self = shift;
  my $object = $self->object;

  my $sitename = $object->species_defs->ENSEMBL_SITETYPE;

  my $html = qq(<h2>$sitename Blast Results</h2>);

  my $ticket = $object->param('ticket');
  my $blast = $object->retrieve_ticket($ticket);

  my $run_id = ($object->param('run_id'));
  if ($run_id) {
    my $run_token = $blast->workdir."/".$run_id;
    my( $runnable )= $blast->runnables_like( -token=>$run_token );

    ## Create sorted alignment [$hit,$hsp] from top NN scoring HSPs
    my $alignments = [];
    my $result  = $runnable->result;
    my $species = $result->database_species;
    my $sortby = $object->param('view_sortby') || 'score';

    my $num_aligns = $object->param('view_numaligns') || 100;
    my $max_aligns  = 10000;
    my $tot_aligns = 0;
    map{ $tot_aligns += $_->num_hsps } $result->hits;
    if ( $num_aligns > $max_aligns ) { 
      $num_aligns = $max_aligns if $num_aligns > $max_aligns;
      $num_aligns = $tot_aligns if $num_aligns > $tot_aligns;
    }

    foreach my $hit( $result->hits ){
      push @$alignments, map{ [$hit,$_] } $hit->hsps;
    }
    @$alignments = ( sort{ $b->[1]->$sortby <=> $a->[1]->$sortby }
                         @$alignments )[0..$num_aligns-1];

    ## Display alignments in various ways!

    ## Summary
    (my $species_name = $species) =~ s/_/ /g;
    $html .= "<h3>Displaying unnamed sequence alignments vs $species_name LATESTGP database</h3>";

    ## Karyotype (if available)
    $html .= "<h3>Alignment location vs karyotype</h3>";
    if ($object->species_defs->get_config($species, 'ENSEMBL_CHROMOSOMES')) {
      $html .= draw_karyotype($object, $alignments);;
    }
    else {
      $html .= '<p>Sorry, this species has not been assembled into chromosomes</p>';
    }

    ## Alignment image
    $html .= "<h3>Alignment locations vs query</h3>";
    $html .= draw_alignment($object, $blast);;

    ## Alignment table
    $html .= "<h3>Alignment summary</h3>";
    $html .= display_alignment_table($object, $blast);;
  }
  else {
    $html .= '<p>No run IDs found</p>';  
  }
  return $html;
}

sub draw_karyotype {
  my ($object, $aligns) = @_;

  my $config_name = 'Vkaryotype';
  my $config = $object->get_userconfig($config_name);
  my $image    = $object->new_karyotype_image();

  my $alignments = [];
  @$alignments = ( grep{ $_->[1]->can( 'genomic_hit' ) && $_->[1]->genomic_hit } @$aligns );
  if( ! @$alignments ){ return "No HSPs for result!" }

  ## Create highlights - arrows and outline box
  my %highlights1 = ('style' => 'rharrow');
  my %highlights2 = ('style' => 'outbox');

  my @colours = qw( gold orange chocolate firebrick darkred );

  # Create per-hit glyphs
  my @glyphs;
  my $first=1;
  foreach( @$alignments ){
    my( $hit, $hsp ) = @{$_};
    my $gh        = $hsp->genomic_hit;
    my $chr       = $gh->seq_region_name;
    my $chr_start = $gh->seq_region_start;
    my $chr_end   = $gh->seq_region_end;
    my $caption   = "Alignment vs ". $hsp->hit->seq_id;
    my $score     = $hsp->score;
    my $pct_id    = $hsp->percent_identity;
    my $colour_id = int( ($pct_id-1)/20 );
    my $colour    = @colours[ $colour_id ];

    $highlights1{$chr} ||= [];
    push( @{$highlights1{$chr}}, $config );

    if( $first ){
      $first = 0;
      $highlights2{$chr} ||= [];
      push ( @{$highlights2{$chr}}, { start => $chr_start,
                                      end   => $chr_end,
                                      score => $score,
                                      col   => $colour } );
    }

  }

  $image->image_name = "blast";
  $image->imagemap = 'yes';
  my $pointers = [\%highlights1, \%highlights2];
  $image->karyotype( $object, $pointers, $config_name );

  return $image->render;
}

sub draw_alignment {
  my ($object, $blast) = @_;
  return "<p>ALIGNMENT IMAGE GOES HERE</p>";
}

sub display_alignment_table {
  my ($object, $blast) = @_;
  return "<p>ALIGNMENT TABLE GOES HERE</p>";
}

1;
