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
  return $self->non_coding_error unless $object->translation_object;
  my $analyses    = $object->table_info( $object->get_db, 'protein_feature' )->{'analyses'}||{};
  my @domain_keys = grep { $analyses->{$_}{'web'}{'type'} eq 'domain' } keys %$analyses;
  my @other_keys  = grep { $analyses->{$_}{'web'}{'type'} ne 'domain' } keys %$analyses;
##  my $domains = $object->translation_object->get_protein_domains();
  my @domains     = map { @{$object->translation_object->get_all_ProteinFeatures($_)} } @domain_keys;
  my @others      = map { @{$object->translation_object->get_all_ProteinFeatures($_)} } @other_keys;

  return unless (@others || @domains) ;

  my $html = '';
  if( @domains ) {
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
    $table->add_columns(
      { 'key' => 'type',    'title' => 'Domain type',      'width' => '15%', 'align' => 'center' },
      { 'key' => 'start',   'title' => 'Start',            'width' => '10%', 'align' => 'center' , 'hidden_key' => '_loc' },
      { 'key' => 'end',     'title' => 'End',              'width' => '10%', 'align' => 'center' },
      { 'key' => 'desc',    'title' => 'Description',      'width' => '15%', 'align' => 'center' },
      { 'key' => 'acc',     'title' => 'Accession',        'width' => '10%', 'align' => 'center' },
      { 'key' => 'interpro','title' => 'InterPro',         'width' => '40%', 'align' => 'center' },
    );
    foreach my $domain (
      sort { $a->idesc cmp $b->idesc ||
             $a->start <=> $b->start ||
             $a->end <=> $b->end ||
             $a->analysis->db cmp $b->analysis->db } @domains ) {
      my $db = $domain->analysis->db;
      my $id = $domain->hseqname;
      my $interpro_acc = $domain->interpro_ac;
      my $interpro_link = $object->get_ExtURL_link($interpro_acc,'INTERPRO',$interpro_acc);
      my $other_urls;
      if ($interpro_acc) {
        my $url = $object->_url({ 'action' => 'Domains/Genes', 'domain' => $interpro_acc });
	  $other_urls = qq( [<a href="$url">Display all genes with this domain</a>]);
      }
      else {
	  $interpro_link = '-';
	  $other_urls = '';
      }
      $table->add_row( {
        'type'     => $db,
        'desc'     => $domain->idesc || '-',
        'acc'      => $object->get_ExtURL_link( $id, uc($db), $id ),
        'start'    => $domain->start,
        'end'      => $domain->end ,
        'interpro' => $interpro_link.$other_urls,
        '_loc'  => join '::', $domain->start,$domain->end,
      } );
    }
    $html .= '<h2>Domains</h2>'. $table->render;
  } 
  if( @others ) {
    my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
    $table->add_columns(
      { 'key' => 'type',    'title' => 'Feature type',     'width' => '40%', 'align' => 'center' },
      { 'key' => 'start',   'title' => 'Start',            'width' => '30%', 'align' => 'center' , 'hidden_key' => '_loc' },
      { 'key' => 'end',     'title' => 'End',              'width' => '30%', 'align' => 'center' },
    );
    foreach my $domain ( 
        sort { $a->[0] cmp $b->[0] || $a->[1]->start <=> $b->[1]->start || $a->[1]->end <=> $b->[1]->end }
        map { [ $_->analysis->db || $_->analysis->logic_name || 'unknown', $_ ] }
	    @others ) {
        ( my $domain_type = $domain->[0] ) =~ s/_/ /g;
        $table->add_row( {
	    'type'  => ucfirst($domain_type),
	    'start' => $domain->[1]->start,
	    'end'   => $domain->[1]->end,
	    '_loc'  => join '::', $domain->[1]->start,$domain->[1]->end,
        } );
    }
    $html .= '<h2>Other features</h2>'.$table->render;
  }
  return $html;
}

1;

