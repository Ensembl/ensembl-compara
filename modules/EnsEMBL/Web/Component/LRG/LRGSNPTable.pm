# $Id$

package EnsEMBL::Web::Component::LRG::LRGSNPTable;

use strict;

use base qw(EnsEMBL::Web::Component::LRG EnsEMBL::Web::Component::Gene::GeneSNPTable);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self             = shift;
  my $hub              = $self->hub;
  my $consequence_type = $hub->param('sub_table');
	my $icontext         = $hub->param('context') || 'FULL';
  my $lrg              = $self->configure($icontext, $hub->get_imageconfig('lrgsnpview_transcript'));
  my @transcripts      = sort { $a->stable_id cmp $b->stable_id } @{$lrg->get_all_transcripts};
  
  my $count;
  $count += scalar @{$_->__data->{'transformed'}{'gene_snps'}} foreach @transcripts;
  
	my $msg = '';
  if ($icontext) {
    if ($icontext eq 'FULL') {
      $msg = 'The <b>full</b> intronic sequence around this gene is used.';
    }	
    else {	
      $msg = "Currently <b>$icontext"."bp</b> of intronic sequence is included either side of the exons.";
    }
    $msg .='<br />';
  }
	my $html = $self->_hint('snp_phenotype','Configuring the page', qq{<p>$msg\To extend or reduce the intronic sequence, use the "<strong>Configure this page - Context</strong>" link on the left.</p>});
	
	
  if ($consequence_type || $count < 25) {
    $consequence_type ||= 'ALL';
    my $table_rows = $self->variation_table($consequence_type, \@transcripts, $lrg->Obj->feature_Slice);
    my $table      = $table_rows ? $self->make_table($table_rows, $consequence_type) : undef;
    return $self->render_content($table, $consequence_type);
  } else {
    my $table = $self->stats_table(\@transcripts); # no sub-table selected, just show stats
    return $html.$self->render_content($table);
  }
}

sub make_table {
  my ($self, $table_rows, $consequence_type) = @_;
  
  my $columns = [
    { key => 'ID',         sort => 'html'                                                        },
    { key => 'chr' ,       sort => 'position',      title => 'Chr: bp'                           },
    { key => 'Alleles',    sort => 'string',                                   align => 'center' },
    #{ key => 'Ambiguity',  sort => 'string',                                   align => 'center' },
    { key => 'HGVS',       sort => 'string',        title => 'HGVS name(s)',   align => 'center' },
    { key => 'class',      sort => 'string',        title => 'Class',          align => 'center' },
    { key => 'Source',     sort => 'string'                                                      },
    { key => 'status',     sort => 'string',   title => 'Validation',     align => 'center' },
    { key => 'snptype',    sort => 'string',        title => 'Type',                             },
    { key => 'aachange',   sort => 'string',        title => 'Amino Acid',     align => 'center' },
    { key => 'aacoord',    sort => 'position',      title => 'AA co-ordinate', align => 'center' },
    { key => 'Transcript', sort => 'string'                                                      },
  ];
  
  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ], exportable => 1, id => "${consequence_type}_table" });
}

1;
