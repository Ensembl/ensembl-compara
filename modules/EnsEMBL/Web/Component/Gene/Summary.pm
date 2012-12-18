package EnsEMBL::Web::Component::Gene::Summary;

use strict;
use warnings;
no warnings 'uninitialized';

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

# status warnings/hints would be eg out-of-date page, dubious evidence, etc
# which need to be displayed prominently at the top of a page. Only used
# in Vega plugin at the moment, but probably more widely useful.
sub status_warnings { return undef; }
sub status_hints    { return undef; }

sub content {
  my $self = shift;
  my $object = $self->object;
  
  return sprintf '<p>%s</p>', encode_entities($object->Obj->description) if $object->Obj->isa('Bio::EnsEMBL::Compara::Family'); # Grab the description of the object
  return sprintf '<p>%s</p>', 'This identifier is not in the current EnsEMBL database' if $object->Obj->isa('Bio::EnsEMBL::ArchiveStableId');

  my $html = "";
 
  my @warnings = $self->status_warnings;
  if(@warnings>1 and $warnings[0] and $warnings[1]) {
    $html .= $self->_info_panel($warnings[2]||'warning',
                                $warnings[0],$warnings[1]);
  }
  my @hints = $self->status_hints;
  if(@hints>1 and $hints[0] and $hints[1]) {
    $html .= $self->_hint($hints[2],$hints[0],$hints[1]);
  }
  
  $html .= $self->transcript_table;
  my $extra = ($object->species_defs->ENSEMBL_SITETYPE eq 'Vega') ? ' and manually curated alternative alleles' : ', paralogues, regulatory regions and splice variants';

  $html .= $self->_hint('gene', 'Transcript and Gene level displays', sprintf('
    <p>In %s we provide displays at two levels:</p>
    <ul>
      <li>Transcript views which provide information specific to an individual transcript such as the cDNA and CDS sequences and protein domain annotation.</li>
      <li>Gene views which provide displays for data associated at the gene level such as orthologues%s.</li>
    </ul>
    <p>
      This view is a gene level view. To access the transcript level displays select a Transcript ID in the table above and then navigate to the information you want using the menu at the left hand side of the page.  
      To return to viewing gene level information click on the Gene tab in the menu bar at the top of the page.
    </p>', $object->species_defs->ENSEMBL_SITETYPE, $extra
  ));

  return $html;
}

1;
