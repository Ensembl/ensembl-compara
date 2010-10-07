#$Id$
package EnsEMBL::Web::Component::LRG::LRGSNPTable;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::LRG);
use base qw(EnsEMBL::Web::Component::LRG EnsEMBL::Web::Component::Gene::GeneSNPTable);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return;
}


sub content {
  my $self        = shift;
  my $object      = $self->object;
  my $lrg         = $self->configure($object->param('context') || 'FULL', $object->get_imageconfig('lrgsnpview_transcript'));
  my @transcripts = sort { $a->stable_id cmp $b->stable_id } @{$lrg->get_all_transcripts};
  my $lrg_slice   = $lrg->Obj->feature_Slice;
  my $tables      = {};

###
  my $table_rows = $self->variation_table(\@transcripts, $lrg_slice);
  
  my $table = $self->make_table($table_rows) if $table_rows;
  
  return $self->render_content($table);
}

sub make_table {
  my ($self, $table_rows) = @_;
  
  my $columns = [
    { key => 'ID',        sort => 'html'                                                   },
    { key => 'chr' ,      sort => 'position', title => 'Chr: bp'                           },
    { key => 'Alleles',   sort => 'string',   align => 'center'                            },
    { key => 'Ambiguity', sort => 'string',   align => 'center'                            },
    { key => 'HGVS',      sort => 'string',   title => 'HGVS name(s)',   align => 'center' },
    { key => 'class',     sort => 'string',   title => 'Class',          align => 'center' },
    { key => 'Source',    sort => 'string'                                                 },
    { key => 'status',    sort => 'string',   title => 'Validation',     align => 'center' },
    { key => 'snptype',   sort => 'string',   title => 'Type',                             },
    { key => 'aachange',  sort => 'string',   title => 'Amino Acid',     align => 'center' },
    { key => 'aacoord',   sort => 'position', title => 'AA co-ordinate', align => 'center' },
    { key => 'Transcript', sort => 'string'},
  ];
  
  return new EnsEMBL::Web::Document::SpreadSheet($columns, $table_rows, { data_table => 1, sorting => [ 'chr asc' ] });
}

1;
