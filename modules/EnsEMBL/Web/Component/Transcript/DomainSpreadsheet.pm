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
  my @other_domains = map { @{$object->translation_object->get_all_ProteinFeatures($_)} } qw( tmhmm SignalP ncoils Seg );
  return unless (@other_domains || @$domains) ;

  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
  $table->add_columns(
    { 'key' => 'type',    'title' => 'Domain type',      'width' => '15%', 'align' => 'center' },
    { 'key' => 'start',   'title' => 'Start',            'width' => '10%', 'align' => 'center' , 'hidden_key' => '_loc' },
    { 'key' => 'end',     'title' => 'End',              'width' => '10%', 'align' => 'center' },
    { 'key' => 'desc',    'title' => 'Description',      'width' => '15%', 'align' => 'center' },
    { 'key' => 'acc',     'title' => 'Accession',        'width' => '10%', 'align' => 'center' },
    { 'key' => 'interpro','title' => 'Interpro',         'width' => '40%', 'align' => 'center' },
  );
  foreach my $domain (
    sort { $a->idesc cmp $b->idesc ||
           $a->start <=> $b->start ||
           $a->end <=> $b->end ||
           $a->analysis->db cmp $b->analysis->db } @$domains ) {
    my $db = $domain->analysis->db;
    my $id = $domain->hseqname;
    my $interpro_acc = $domain->interpro_ac;
    warn "$db--$interpro_acc";
    my $interpro_link = $object->get_ExtURL_link($interpro_acc,'INTERPRO',$interpro_acc);
    my $other_urls;
    if ($interpro_acc) {
	$other_urls = sprintf(qq( [<a href="/%s/Transcript/Domain/Genes?%s;domain=%s">Display all genes with this domain</a>]),
			      $object->species,
			      join(';', @{$object->core_params}),
			      $interpro_acc );
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

  foreach my $domain ( 
      sort { $a->[0] cmp $b->[0] || $a->[1]->start <=> $b->[1]->start || $a->[1]->end <=> $b->[1]->end }
      map { [ $_->analysis->db || $_->analysis->logic_name || 'unknown', $_ ] }
	  @other_domains ) {
      ( my $domain_type = $domain->[0] ) =~ s/_/ /g;
      $table->add_row( {
	  'type'  => ucfirst($domain_type),
	  'desc'  => '-',
	  'acc'   => '-',
	  'start' => $domain->[1]->start,
	  'end'   => $domain->[1]->end,
	  'interpro' => '-',
	  '_loc'  => join '::', $domain->[1]->start,$domain->[1]->end,
      } );
  }

  return $table->render;
}

1;

