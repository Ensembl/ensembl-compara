package EnsEMBL::Web::Component::Transcript::DomainSpreadsheet;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object   = $self->object;
  my $domains = $object->translation_object->get_protein_domains();
  return unless @$domains ;

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
  $table->add_columns(
    { 'key' => 'desc',  'title' => 'Description',      'width' => '30%', 'align' => 'center' },
    { 'key' => 'start', 'title' => 'Start',            'width' => '15%', 'align' => 'center' , 'hidden_key' => '_loc' },
    { 'key' => 'end',   'title' => 'End',              'width' => '15%', 'align' => 'center' },
    { 'key' => 'type',  'title' => 'Domain type',      'width' => '20%', 'align' => 'center' },
    { 'key' => 'acc',   'title' => 'Accession number', 'width' => '20%', 'align' => 'center' },
  );
# may do a code reference to url call else clean up url creation on domain type
  my $prev_start = undef;
  my $prev_end   = undef;
  foreach my $domain (
    sort { $a->idesc cmp $b->idesc ||
           $a->start <=> $b->start ||
           $a->end <=> $b->end ||
           $a->analysis->db cmp $b->analysis->db } @$domains ) {
    my $db = $domain->analysis->db;
    my $id = $domain->hseqname;
    $table->add_row( { 
      'type'  => $db,
      'acc'   => $object->get_ExtURL_link( $id, uc($db), $id ),
      'start' => $domain->start,
      'end'   => $domain->end ,
      'desc'  => $domain->idesc,
      '_loc'  => join '::', $domain->start,$domain->end,
    } );
  }
  return $table->render;
}

1;

