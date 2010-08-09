#$Id$
package EnsEMBL::Web::Configuration::LRG;

use strict;

use base qw( EnsEMBL::Web::Configuration );

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub configurator   { return $_[0]->_configurator;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Genome';
}

sub short_caption {
  my $self = shift;
  return 'LRG-based displays';
}

sub caption           {
  my $self = shift;
  my $caption;
=pod
  my( $disp_id ) = $self->object->display_xref;
  my $caption = $self->object->type_name.': ';
  if( $disp_id ) {
    $caption .= "$disp_id (".$self->object->stable_id.")";
  } else {
    $caption .= $self->object->stable_id;
  }
=cut
  if ($self->hub->param('lrg')) {
    $caption = 'LRG: '.$self->hub->param('lrg'); 
  }
  else {
    $caption = 'LRGs';
  }
  return $caption;
}

sub availability {
  my $self = shift;
  my $hash = $self->get_availability;
  $hash->{'lrg'} = $self->object ? 1 : 0;

  my $lrg = $self->object;
  if ($lrg) {
    my $rows = $lrg->table_info( $lrg->get_db, 'stable_id_event' )->{'rows'};
    $hash->{'either'}   = 1;
    $hash->{'core'}     = $lrg->get_db eq 'core' ? 1 : 0;
    my $funcgen_db = $lrg->get_db('funcgen');
    my $funcgen_res = 0;
    if ($funcgen_db){
     $funcgen_res = $lrg->table_info('funcgen', 'feature_set' )->{'rows'} ? 1 : 0;
    }
    $hash->{'regulation'} = $funcgen_res ? 1 : 0;
  }
  return $hash;
}

sub counts {
  my $self = shift;
  my $hub = $self->hub;
  my $obj = $self->model->api_object('Gene');

  return {} unless $obj;

  my $key = '::COUNTS::GENE::'.$hub->species.'::'.$hub->param('db').'::'.$hub->param('lrg').'::';
  my $counts = $hub->cache ? $hub->cache->get($key) : undef;

  if (!$counts) {
    $counts = {
      transcripts   => scalar @{$self->model->api_object('Transcript')},
      genes         => 1,
    };

    $hub->cache->set($key, $counts, undef, 'COUNTS') if $hub->cache;
  }
 
  return $counts;
}


sub populate_tree {
  my $self = shift;

  ## HACK THE AVAILABILITY, BECAUSE WE ARE MIXING OBJECT TYPES
  my $has_lrg = $self->object ? 1 : 0;

  $self->create_node('Genome', 'All LRGs',
    [qw(
      karyotype EnsEMBL::Web::Component::LRG::Genome 
    )],
    { 'availability' => 1 }
  );

  $self->create_node('Summary', 'LRG summary',
    [qw(
      summary     EnsEMBL::Web::Component::LRG::LRGSummary
      transcripts EnsEMBL::Web::Component::LRG::TranscriptsImage  
    )],
    { 'availability' => $has_lrg }
  );

  $self->create_node('Sequence', 'Sequence',
    [qw( exons EnsEMBL::Web::Component::LRG::LRGSeq )],
    { 'availability' => $has_lrg}
  );

  $self->create_node('Differences', 'Reference comparison',
    [qw( exons EnsEMBL::Web::Component::LRG::LRGDiff )],
    { 'availability' => $has_lrg}
  );
 
  my $var_menu = $self->create_submenu('Variation', 'Genetic Variation');

  $var_menu->append($self->create_node('Variation_LRG/Table', 'Variation Table',
    [qw( snptable EnsEMBL::Web::Component::LRG::LRGSNPTable )],
    { 'availability' => $has_lrg }
  ));

  $var_menu->append($self->create_node('Variation_LRG/Image',  'Variation Image',
    [qw( image EnsEMBL::Web::Component::LRG::LRGSNPImage )],
    #{ 'availability' => $has_lrg }
    { 'availability' => 0 }
  ));

  # External Data tree, including non-positional DAS sources
  #my $external = $self->create_node('ExternalData', 'External Data',
  #  [qw( external EnsEMBL::Web::Component::Gene::ExternalData )],
  #  { 'availability' => 'gene' }
  #);
  
  #$external->append($self->create_node('UserAnnotation', 'Personal annotation',
  #  [qw( manual_annotation EnsEMBL::Web::Component::Gene::UserAnnotation )],
  #  { 'availability' => 'gene' }
  #));
  
  
  $self->create_subnode('Export', 'Export Gene Data',
    [qw( export EnsEMBL::Web::Component::Export::Gene )],
    { 'availability' => 'gene', 'no_menu_entry' => 1 }
  );
}

1;
