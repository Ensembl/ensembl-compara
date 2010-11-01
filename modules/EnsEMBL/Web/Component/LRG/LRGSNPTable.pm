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
  my $self        = shift;
  my $hub         = $self->hub;
  my $lrg         = $self->configure($hub->param('context') || 'FULL', $hub->get_imageconfig('lrgsnpview_transcript'));
  my @transcripts = sort { $a->stable_id cmp $b->stable_id } @{$lrg->get_all_transcripts};
  
  # no sub-table selected, just show stats
  if(!defined($hub->param('sub_table'))) {
    my $table = $self->stats_table(\@transcripts);
    return $self->render_content($table)
  }
  
  else {
    my $table_rows = $self->variation_table(\@transcripts, $lrg->Obj->feature_Slice);
    my $table      = $table_rows ? $self->make_table($table_rows) : undef;
    
    return $self->render_content($table);
  }
}



sub make_table {
  my ($self, $table_rows) = @_;
  
  my $columns = [
    { key => 'ID',         sort => 'html'                                                   },
    { key => 'chr' ,       sort => 'position', title => 'Chr: bp'                           },
    { key => 'Alleles',    sort => 'string',   align => 'center'                            },
    { key => 'Ambiguity',  sort => 'string',   align => 'center'                            },
    { key => 'HGVS',       sort => 'string',   title => 'HGVS name(s)',   align => 'center' },
    { key => 'class',      sort => 'string',   title => 'Class',          align => 'center' },
    { key => 'Source',     sort => 'string'                                                 },
    { key => 'status',     sort => 'string',   title => 'Validation',     align => 'center' },
    { key => 'snptype',    sort => 'string',   title => 'Type',                             },
    { key => 'aachange',   sort => 'string',   title => 'Amino Acid',     align => 'center' },
    { key => 'aacoord',    sort => 'position', title => 'AA co-ordinate', align => 'center' },
    { key => 'Transcript', sort => 'string'                                                 },
  ];
  
  return $self->new_table($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ] });
}

1;
