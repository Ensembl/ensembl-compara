package EnsEMBL::Web::ZMenu::AltSeqAlignment;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self         = shift;

  my $hub          = $self->hub;
  my $id           = $hub->param('id');
  my $db           = $hub->param('db') || 'core';
  my $object_type  = $hub->param('ftype');
  my $db_adaptor   = $hub->database(lc($db));
  my $adaptor_name = "get_${object_type}Adaptor";
  my $feat_adap    = $db_adaptor->$adaptor_name;

  my $feature = $feat_adap->fetch_by_dbID($id); 
  my $external_db_id = $feature->can('external_db_id') ? $feature->external_db_id : '';
  my $extdbs         = $external_db_id ? $hub->species_defs->databases->{'DATABASE_CORE'}{'tables'}{'external_db'}{'entries'} : {};
  my $hit_db_name    = $extdbs->{$external_db_id}->{'db_name'} || 'External Feature';
  my $ref_seq_name  = $feature->display_id;
  my $ref_seq_start = $feature->hstart < $feature->hend ? $feature->hstart : $feature->hend;
  my $ref_seq_end   = $feature->hend < $feature->hstart ? $feature->hstart : $feature->hend;
  my $ref_location .= $ref_seq_name .':' .$ref_seq_start . '-' . $ref_seq_end;
  my $hit_strand    = $feature->hstart > $feature->hend  ? '(- strand)' : '(+ strand)';

  $self->caption("$ref_location ($hit_db_name)");


  $self->add_entry ({
    label   => "$ref_location $hit_strand",
    link    => $hub->url({
      type    => 'Location',
      action  => 'View',
      r       => $ref_location,
      __clear => 1
    })
  });  

  $self->add_entry({
    label => 'View all hits',
    link  => $hub->url({
      type    => 'Location',
      action  => 'Genome',
      ftype   => $object_type,
      id      => $ref_seq_name,
      filter  => $feature->slice->seq_region_name,
      db      => $db,
      __clear => 1
    })
  });
}

1;
